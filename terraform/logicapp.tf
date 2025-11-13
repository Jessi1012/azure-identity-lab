# LOGIC APP (Automation)

resource "azurerm_logic_app_workflow" "auto_remediate" {
  name                = "identity-auto-remediate"
  location            = azurerm_resource_group.identity_lab.location
  resource_group_name = azurerm_resource_group.identity_lab.name
  tags                = var.tags
}

# LOGIC APP TRIGGER (HTTP Request)

resource "azurerm_logic_app_trigger_http_request" "sentinel_trigger" {
  name         = "When-Sentinel-Alert-Fires"
  logic_app_id = azurerm_logic_app_workflow.auto_remediate.id
  schema = jsonencode({
    type = "object"
    properties = {
      IncidentTitle     = { type = "string" }
      UserPrincipalName = { type = "string" }
      Severity          = { type = "string" }
      IncidentUrl       = { type = "string" }
    }
  })
}

# LOGIC APP ACTION 1: Send Teams Alert

resource "azurerm_logic_app_action_http" "teams_alert" {
  name         = "Send-Teams-Alert"
  logic_app_id = azurerm_logic_app_workflow.auto_remediate.id
  method       = "POST"
  uri          = azurerm_key_vault_secret.teams_webhook.value
  headers = {
    "Content-Type" = "application/json"
  }
  body = jsonencode({
    title = "🚨 SECURITY ALERT: Identity Threat Detected"
    sections = [{
      activityTitle = "@{triggerBody()?['IncidentTitle']}"
      facts = [
        { name = "User", value = "@{triggerBody()?['UserPrincipalName']}" },
        { name = "Severity", value = "@{triggerBody()?['Severity']}" },
        { name = "Time", value = "@{utcNow()}" },
        { name = "Action Taken", value = "Account automatically disabled" }
      ]
    }]
  })
}
