# Deployment Guide - Azure Sentinel Identity Lab

## Overview

This project uses an **incremental deployment model**:

- **First Deployment**: Creates ALL resources (workspace, Sentinel, Key Vault, alert rules)
- **Subsequent Deployments**: Only adds/updates KQL alert rules, preserves existing infrastructure

## How It Works

### 🆕 First Deployment (Automatic Detection)

The workflow automatically detects if the Log Analytics workspace exists:

1. **If workspace DOESN'T exist** → Creates everything from scratch
2. **If workspace EXISTS** → Only manages alert rules (incremental)

### ✅ Adding New KQL Queries

When you add a new `.kql` file and corresponding Terraform alert rule:

1. Add your KQL query to `kql-queries/your-new-query.kql`
2. Add the alert rule definition in `terraform/main.tf`:
   ```terraform
   resource "azurerm_sentinel_alert_rule_scheduled" "your_new_rule" {
     name                       = "YourNewRuleName"
     log_analytics_workspace_id = local.workspace_id  # Uses existing workspace!
     display_name               = "Your Rule Display Name"
     # ... other configuration
     query = file("${path.module}/../kql-queries/your-new-query.kql")
   }
   ```
3. Commit and push:
   ```bash
   git add kql-queries/your-new-query.kql terraform/main.tf
   git commit -m "Add new detection rule: Your Rule Name"
   git push origin feature/test-deployment
   ```
4. The workflow **automatically**:
   - Detects existing workspace
   - Preserves all existing resources
   - Adds ONLY your new alert rule

### 🔧 Manual Override (Force Recreation)

If you need to recreate the workspace (rare), update the workflow env variable:

```yaml
TF_VAR_create_workspace: "true"  # Change from "false" to "true"
```

⚠️ **Warning**: This will delete and recreate the workspace!

## Workflow Behavior

### Incremental Deployment (Normal)
```
✅ Workspace exists
✅ Sentinel onboarding exists  
✅ Key Vault exists
✅ Existing alert rules preserved
➕ New alert rules added
🔄 Changed alert rules updated
```

### First Deployment
```
🆕 Create Resource Group (data source)
🆕 Create Log Analytics Workspace
🆕 Enable Sentinel
🆕 Create Key Vault
🆕 Create all alert rules
🆕 Create Logic App
```

## State Management

- **Remote State**: Stored in Azure Storage (`tfstateb54w9t` container)
- **State Protection**: `prevent_destroy` lifecycle on critical resources
- **Automatic Detection**: Workflow checks Azure for existing resources

## Adding New Alert Rules

### Step 1: Create KQL Query
```kql
// kql-queries/suspicious-activity.kql
SigninLogs
| where TimeGenerated > ago(1h)
| where RiskLevelDuringSignIn == "high"
| project TimeGenerated, UserPrincipalName, IPAddress, Location
```

### Step 2: Add Terraform Resource
```terraform
resource "azurerm_sentinel_alert_rule_scheduled" "suspicious_activity" {
  name                       = "SuspiciousActivityDetection"
  log_analytics_workspace_id = local.workspace_id  # Important!
  display_name               = "High Risk Sign-in Detected"
  
  enabled           = true
  query_frequency   = "PT1H"
  query_period      = "PT1H"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "High"
  tactics  = ["InitialAccess"]
  
  query = file("${path.module}/../kql-queries/suspicious-activity.kql")
  
  incident {
    create_incident_enabled = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT5M"
      entity_matching_method  = "AnyAlert"
      reopen_closed_incidents = false
    }
  }
  
  depends_on = [
    azurerm_sentinel_log_analytics_workspace_onboarding.sentinel,
    time_sleep.wait_for_sentinel
  ]
}
```

### Step 3: Push and Deploy
```bash
git add .
git commit -m "Add suspicious activity detection rule"
git push origin feature/test-deployment
```

The workflow automatically deploys your new rule without touching existing resources! 🚀

## Troubleshooting

### "Workspace not found" errors
- The workflow will automatically detect and fix this
- Existing workspace is used via `data` source and `local.workspace_id`

### Alert rule conflicts
- Alert rules are managed by Terraform
- Manually created rules in Azure Portal won't conflict
- To import manually-created rules, add them to Terraform

### Force clean deployment
- Delete the state blob in Azure Storage
- Set `TF_VAR_create_workspace=true` in workflow
- Push to trigger full recreation
