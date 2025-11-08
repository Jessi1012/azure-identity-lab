output "resource_group_name" {
  value = data.azurerm_resource_group.identity_lab.name
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.identity_logs.id
}

output "workspace_name" {
  value = azurerm_log_analytics_workspace.identity_logs.name
}

output "key_vault_id" {
  value = azurerm_key_vault.identity_vault.id
}

output "detection_rules" {
  value = [
    azurerm_sentinel_alert_rule_scheduled.dormant_account.display_name,
    azurerm_sentinel_alert_rule_scheduled.impossible_travel.display_name,
    azurerm_sentinel_alert_rule_scheduled.failed_login_flood.display_name,
    azurerm_sentinel_alert_rule_scheduled.privilege_escalation.display_name,
  ]
}

output "deployment_summary" {
  value = <<-EOT
✅ DEPLOYMENT COMPLETE!
Resource Group: ${data.azurerm_resource_group.identity_lab.name}
Workspace: ${azurerm_log_analytics_workspace.identity_logs.name}
Key Vault: ${azurerm_key_vault.identity_vault.name}
4 Detection Rules Deployed
Defender: ENABLED
Monthly Cost: ~$9
EOT
}