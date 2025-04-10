# File: main.tf

# Configure Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Get current subscription details
data "azurerm_subscription" "current" {}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name_prefix}-rg-${random_string.suffix.result}"
  location = var.location
}

# Network Security
# Note: Using a public module. Ensure you understand its behavior and outputs.
# Pinning the module version is highly recommended for production.
module "network" {
  source              = "Azure/network/azurerm"
  # version = "x.y.z" # <-- Add specific version
  resource_group_name = azurerm_resource_group.main.name
  vnet_name           = "${var.resource_group_name_prefix}-vnet"
  address_space       = var.vnet_address_space
  subnet_prefixes     = [var.function_subnet_prefix, var.logicapp_subnet_prefix]
  subnet_names        = ["functions-subnet", "logic-app-subnet"]
  use_for_each        = false # Outputs will be lists (e.g., vnet_subnets[0])

  tags = {
    environment = "dev" # Example tag
  }
}

# Network Security Group for Function App Subnet
resource "azurerm_network_security_group" "func_nsg" {
  name                = "${var.resource_group_name_prefix}-func-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https-inbound-from-logicapp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.logicapp_subnet_prefix # Logic App subnet source
    destination_address_prefix = var.function_subnet_prefix # Function App subnet destination
  }
  # Add other rules as needed
}

# Network Security Group for Logic App Subnet
resource "azurerm_network_security_group" "logic_nsg" {
  name                = "${var.resource_group_name_prefix}-logic-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https-outbound-to-function"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.logicapp_subnet_prefix # Logic App subnet source
    destination_address_prefix = var.function_subnet_prefix # Function App subnet destination
  }
  # Add other rules as needed (e.g., outbound access to Azure services for connectors)
}

# Associate NSG with Function App Subnet
resource "azurerm_subnet_network_security_group_association" "functions_subnet_assoc" {
  # Verify index [0] corresponds to 'functions-subnet' in the module definition
  subnet_id                 = module.network.vnet_subnets[0]
  network_security_group_id = azurerm_network_security_group.func_nsg.id
}

# Associate NSG with Logic App Subnet
resource "azurerm_subnet_network_security_group_association" "logic_app_subnet_assoc" {
  # Verify index [1] corresponds to 'logic-app-subnet' in the module definition
  subnet_id                 = module.network.vnet_subnets[1]
  network_security_group_id = azurerm_network_security_group.logic_nsg.id
}

# App Service Plan (Consumption Plan for Functions)
resource "azurerm_service_plan" "func_plan" {
  name                = "${var.resource_group_name_prefix}-func-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Windows" # Change to Linux if function runtime needs it
  sku_name            = "Y1"      # Y1 = Consumption plan SKU
}

# Storage Account for Function App
resource "azurerm_storage_account" "func_storage" {
  name                     = "st${lower(var.resource_group_name_prefix)}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
}

# Function App
resource "azurerm_windows_function_app" "secure_func" {
  name                       = "${var.resource_group_name_prefix}-func-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key

  https_only = true

  # Consider VNet Integration or Private Endpoint for true network isolation
  # Requires subnet delegation or specific PE resources
  # virtual_network_subnet_id = module.network.vnet_subnets[0] # Requires delegation setup

  site_config {
    always_on = false # Consumption plan doesn't support Always On
    ftps_state = "Disabled"
    application_stack {
      # Dynamically set based on variables
      dotnet_version = var.function_runtime_stack == "dotnet" ? var.function_dotnet_version : null
      # Add other stacks as needed (e.g., node_version, python_version) based on var.function_runtime_stack
    }
    # ip_restriction block could be added here for further security if not using VNet/PE fully
  }

  app_settings = {
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "FUNCTIONS_WORKER_RUNTIME"    = var.function_runtime_stack
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.func_storage.primary_connection_string
    "WEBSITE_CONTENTSHARE"        = lower("${var.resource_group_name_prefix}-func-${random_string.suffix.result}")
    # Add any application-specific settings here
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.functions_subnet_assoc,
    azurerm_storage_account.func_storage,
    azurerm_service_plan.func_plan
  ]
}

# API Connection for Logic App to call the Function App
resource "azurerm_api_connection" "function_api" {
  name                = "${var.resource_group_name_prefix}-func-apiconn"
  resource_group_name = azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/azurefunction"
  display_name        = "Azure Function Connection (${azurerm_windows_function_app.secure_func.name})"

  parameter_values = {
    "functionAppUrl" = "https://${azurerm_windows_function_app.secure_func.default_hostname}"
    # Add authentication parameters if function auth is not 'anonymous'
    # e.g., "authType": "ManagedServiceIdentity" (if Function App MSI has access)
    # or "authType": "None" if anonymous (generally not recommended)
  }

  tags = {
    DisplayName = "Azure Function Connection"
  }

  depends_on = [azurerm_windows_function_app.secure_func]
}




# --- ADD Logic App Deployment via ARM Template ---

# Read the ARM template file content
data "local_file" "logic_app_arm_template" {
  filename = "${path.module}/workflow.json" # Ensure this filename matches
}

# Deploy the Logic App using the ARM template
resource "azurerm_resource_group_template_deployment" "logic_app_deployment" {
  # Use the correct RG name from your resources
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode     = "Incremental"
  # Provide a unique name for the deployment operation itself
  name                = "${var.resource_group_name_prefix}-logicapp-deploy-${random_string.suffix.result}"

  # Provide the ARM template content read from the file
  template_content = data.local_file.logic_app_arm_template.content

  # Provide the parameters required by the workflow.json ARM template
  parameters_content = jsonencode({
    "logicAppName" = {
       # Define the name for the Logic App to be created by the template
       value = "${var.resource_group_name_prefix}-logicapp-scheduler"
    },
    "location" = {
        # Use the location variable or RG location
        value = var.location
     },
    "functionApiConnectionId" = {
        # Pass the ID of the API Connection created by Terraform
        value = azurerm_api_connection.function_api.id
     },
    "functionApiConnectionName" = {
        # Pass the Name of the API Connection created by Terraform
        value = azurerm_api_connection.function_api.name
     },
    "managedApiId" = {
        # Pass the Managed API ID used by the API Connection
        value = azurerm_api_connection.function_api.managed_api_id
     },
     "functionApiPath" = {
         # Pass the Function API Route from the variable
         value = var.function_api_route
     },
     "triggerInterval" = {
         # Pass the trigger interval from the variable
         value = var.logic_app_trigger_interval
     },
     "triggerFrequency" = {
         # Pass the trigger frequency from the variable
         value = var.logic_app_trigger_frequency
     }
     # Add any other parameters defined in workflow.json here
  })

  # Ensure the API connection exists before attempting the deployment
  depends_on = [azurerm_api_connection.function_api]
}