# 🎯 Complete Terraform Automation - Setup Guide

## 📋 What This Achieves

**100% Automated Infrastructure Management:**
- ✅ First `terraform apply` → Creates EVERYTHING (Resource Group, Storage Account, Workspace, Sentinel, Alert Rules, Key Vault, Logic App)
- ✅ Second `terraform apply` → Shows "No changes" (idempotent)
- ✅ Add new resource → Only creates the new one
- ✅ Someone deletes Storage Account → `terraform apply` recreates it automatically
- ✅ Someone deletes ANY resource → Terraform detects and recreates it

---

## 🚀 Quick Start (First Time Setup)

### **Step 1: Clean Start**

```powershell
cd C:\Users\chait\Documents\azure-identity-lab\terraform

# Remove any existing local state
Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item terraform.tfstate* -ErrorAction SilentlyContinue
```

---

### **Step 2: Initialize Terraform (Local State)**

```powershell
terraform init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Installing hashicorp/azurerm v3.85.0...
# - Installing hashicorp/time v0.9.2...
# Terraform has been successfully initialized!
```

**Note:** This uses **local state** (stored in `terraform/terraform.tfstate` on your computer).

---

### **Step 3: Preview What Will Be Created**

```powershell
terraform plan

# Expected output shows 18 resources to create:
# Plan: 18 to add, 0 to change, 0 to destroy.
#
# Resources to create:
#  1. azurerm_resource_group.identity_lab
#  2. azurerm_storage_account.tfstate (NEW - for state storage)
#  3. azurerm_storage_container.tfstate (NEW - tfstate container)
#  4. azurerm_log_analytics_workspace.identity_logs
#  5. azurerm_sentinel_log_analytics_workspace_onboarding.sentinel
#  6. time_sleep.wait_for_sentinel
#  7-11. azurerm_sentinel_alert_rule_scheduled (5 alert rules)
# 12. azurerm_key_vault.identity_vault
# 13. azurerm_role_assignment.keyvault_admin
# 14. azurerm_key_vault_secret.teams_webhook
# 15. azurerm_logic_app_workflow.auto_remediate
# 16. azurerm_logic_app_trigger_http_request.sentinel_trigger
# 17. azurerm_logic_app_action_http.teams_alert
# 18. azurerm_security_center_subscription_pricing.defender_vms
```

---

### **Step 4: Create Everything**

```powershell
terraform apply

# You'll be prompted:
# Do you want to perform these actions?
#   Enter a value: yes

# Terraform creates resources in dependency order:
# ✅ Resource Group created (2s)
# ✅ Storage Account created (25s)
# ✅ Storage Container created (3s)
# ✅ Log Analytics Workspace created (45s)
# ✅ Sentinel enabled (30s)
# ⏳ Waiting 180s for Sentinel API...
# ✅ Alert rules created (5 x 40s = 200s)
# ✅ Key Vault created (35s)
# ✅ Logic App created (25s)
# 
# Apply complete! Resources: 18 added, 0 changed, 0 destroyed.
#
# Outputs:
# resource_group_name = "Identity-Lab-RG"
# storage_account_name = "tfstateb54w9t"
# state_container_name = "tfstate"
# workspace_name = "identity-lab-logs-v3"
# key_vault_name = "kv-identity-5n7ekf"
```

**Total time: ~8-10 minutes**

---

## ✅ Verification Steps

### **Verify in Azure Portal:**

```powershell
# List all resources in Resource Group
az resource list --resource-group Identity-Lab-RG --output table

# Expected output:
# Name                        Type                                      Location
# --------------------------  ----------------------------------------  ----------
# Identity-Lab-RG             ResourceGroup                             eastus
# tfstateb54w9t               StorageAccount                            eastus
# identity-lab-logs-v3        Log Analytics Workspace                   eastus
# kv-identity-5n7ekf          Key Vault                                 eastus
# identity-auto-remediate     Logic App                                 eastus
# (Plus 5 Sentinel alert rules)
```

### **Verify State File Exists:**

