# File: variables.tf

variable "resource_group_name_prefix" {
  description = "Prefix for the resource group name."
  type        = string
  default     = "tf-func-logic"
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "East US"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "function_subnet_prefix" {
  description = "Address prefix for the Function App subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "logicapp_subnet_prefix" {
  description = "Address prefix for the Logic App subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "function_runtime_stack" {
  description = "Function App runtime stack (e.g., dotnet, node, python, java)."
  type        = string
  default     = "dotnet" # Adjust if using a different language
}

variable "function_dotnet_version" {
  description = "Version for the .NET runtime stack (if using dotnet)."
  type        = string
  default     = "v6.0" # Adjust as needed (e.g., v7.0)
}

variable "logic_app_trigger_interval" {
  description = "Interval for the Logic App recurrence trigger."
  type        = number
  default     = 10
}

variable "logic_app_trigger_frequency" {
  description = "Frequency for the Logic App recurrence trigger (e.g., Minute, Hour, Day)."
  type        = string
  default     = "Minute"
}

variable "function_api_route" {
  description = "The API route of the function to be triggered by the Logic App (e.g., /api/MyHttpTrigger)."
  type        = string
  default     = "/api/trigger" # IMPORTANT: Change this to your actual function route!
}