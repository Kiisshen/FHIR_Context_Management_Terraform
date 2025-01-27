variable "resource_group_location" {
  type        = string
  default     = "northeurope"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "resource_group_name" {
  description = "Resource Group name for the project"
  default     = "context_management_group"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for Functions app storage"
  default     = "contextfunctionsstorage"
  type        = string
}

variable "functions_consumption_plan_name" {
  description = "Functions app consumption plan name"
  default     = "functions_consumption_plan"
  type        = string
}

variable "windows_functions_app_name" {
  description = "Functions app name"
  default     = "contextmanagementfunctionsapp"
  type        = string
}

variable "analytics_workspace_name" {
  description = "Name for analytics workspace"
  default     = "functionsanalyticsworkspace"
  type        = string
}

variable "application_insights_name" {
  description = "Name for application insights"
  default     = "functions_application_insights"
  type        = string
}

variable "healthcare_service_name" {
  description = "Name for the Healthcare Data Service"
  default     = "hdsfhircontexttest"
  type        = string
}

variable "fhir_service_name" {
  description = "FHIR Service name"
  default     = "contextchangefhirservice"
  type        = string
}

variable "system_topic_name" {
  description = "Healthcare Data Service System topic name for event grid"
  default     = "fhirResourceListener"
  type        = string
}

variable "signalr_service_name" {
  description = "SignalR service name"
  default     = "contextsignalrservice"
  type        = string
}

variable "event_sub_name" {
  description = "Event Subscription name"
  default     = "fhircreatedsub"
  type        = string
}

variable "web_pubsub_service_name" {
  description = "Web PubSub service name"
  default     = "contextpubsubservice"
}

variable "event_sub_name_pubsub" {
  description = "Web PubSub subscription name"
  default     = "fhircreatedsubpubsub"
}

variable "key_vault_name" {
  description = "Keyvault name"
  default     = "fhirkeyvaulttest"
}

variable "keyvault_secret_name" {
  description = "keyvault secret name"
  default     = "secret-kissa"
}

variable "keyvault_secret_value" {
  description = "keyvault secret value"
  default     = "kissa"
}

variable "app_registration_name" {
  description = "app registration name"
  default     = "TestAppRegistration"
}