```powershell
# Check local state file
Test-Path terraform.tfstate
# Should return: True

# Check state file content
terraform show
# Shows all 18 resources tracked in state
```

---

## 🔄 Testing Idempotency

### **Test 1: Run Apply Again (No Changes)**

```powershell
terraform apply

# Expected output:
# azurerm_resource_group.identity_lab: Refreshing state...
# azurerm_storage_account.tfstate: Refreshing state...
# ... (checks all 18 resources)
#
# No changes. Your infrastructure matches the configuration.
#
# Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**Time: ~2 minutes (just verification, no API calls to create/update)**

✅ **Result:** Terraform confirms everything already exists, does nothing. Perfect!

---

### **Test 2: Add New Alert Rule**

```powershell
# Edit main.tf, add new rule after line 290:
code terraform/main.tf
```

Add this code:
```terraform
resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "BruteForceDetection"
  log_analytics_workspace_id = local.workspace_id
  display_name               = "Brute Force Attack Detected"
  
  enabled           = true
  query_frequency   = "PT5M"
  query_period      = "PT1H"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  
  severity = "High"
  tactics  = ["CredentialAccess"]
  
  query = <<-QUERY
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType != 0
    | summarize FailedAttempts = count() by UserPrincipalName, IPAddress
    | where FailedAttempts > 10
  QUERY
  
  incident {
    create_incident_enabled = true
  }
  
  depends_on = [time_sleep.wait_for_sentinel]
}
```

Run apply:
```powershell
terraform apply

# Expected output:
# ... (refreshes existing 18 resources - no changes)
#
# Terraform will perform the following actions:
#
#   # azurerm_sentinel_alert_rule_scheduled.brute_force will be created
#   + resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
#       + name     = "BruteForceDetection"
#       + severity = "High"
#       ...
#     }
#
# Plan: 1 to add, 0 to change, 0 to destroy.
#
# Enter a value: yes
#
# azurerm_sentinel_alert_rule_scheduled.brute_force: Creating...
# azurerm_sentinel_alert_rule_scheduled.brute_force: Creation complete after 42s
#
# Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

✅ **Result:** Only new rule created! Existing 18 resources untouched!

---

### **Test 3: Someone Manually Deletes Storage Account**

