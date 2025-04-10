

output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Name of the deployed Function App."
  value       = azurerm_windows_function_app.secure_func.name
}

output "function_app_hostname" {
  description = "Default hostname of the Function App."
  value       = azurerm_windows_function_app.secure_func.default_hostname
}

# Updated Logic App Outputs
output "logic_app_name_deployed_via_arm" {
  description = "Name of the Logic App Workflow deployed via ARM template."
  # We output the name we passed as a parameter to the deployment
  value       = "${var.resource_group_name_prefix}-logicapp-scheduler"
}

output "logic_app_arm_deployment_name" {
    description = "Name of the ARM deployment operation for the Logic App."
    value = azurerm_resource_group_template_deployment.logic_app_deployment.name
}
# Note: Getting the Logic App's resource ID directly requires configuring ARM template outputs.

output "api_connection_name" {
  description = "Name of the API Connection used by the Logic App."
  value       = azurerm_api_connection.function_api.name
}

output "function_subnet_id" {
  description = "Resource ID of the Function App subnet."
  value       = module.network.vnet_subnets[0]
}

output "logic_app_subnet_id" {
  description = "Resource ID of the Logic App subnet."
  value       = module.network.vnet_subnets[1]
}