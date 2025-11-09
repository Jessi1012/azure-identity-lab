terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Get current Azure client configuration like tenant and subscription info
data "azurerm_client_config" "current" {}

# 1. RESOURCE GROUP (use existing)
data "azurerm_resource_group" "identity_lab" {
  name = var.resource_group_name
}

# 2. LOG ANALYTICS WORKSPACE
resource "azurerm_log_analytics_workspace" "identity_logs" {
  name                = var.workspace_name
  location            = data.azurerm_resource_group.identity_lab.location
  resource_group_name = data.azurerm_resource_group.identity_lab.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# 3. MICROSOFT SENTINEL
# Import existing solution if already deployed manually:
# terraform import azurerm_log_analytics_solution.sentinel "/subscriptions/645a9291-908c-4ee8-b187-9b84d1e25a36/resourceGroups/Identity-Lab-RG/providers/Microsoft.OperationsManagement/solutions/SecurityInsights(identity-lab-logs-workspace01)"
resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = data.azurerm_resource_group.identity_lab.location
  resource_group_name   = data.azurerm_resource_group.identity_lab.name
  workspace_resource_id = azurerm_log_analytics_workspace.identity_logs.id
  workspace_name        = azurerm_log_analytics_workspace.identity_logs.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# 4. AZURE AD DIAGNOSTIC SETTINGS
# Note: This resource has known provider issues. If it fails, configure manually in portal.
resource "azurerm_monitor_aad_diagnostic_setting" "entra_logs" {
  name                       = "SendLogsToSentinel"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id

  enabled_log {
    category = "SignInLogs"
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AuditLogs"
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "NonInteractiveUserSignInLogs"
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "ServicePrincipalSignInLogs"
    retention_policy {
      enabled = false
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

# 5. SENTINEL DETECTION RULES - Define multiple scheduled alert rules using KQL queries

# Dormant account reactivation detection
resource "azurerm_sentinel_alert_rule_scheduled" "dormant_account" {
  name                       = "DormantAccountReactivation-${random_string.suffix.result}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Dormant Account Reactivation Detected"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P1D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  severity                   = "High"
  tactics                    = ["Persistence", "InitialAccess"]
  query                      = file("${path.module}/../kql-queries/dormant-account-detection.kql")

  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
    }
  }

  depends_on = [azurerm_log_analytics_solution.sentinel]
}


# Impossible travel detection
resource "azurerm_sentinel_alert_rule_scheduled" "impossible_travel" {
  name                       = "ImpossibleTravelDetection-${random_string.suffix.result}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Impossible Travel Login"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P1D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  severity                   = "Medium"
  tactics                    = ["InitialAccess"]
  query                      = file("${path.module}/../kql-queries/impossible-travel-detection.kql")

  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
    }
  }

  depends_on = [azurerm_log_analytics_solution.sentinel]
}


# Failed login flood detection (password spray)
resource "azurerm_sentinel_alert_rule_scheduled" "failed_login_flood" {
  name                       = "FailedLoginFloodDetection-${random_string.suffix.result}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Failed Login Flood (Password Spray)"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P1D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  severity                   = "High"
  tactics                    = ["CredentialAccess"]
  query                      = file("${path.module}/../kql-queries/failed-login-flood-detection.kql")

  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
    }
  }

  depends_on = [azurerm_log_analytics_solution.sentinel]
}


# Privilege escalation detection
resource "azurerm_sentinel_alert_rule_scheduled" "privilege_escalation" {
  name                       = "PrivilegeEscalationDetection-${random_string.suffix.result}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Unauthorized Privilege Escalation"
  enabled                    = true
  query_frequency            = "PT1H"
  query_period               = "P1D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  severity                   = "High"
  tactics                    = ["PrivilegeEscalation"]
  query                      = file("${path.module}/../kql-queries/privilege-escalation-detection.kql")

  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
    }
  }

  depends_on = [azurerm_log_analytics_solution.sentinel]
}


# 6. DEFENDER FOR CLOUD CONFIGURATION (Free Tier)
resource "azurerm_security_center_contact" "security_contact" {
  email               = "chaitra.shashikala@gmail.com"
  phone               = "+917204426101"
  alert_notifications = true
  alerts_to_admins    = true
}

resource "azurerm_security_center_subscription_pricing" "defender_vms" {
  tier          = "Free"
  resource_type = "VirtualMachines"
}

# 7. KEY VAULT CONFIGURATION FOR SECRETS
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "identity_vault" {
  name                       = "kv-identity-${random_string.suffix.result}" # Vault name suffix to ensure uniqueness
  location                   = data.azurerm_resource_group.identity_lab.location
  resource_group_name        = data.azurerm_resource_group.identity_lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
  tags                       = var.tags
}

resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.identity_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_monitor_action_group" "identity_lab_action_group" {
  name                = "CriticalAlertsAction"
  resource_group_name = data.azurerm_resource_group.identity_lab.name
  short_name          = "p0action"

  email_receiver {
    name          = "sendtoadmin"
    email_address = "admin@contoso.com"
  }
}
