# outputs.tf

output "resource_group_name" {
  value       = data.azurerm_resource_group.identity_lab.name
  description = "Name of the resource group created"
}

output "workspace_id" {
  value       = local.workspace_id
  description = "ID of Log Analytics workspace"
}

output "workspace_name" {
  value       = var.workspace_name
  description = "Name of Log Analytics workspace"
}

output "key_vault_id" {
  value       = azurerm_key_vault.identity_vault.id
  description = "ID of Key Vault created"
}

output "detection_rules" {
  value       = [
    azurerm_sentinel_alert_rule_scheduled.dormant_account.display_name,
    azurerm_sentinel_alert_rule_scheduled.impossible_travel.display_name,
    azurerm_sentinel_alert_rule_scheduled.failed_login_flood.display_name,
    azurerm_sentinel_alert_rule_scheduled.privilege_escalation.display_name
  ]
  description = "List of detection rules deployed"
}

output "deployment_summary" {
  value = <<-EOT
✅ DEPLOYMENT COMPLETE!
Resource Group: ${data.azurerm_resource_group.identity_lab.name}
Workspace: ${var.workspace_name}
Key Vault: ${azurerm_key_vault.identity_vault.name}

4 Detection Rules Deployed:
- Dormant Account Reactivation
- Impossible Travel Detection
- Failed Login Flood (Password Spray)
- Privilege Escalation

Logic App: Automated response enabled
Defender for Cloud: ENABLED
Azure Policies: 2 assigned
Monthly Cost: ~$9

Next Steps:
1. Go to Azure Portal
2. Search "Microsoft Sentinel"
3. Check incidents
4. Run KQL queries in Logs
EOT
  description = "Complete deployment summary"
}
