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


# ===========================
# Resource Group
# ===========================
# Using existing resource group instead of creating new one
data "azurerm_resource_group" "identity_lab" {
  name = var.resource_group_name
}


# ===========================
# Log Analytics Workspace
# ===========================

resource "azurerm_log_analytics_workspace" "identity_logs" {
  name                = var.workspace_name
  location            = data.azurerm_resource_group.identity_lab.location
  resource_group_name = data.azurerm_resource_group.identity_lab.name

  sku               = "PerGB2018"        # Pricing plan
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ===========================
# Enable Microsoft Sentinel (SIEM)
# ===========================

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  depends_on   = [azurerm_log_analytics_workspace.identity_logs]
}

# ===========================
# Azure AD Diagnostic Settings (send Logs to Log Analytics)
# ===========================

resource "azurerm_monitor_aad_diagnostic_setting" "entra_logs" {
  name                       = "SendLogsToSentinel"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id

  enabled_log {
    category = "SignInLogs"  # Includes all sign-in attempts
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AuditLogs"   # Includes all administrative changes
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "NonInteractiveUserSignInLogs" # Service account sign-ins
    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "ServicePrincipalSignInLogs"  # App sign-ins
    retention_policy {
      enabled = false
    }
  }
}

# ===========================
# Sentinel Detection Rules
# ===========================

# Example Rule: Dormant Account Reactivation

resource "azurerm_sentinel_alert_rule_scheduled" "dormant_account" {
  name                       = "DormantAccountReactivation"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Dormant Account Reactivation Detected"
  
  enabled           = true
  query_frequency   = "PT1H"
  query_period      = "P1D"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "High"
  tactics  = ["Persistence", "InitialAccess"]
  
  query = file("${path.module}/../kql-queries/dormant-account-detection.kql")
  
  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
      entity_matching_method  = "AnyAlert"
      reopen_closed_incidents = false
    }
  }
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
 }
 resource "azurerm_sentinel_alert_rule_scheduled" "impossible_travel" {
  name                       = "ImpossibleTravelDetection"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Impossible Travel Login"
  
  enabled           = true
  query_frequency   = "PT1H"
  query_period      = "P1D"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "Medium"
  tactics  = ["InitialAccess"]
  
  query = file("${path.module}/../kql-queries/impossible-travel-detection.kql")
  
  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
      entity_matching_method  = "AnyAlert"
      reopen_closed_incidents = false
    }
  }
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
 }
 resource "azurerm_sentinel_alert_rule_scheduled" "failed_login_flood" {
  name                       = "FailedLoginFloodDetection"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Failed Login Flood (Password Spray)"
  
  enabled           = true
  query_frequency   = "PT1H"
  query_period      = "P1D"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "High"
  tactics  = ["CredentialAccess"]
  
  query = file("${path.module}/../kql-queries/failed-login-flood-detection.kql")
  
  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
      entity_matching_method  = "AnyAlert"
      reopen_closed_incidents = false
    }
  }
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
 }
resource "azurerm_sentinel_alert_rule_scheduled" "privilege_escalation" {
  name                       = "PrivilegeEscalationDetection"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  display_name               = "Unauthorized Privilege Escalation"
  
  enabled           = true
  query_frequency   = "PT1H"
  query_period      = "P1D"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "High"
  tactics  = ["PrivilegeEscalation"]
  
  query = file("${path.module}/../kql-queries/privilege-escalation-detection.kql")
  
  incident {
    create_incident_enabled = true

    grouping {
      enabled           = true
      lookback_duration = "PT5M"
      entity_matching_method  = "AnyAlert"
      reopen_closed_incidents = false
    }
  }
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.sentinel]
 }

# ===========================
# Defender for Cloud (Security Score)
# ===========================

# Security contact already exists (name must be 'default')
# Import it if you want Terraform to manage it:
#   terraform import azurerm_security_center_contact.security_contact "/subscriptions/645a9291-908c-4ee8-b187-9b84d1e25a36/providers/Microsoft.Security/securityContacts/default"
# Or comment out to leave it as-is:

# resource "azurerm_security_center_contact" "security_contact" {
#   email               = "chaitra.shashikala@gmail.com"
#   phone               = "+917204426101"
#   alert_notifications = true
#   alerts_to_admins    = true
# }


resource "azurerm_security_center_subscription_pricing" "defender_vms" {
  tier          = "Free"  # No extra cost tier for Virtual Machines
  resource_type = "VirtualMachines"
}

# ===========================
# Azure Key Vault (Secure Secret Storage)
# ===========================

# Generate a random suffix for naming uniqueness
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "identity_vault" {
  name                       = "kv-identity-${random_string.suffix.result}"
  location                   = data.azurerm_resource_group.identity_lab.location
  resource_group_name        = data.azurerm_resource_group.identity_lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7   # Can recover deleted secrets for 7 days
  purge_protection_enabled   = true  # Prevent permanent deletion during retention period
  enable_rbac_authorization  = true  # Role Based Access Control for permissions
  
  network_acls {
    default_action = "Allow"  # Changed from Deny to allow GitHub Actions
    bypass         = "AzureServices"  # Allow trusted Azure services
    ip_rules       = []  # Can add specific IPs later if needed
  }
  
  tags = var.tags
}


resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.identity_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}


resource "azurerm_key_vault_secret" "teams_webhook" {
  name         = "teams-webhook-url"
  value        = var.teams_webhook_url
  key_vault_id = azurerm_key_vault.identity_vault.id

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

