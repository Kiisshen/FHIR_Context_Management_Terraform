resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

data "azurerm_client_config" "current" {
}

data "azuread_client_config" "current" {
}

resource "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"

  tenant_id    = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

resource "time_rotating" "example" {
  rotation_days = 180
}

resource "azuread_application" "app_registration" {
  display_name = var.app_registration_name
  owners       = [data.azuread_client_config.current.object_id]

  password {
    display_name = "MySecret-1"
    start_date   = time_rotating.example.id
    end_date     = timeadd(time_rotating.example.id, "4320h")
  }
}

resource "azurerm_role_assignment" "app_registration_keyvault_admin_user_current" {
  principal_id         = data.azuread_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

resource "azurerm_role_assignment" "app_registration_keyvault_admin" {
  principal_id         = azuread_service_principal.app_registration_sp.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

resource "azurerm_key_vault_secret" "app_secret" {
  name         = "AppSecret"
  value        = tolist(azuread_application.app_registration.password).0.value
  key_vault_id = azurerm_key_vault.key_vault.id

  depends_on = [
    azurerm_role_assignment.app_registration_keyvault_admin,
    azurerm_role_assignment.app_registration_keyvault_admin_user_current
  ]
}

resource "azurerm_web_pubsub" "webpubsub" {
  name                = var.web_pubsub_service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku         = "Free_F1"
  capacity    = 1

  public_network_access_enabled = true

  live_trace {
    enabled                   = true
    messaging_logs_enabled    = true
    connectivity_logs_enabled = true
  }
}

resource "azurerm_signalr_service" "signalr" {
  name                = var.signalr_service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Free_F1"
    capacity = 1
  }

  public_network_access_enabled = true

  cors {
    allowed_origins = [
      "*"
    ]
  }
  connectivity_logs_enabled = true
  messaging_logs_enabled    = false
  service_mode              = "Serverless"

  tags = {
    environment = "dev"
    source      = "terraform"
  }
}

resource "azurerm_storage_account" "func_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

resource "azurerm_service_plan" "func_consumption_plan" {
  name                = var.functions_consumption_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "Y1"

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

resource "azurerm_windows_function_app" "func_app" {
  name                = var.windows_functions_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  service_plan_id = azurerm_service_plan.func_consumption_plan.id

  site_config {
    application_stack {
      node_version = "~20"
    }
    cors {
      allowed_origins = ["*"]
    }

    application_insights_connection_string = azurerm_application_insights.insights.connection_string
    application_insights_key = azurerm_application_insights.insights.instrumentation_key
  }

  app_settings = {
    SIGNALR_CONNECTION_STRING = azurerm_signalr_service.signalr.primary_connection_string
    WebPubSubConnectionString = azurerm_web_pubsub.webpubsub.primary_connection_string
    FHIR_SERVICE              = "https://${var.healthcare_service_name}-${var.fhir_service_name}.fhir.azurehealthcareapis.com/"
    AZURE_TENANT_ID           = data.azurerm_client_config.current.tenant_id
    AZURE_CLIENT_ID           = azuread_application.app_registration.client_id
    KEY_VAULT_STRING          = azurerm_key_vault.key_vault.vault_uri
    KEY_VAULT_SECRET          = azurerm_key_vault_secret.app_secret.name
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      app_settings,
      site_config,
    ]
  }

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = var.analytics_workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

resource "azurerm_application_insights" "insights" {
  name                = var.application_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  application_type    = "Node.JS"

  tags = {
    environment = "dev"
    source = "terraform"
  }
}

resource "azurerm_healthcare_workspace" "healthcare_workspace" {
  name                = var.healthcare_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_healthcare_fhir_service" "example" {
  name                = var.fhir_service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_healthcare_workspace.healthcare_workspace.id
  kind                = "fhir-R4"

  authentication {
    authority = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}"
    audience  = "https://${var.healthcare_service_name}-${var.fhir_service_name}.fhir.azurehealthcareapis.com"
  }

  identity {
    type = "SystemAssigned"
  }

  cors {
    allowed_origins     = ["*"]
    allowed_headers     = ["*"]
    allowed_methods     = ["GET", "DELETE", "PUT", "POST"]
    credentials_allowed = false
  }

  configuration_export_storage_account_name = azurerm_storage_account.func_storage.name
}

resource "azurerm_role_assignment" "fhir_role_assignment" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "FHIR Data Contributor"
  scope                = azurerm_healthcare_fhir_service.example.id
}

resource "azurerm_role_assignment" "key_vault_role_assignment" {
  principal_id         = azurerm_windows_function_app.func_app.identity.0.principal_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

resource "azurerm_role_assignment" "key_vault_role_assignment_fhir" {
  principal_id         = azurerm_healthcare_fhir_service.example.identity.0.principal_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

resource "azurerm_role_assignment" "fhir_role_assignment_functions" {
  principal_id         = azurerm_windows_function_app.func_app.identity.0.principal_id
  role_definition_name = "FHIR Data Contributor"
  scope                = azurerm_healthcare_fhir_service.example.id
}

resource "azurerm_eventgrid_system_topic" "example" {
  name                   = var.system_topic_name
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  source_arm_resource_id = azurerm_healthcare_workspace.healthcare_workspace.id
  topic_type             = "Microsoft.HealthcareApis.Workspaces"
}

resource "azurerm_eventgrid_system_topic_event_subscription" "example" {
  name                = var.event_sub_name
  system_topic        = azurerm_eventgrid_system_topic.example.name
  resource_group_name = azurerm_resource_group.rg.name

  webhook_endpoint {
    url = "https://${azurerm_windows_function_app.func_app.default_hostname}/api/FHIREventEndpoint?"
  }

  included_event_types = [
    "Microsoft.HealthcareApis.FhirResourceCreated"
  ]
  event_delivery_schema = "EventGridSchema"
}

resource "azurerm_eventgrid_system_topic_event_subscription" "example2" {
  name                = var.event_sub_name_pubsub
  system_topic        = azurerm_eventgrid_system_topic.example.name
  resource_group_name = azurerm_resource_group.rg.name

  webhook_endpoint {
    url = "https://${azurerm_windows_function_app.func_app.default_hostname}/api/WebPubSubEndpoint?"
  }

  included_event_types = [
    "Microsoft.HealthcareApis.FhirResourceCreated"
  ]
  event_delivery_schema = "EventGridSchema"

    depends_on = [
      azurerm_eventgrid_system_topic_event_subscription.example
  ]
}

resource "azuread_service_principal" "app_registration_sp" {
  application_id = azuread_application.app_registration.client_id
}

# Assign the FHIR Data Contributor role to the Service Principal
resource "azurerm_role_assignment" "fhir_role_assignment_app" {
  principal_id         = azuread_service_principal.app_registration_sp.object_id
  role_definition_name = "FHIR Data Contributor"
  scope                = azurerm_healthcare_fhir_service.example.id
}


output "app_registration_client_id" {
  value       = azuread_application.app_registration.client_id
  description = "The client ID of the Azure AD App Registration."
}

output "app_current_tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "The tenant ID of user."
}