```powershell
# Simulate disaster - delete storage account manually
az storage account delete \
  --name tfstateb54w9t \
  --resource-group Identity-Lab-RG \
  --yes

# Storage account is now GONE!

# Run terraform plan
terraform plan

# Expected output:
# azurerm_storage_account.tfstate: Refreshing state...
#
# ⚠️ Warning: Resource not found
# The resource azurerm_storage_account.tfstate does not exist in Azure,
# but is tracked in state. Terraform will recreate it.
#
# Terraform will perform the following actions:
#
#   # azurerm_storage_account.tfstate will be created
#   + resource "azurerm_storage_account" "tfstate" {
#       + name                     = "tfstateb54w9t"
#       + account_tier             = "Standard"
#       + account_replication_type = "LRS"
#       ...
#     }
#
#   # azurerm_storage_container.tfstate will be created
#   + resource "azurerm_storage_container" "tfstate" {
#       + name = "tfstate"
#       ...
#     }
#
# Plan: 2 to add, 0 to change, 0 to destroy.

# Recreate the deleted resources
terraform apply

# Enter a value: yes
#
# azurerm_storage_account.tfstate: Creating...
# azurerm_storage_account.tfstate: Creation complete after 28s
# azurerm_storage_container.tfstate: Creating...
# azurerm_storage_container.tfstate: Creation complete after 3s
#
# Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

✅ **Result:** Storage account automatically recreated! Infrastructure self-heals!

---

## 🎯 What Terraform Now Manages

| Resource | Managed? | Auto-Recreates if Deleted? |
|----------|----------|----------------------------|
| Resource Group | ✅ Yes | ✅ Yes |
| Storage Account (tfstate) | ✅ Yes | ✅ Yes |
| Storage Container (tfstate) | ✅ Yes | ✅ Yes |
| Log Analytics Workspace | ✅ Yes | ✅ Yes |
| Sentinel | ✅ Yes | ✅ Yes |
| Alert Rules (5 rules) | ✅ Yes | ✅ Yes |
| Key Vault | ✅ Yes | ✅ Yes |
| Key Vault Secret | ✅ Yes | ✅ Yes |
| Logic App | ✅ Yes | ✅ Yes |

**Total: 100% of infrastructure managed by Terraform**

---

## 🔄 Workflow Summary

```
┌─────────────────────────────────────────────────────────┐
│ SCENARIO 1: First Deployment                            │
├─────────────────────────────────────────────────────────┤
│ terraform apply → Creates 18 resources (10 min)         │
│ Result: Everything deployed from scratch ✅              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCENARIO 2: No Changes                                  │
├─────────────────────────────────────────────────────────┤
│ terraform apply → "No changes" (2 min)                  │
│ Result: Terraform verifies, does nothing ✅              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCENARIO 3: Add New Resource                            │
├─────────────────────────────────────────────────────────┤
│ terraform apply → Creates 1 new (5 min)                 │
│ Result: Only new resource created ✅                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCENARIO 4: Modify Existing Resource                    │
├─────────────────────────────────────────────────────────┤
│ terraform apply → Updates 1 in-place (2 min)            │
│ Result: Only changed attributes updated ✅               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ SCENARIO 5: Someone Deletes Resource                    │
├─────────────────────────────────────────────────────────┤
│ terraform apply → Recreates missing (3 min)             │
│ Result: Infrastructure self-heals ✅                     │
└─────────────────────────────────────────────────────────┘
```

---

## 🎤 Interview Talking Points

### **"How does your Terraform handle infrastructure?"**

> "My Terraform configuration achieves 100% infrastructure automation. Running `terraform apply` the first time creates everything - resource group, storage account for state management, Log Analytics workspace, Sentinel with 5 alert rules, Key Vault, and Logic App.
>
> The key innovation is that even the Terraform state storage account is managed by Terraform itself, using local state initially to avoid the chicken-egg problem. This means if someone accidentally deletes the storage account, running `terraform apply` detects it and recreates it automatically.
>
> The infrastructure is fully idempotent - I can run apply 100 times and it will only make changes when the code changes. If I add a new alert rule, it creates only that rule. If someone manually changes retention settings in Azure Portal, Terraform detects the drift and reverts it back to match the code.
>
> This demonstrates Infrastructure as Code best practices where code is the single source of truth, and manual changes are automatically corrected."

---

## 🚨 Important Notes

### **State Management Strategy:**

**Current (Local State):**
```
✅ Simple - no backend setup
✅ Works immediately
❌ State on local computer only
❌ GitHub Actions won't work (needs remote state)
```

**To Enable GitHub Actions (Optional):**

After first successful deployment, migrate to remote backend:

```powershell
# Uncomment backend block in backend.tf
code terraform/backend.tf

# Uncomment this:
terraform {
  backend "azurerm" {
    resource_group_name  = "Identity-Lab-RG"
    storage_account_name = "tfstateb54w9t"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# Migrate state
terraform init -migrate-state

# Confirm migration:
# Would you like to copy existing state to the new backend?
# Enter a value: yes

# ✅ State now in Azure Storage
# ✅ GitHub Actions can access it
# ✅ Team can collaborate
```

---

## ✅ Summary

**What You Achieved:**
- ✅ 100% automated infrastructure (no manual setup needed)
- ✅ Self-healing (deleted resources auto-recreate)
- ✅ Idempotent (safe to run multiple times)
- ✅ Incremental updates (only changes what's different)
- ✅ Drift detection (manual changes detected)
- ✅ Complete state management (including state storage itself)

**Commands You Need:**
```powershell
terraform init   # First time setup
terraform plan   # Preview changes
terraform apply  # Create/update infrastructure
terraform show   # View current state
terraform destroy # Delete everything (if needed)
```

**Your infrastructure is now production-ready and fully automated!** 🎉
