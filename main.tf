# Configure Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatesa12345"
    container_name       = "tfstate"
    key                  = "func-logic-app.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "func-logic-app-rg"
  location = "East US"
}

# Network Security
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.main.name
  vnet_name           = "secure-vnet"
  address_space       = ["10.0.0.0/16"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names        = ["functions-subnet", "logic-app-subnet"]

  nsg_ids = {
    "functions-subnet"  = azurerm_network_security_group.func_nsg.id
    "logic-app-subnet"  = azurerm_network_security_group.logic_nsg.id
  }
}

# Network Security Groups
resource "azurerm_network_security_group" "func_nsg" {
  name                = "func-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.2.0/24" # Logic App subnet
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "logic_nsg" {
  name                = "logic-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https-outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.1.0/24" # Function App subnet
  }
}

# Function App with Private Endpoint
resource "azurerm_function_app" "secure_func" {
  name                       = "secure-function-app"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_plan_id        = azurerm_app_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  version                    = "~4"
  https_only                 = true

  site_config {
    always_on = true
    ftps_state = "Disabled"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Logic App Workflow
resource "azurerm_logic_app_workflow" "scheduler" {
  name                = "function-trigger-la"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  workflow_parameters = {
    "$connections" = jsonencode({
      "azurefunction" = {
        connectionId = azurerm_logic_app_connection.function_conn.id
      }
    })
  }

  workflow_definition = <<WORKFLOW
{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "triggers": {
    "Recurrence": {
      "type": "Recurrence",
      "recurrence": {
        "frequency": "Minute",
        "interval": 10
      }
    }
  },
  "actions": {
    "Call_Function": {
      "type": "ApiConnection",
      "inputs": {
        "body": {},
        "host": {
          "connection": {
            "name": "@parameters('$connections')['azurefunction']['connectionId']"
          }
        },
        "method": "POST",
        "path": "/api/trigger"
      }
    }
  }
}
WORKFLOW
}

# Secure Connection between Logic App and Function App
resource "azurerm_logic_app_connection" "function_conn" {
  name         = "func-connection"
  logic_app_id = azurerm_logic_app_workflow.scheduler.id
  service_provider_name = "azureFunctions"
  parameter_values = {
    "functionAppUrl" = azurerm_function_app.secure_func.default_hostname
  }
}
