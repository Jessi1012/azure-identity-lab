# 🔄 Complete Workflow Deep Dive
## How Git Push → Azure Deployment Works (Step-by-Step)

---

## 📋 Table of Contents
1. [Why Feature Branches Instead of Main?](#why-feature-branches-instead-of-main)
2. [Complete Workflow Timeline](#complete-workflow-timeline)
3. [Terraform Idempotency Explained](#terraform-idempotency-explained)
4. [Pull Request Workflow](#pull-request-workflow)
5. [State Management Deep Dive](#state-management-deep-dive)

---

## 🌿 Why Feature Branches Instead of Main?

### **The Problem with Pushing Directly to Main**

```
❌ DANGEROUS WORKFLOW (Direct to Main):
┌──────────────────────────────────────────────────────────┐
│  Developer's Laptop                                      │
│  ├── Make changes to Terraform code                     │
│  ├── git commit -m "update"                             │
│  └── git push origin main                               │
└──────────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────┐
│  GitHub Actions (Triggered immediately)                  │
│  ├── No validation                                       │
│  ├── No review                                           │
│  ├── Deploys to PRODUCTION immediately                  │
│  └── ⚠️ Oops! Bug in code → Production is broken        │
└──────────────────────────────────────────────────────────┘
```

**Real-world disaster scenario:**
```terraform
# Developer accidentally deletes this line:
# resource "azurerm_log_analytics_workspace" "identity_logs" {

# Pushes to main
# Terraform sees: "Workspace not in code anymore"
# Terraform does: DELETE workspace from Azure
# Result: ALL ALERT RULES DELETED, MONITORING DOWN
# Impact: Security blind spot for hours
# Cost: Potential breach, compliance violation
```

---

### **✅ The Safe Way: Feature Branch Workflow**

```
SAFE WORKFLOW (Feature → PR → Main):
┌──────────────────────────────────────────────────────────┐
│  Developer's Laptop                                      │
│  ├── git checkout -b feature/add-brute-force-rule       │
│  ├── Make changes to Terraform code                     │
│  ├── git commit -m "feat: Add brute force detection"    │
│  └── git push origin feature/add-brute-force-rule       │
└──────────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────┐
│  GitHub Actions (Test Environment)                       │
│  ├── ✅ Security scans run                              │
│  ├── ✅ Terraform plan shows changes                    │
│  ├── ✅ Deploy to TEST environment                      │
│  ├── ⚠️ Bug discovered in testing                       │
│  └── ✅ Fix bug before it reaches production            │
└──────────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────┐
│  Pull Request Created                                    │
│  ├── Team reviews code                                   │
│  ├── Terraform plan attached                            │
│  ├── Security scans visible                             │
│  ├── Questions answered                                 │
│  └── ✅ Approved by reviewer                            │
└──────────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────┐
│  Merge to Main                                           │
│  ├── All checks passed                                   │
│  ├── Code reviewed and approved                         │
│  └── Deploy to PRODUCTION (with confidence!)            │
└──────────────────────────────────────────────────────────┘
```

---

### **Branch Strategy Benefits**

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Safety Net** | Test changes without affecting production | Production stays stable |
| **Code Review** | Team catches bugs before deployment | Higher code quality |
| **Rollback Easy** | Can delete feature branch without affecting main | Quick recovery |
| **Parallel Work** | Multiple developers on different features | Faster development |
| **Audit Trail** | Clear history of what changed when | Compliance requirement |
| **Learning** | Junior developers safe to experiment | Better training |

---

## ⏱️ Complete Workflow Timeline

### **STAGE 1: Local Development (Your Laptop)**

```
[TIME: 10-30 minutes - One-time setup]

┌──────────────────────────────────────────────────────────┐
│  YOUR LAPTOP: C:\Users\chait\Documents\azure-identity-lab│
└──────────────────────────────────────────────────────────┘

Step 1: Create Feature Branch
```
```powershell
# Check current branch
PS> git branch
* main

# Create and switch to feature branch
PS> git checkout -b feature/add-brute-force-detection
Switched to a new branch 'feature/add-brute-force-detection'

# Verify you're on feature branch
PS> git branch
  main
* feature/add-brute-force-detection
```

```
Step 2: Make Code Changes
```
```powershell
# Edit Terraform code
PS> code terraform/main.tf

# Add new alert rule
resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "Brute Force Attack Detection"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.identity_logs.id
  
  query = file("${path.module}/../kql-queries/brute-force-detection.kql")
  
  query_frequency = "PT5M"  # Every 5 minutes
  query_period    = "PT1H"  # Look at last hour
  
  severity = "High"
  enabled  = true
  
  incident_configuration {
    create_incident = true
  }
}

# Create KQL query file
PS> code kql-queries/brute-force-detection.kql

SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0  // Failed logins only
| summarize FailedAttempts = count() by UserPrincipalName, IPAddress
| where FailedAttempts > 10
| project UserPrincipalName, IPAddress, FailedAttempts, TimeGenerated
```

```
Step 3: Local Testing (Optional but Recommended)
```
```powershell
# Format code
PS> cd terraform
PS> terraform fmt
main.tf

# Validate syntax
PS> terraform validate
Success! The configuration is valid.

# Plan (see what would change)
PS> terraform plan
# NOTE: This queries Azure, shows what would be created
# Does NOT actually create anything

Terraform will perform the following actions:

  # azurerm_sentinel_alert_rule_scheduled.brute_force will be created
  + resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
      + name     = "Brute Force Attack Detection"
      + severity = "High"
      + enabled  = true
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

```
Step 4: Commit Changes
```
```powershell
# Stage files for commit
PS> git add terraform/main.tf
PS> git add kql-queries/brute-force-detection.kql
PS> git add docs/README.md  # Updated documentation

# Check what will be committed
PS> git status
On branch feature/add-brute-force-detection
Changes to be committed:
  modified:   terraform/main.tf
  new file:   kql-queries/brute-force-detection.kql
  modified:   docs/README.md

# Commit with descriptive message
PS> git commit -m "feat: Add brute force attack detection rule

- New alert rule triggers on 10+ failed logins per user in 1 hour
- High severity incident created automatically
- KQL query optimized for performance
- Documentation updated with detection logic"

[feature/add-brute-force-detection abc1234] feat: Add brute force attack detection rule
 3 files changed, 45 insertions(+), 2 deletions(-)
```

```
Step 5: Push to GitHub
```
```powershell
# Push feature branch to GitHub
PS> git push origin feature/add-brute-force-detection

Enumerating objects: 12, done.
Counting objects: 100% (12/12), done.
Delta compression using up to 16 threads
Compressing objects: 100% (8/8), done.
Writing objects: 100% (8/8), 1.2 KiB | 1.2 MiB/s, done.
Total 8 (delta 5), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (5/5), completed with 4 local objects.
To https://github.com/Jessi1012/azure-identity-lab.git
 * [new branch]      feature/add-brute-force-detection -> feature/add-brute-force-detection

✅ YOUR WORK IS DONE! GitHub takes over from here.
```

---

### **STAGE 2: GitHub Actions Automation (Cloud)**

```
[TIME: 12-15 minutes - Fully Automated]

Triggered by: git push origin feature/add-brute-force-detection
Workflow file: .github/workflows/deploy.yml
Runner: ubuntu-latest (GitHub provides fresh Linux VM)
```

---

#### **[00:00 - 00:30] STEP 1: Checkout Code**

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

**What happens:**
```bash
# GitHub Actions VM starts (fresh Ubuntu 22.04)
$ git clone https://github.com/Jessi1012/azure-identity-lab.git
$ git checkout feature/add-brute-force-detection
$ cd azure-identity-lab

# Files now available:
├── terraform/main.tf (your changes)
├── kql-queries/brute-force-detection.kql (new file)
├── .github/workflows/deploy.yml (this workflow)
└── All other project files
```

---

#### **[00:30 - 02:00] STEP 2: Security Scans (Parallel)**

**Three scans run simultaneously to save time:**

**Scan 1: CodeQL (JavaScript/Python Security)**
```yaml
- name: CodeQL Analysis
  uses: github/codeql-action/analyze@v3
```
```
Scanning for:
├── SQL injection vulnerabilities
├── Cross-site scripting (XSS)
├── Command injection
├── Path traversal
├── Hardcoded secrets
└── Insecure cryptography

Files scanned:
├── terraform/logicapp-definition.json (JavaScript in Logic App)
└── scripts/*.py (if any Python scripts)

Result: ✅ No vulnerabilities found
Time: 1 minute 23 seconds
```

**Scan 2: tfsec (Terraform Security)**
```yaml
- name: tfsec Security Scan
  uses: aquasecurity/tfsec-action@v1.0.3
```
```
Checking terraform/ directory for:
├── AZU001: Key Vault firewall not enabled
├── AZU002: Storage account insecure transfer
├── AZU003: NSG allows unrestricted access
├── AZU004: Missing encryption at rest
└── 500+ other Azure security rules

Result:
✅ HIGH: 0 issues
⚠️ MEDIUM: 1 issue (Key Vault firewall recommended for production)
ℹ️ LOW: 2 issues (optional improvements)

Time: 45 seconds
```

**Scan 3: Checkov (Compliance Validation)**
```yaml
- name: Checkov Compliance Scan
  uses: bridgecrewio/checkov-action@master
```
```
Validating against:
├── CIS Azure Foundations Benchmark v1.4.0
├── HIPAA compliance requirements
├── PCI-DSS v3.2.1 standards
├── GDPR data protection rules
└── NIST 800-53 controls

Checks: 1,247 rules evaluated
├── PASSED: 1,189 (95.3%)
├── FAILED: 18 (optional recommendations)
├── SKIPPED: 40 (not applicable)

Result: ✅ Compliant (passing score > 90%)
Time: 1 minute 10 seconds
```

**If any CRITICAL or HIGH security issues found:**
```
❌ Workflow STOPS here
❌ No deployment happens
📧 Email sent: "Security issues detected in commit abc1234"
📊 SARIF results uploaded to:
   https://github.com/Jessi1012/azure-identity-lab/security/code-scanning
```

---

#### **[02:00 - 02:30] STEP 3: Terraform Validation**

```yaml
- name: Terraform Validate
  working-directory: ./terraform
  run: terraform validate
```

**What it checks:**
```hcl
Validation checks:
├── Syntax errors (missing brackets, commas, quotes)
├── Resource type names (typos like "azurem_" instead of "azurerm_")
├── Required arguments present
├── Variable references valid
├── Provider configurations correct
└── HCL structure valid

Example errors caught:
❌ resource "azurerm_sentinel_alert_rule" "brute_force" {
     # Missing required argument: log_analytics_workspace_id
   }

❌ query = file("${path.module}/../kql-queries/missing-file.kql")
     # File not found

✅ All validation passed
   - 16 resource blocks validated
   - 9 data sources validated
   - 12 variables declared
   - 0 syntax errors
```

---

#### **[02:30 - 03:00] STEP 4: Azure Authentication**

```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**Behind the scenes:**
```json
// GitHub retrieves secret AZURE_CREDENTIALS
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "***REDACTED***",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

```bash
# Azure login command executed
$ az login \
    --service-principal \
    --username xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
    --password ***REDACTED*** \
    --tenant xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

[
  {
    "cloudName": "AzureCloud",
    "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "isDefault": true,
    "name": "Identity Lab Subscription",
    "state": "Enabled",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "user": {
      "name": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "type": "servicePrincipal"
    }
  }
]

✅ Authentication successful
✅ Connected to subscription: Identity Lab (xxxxxxxx...)
```

**Environment variables set for Terraform:**
```bash
export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_CLIENT_SECRET="***"  # Masked in logs
export ARM_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

---

#### **[03:00 - 04:00] STEP 5: Terraform Init**

```yaml
- name: Terraform Init
  working-directory: ./terraform
  run: terraform init
```

**Phase 1: Download Providers**
```bash
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Finding hashicorp/time versions matching "~> 0.9"...
- Installing hashicorp/azurerm v3.85.0...
- Installing hashicorp/time v0.9.2...

Downloaded plugins:
├── azurerm (125 MB) → ~/.terraform/plugins/
└── time (5 MB) → ~/.terraform/plugins/

Time: 25 seconds
```

**Phase 2: Configure Backend**
```bash
Initializing the backend...

Backend configuration:
├── Type: azurerm (Azure Storage)
├── Storage Account: tfstateb54w9t
├── Container: tfstate
├── Blob: terraform.tfstate
└── Authentication: Azure AD (via Service Principal)

Connecting to backend...
└── GET https://tfstateb54w9t.blob.core.windows.net/tfstate/terraform.tfstate

✅ Backend configured successfully
✅ State file downloaded (size: 45 KB)
```

**Phase 3: State Locking**
```bash
Acquiring state lock...
└── LEASE https://tfstateb54w9t.blob.core.windows.net/tfstate/terraform.tfstate

Lock acquired:
├── ID: 7069b8a4-a844-d0ab-e979-2468a014cffc
├── Who: github-actions-runner@githubactions.com
├── When: 2025-11-11T10:30:15Z
├── Operation: apply
└── Info: Deployment from feature/add-brute-force-detection

✅ State locked (prevents concurrent modifications)
```

**Output:**
```
Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.
```

---

#### **[04:00 - 06:00] STEP 6: Terraform Plan (CRITICAL STEP)**

```yaml
- name: Terraform Plan
  working-directory: ./terraform
  run: terraform plan -out=tfplan -no-color
```

**Terraform's 3-Way Comparison:**

```
┌──────────────────────────────────────────────────────────┐
│ INPUT 1: Terraform Code (main.tf)                       │
│ "What SHOULD exist"                                      │
├──────────────────────────────────────────────────────────┤
│ resource "azurerm_log_analytics_workspace" {            │
│   name              = "identity-lab-logs-v3"             │
│   retention_in_days = 30                                 │
│ }                                                         │
│                                                           │
│ resource "azurerm_sentinel_alert_rule" "brute_force" {  │
│   name = "Brute Force Detection"  # NEW!                │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────┐
│ INPUT 2: State File (terraform.tfstate)                 │
│ "What Terraform THINKS exists"                           │
├──────────────────────────────────────────────────────────┤
│ {                                                         │
│   "resources": [                                          │
│     {                                                     │
│       "type": "azurerm_log_analytics_workspace",         │
│       "name": "identity_logs",                           │
│       "attributes": {                                     │
│         "id": "/subscriptions/.../identity-lab-logs-v3", │
│         "retention_in_days": 30                          │
│       }                                                   │
│     }                                                     │
│     # brute_force rule NOT in state (doesn't exist yet)  │
│   ]                                                       │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────┐
│ INPUT 3: Azure API (Real-time query)                    │
│ "What ACTUALLY exists in Azure"                          │
├──────────────────────────────────────────────────────────┤
│ GET /subscriptions/.../providers/Microsoft.OperationalInsights/workspaces
│                                                           │
│ Response:                                                 │
│ {                                                         │
│   "name": "identity-lab-logs-v3",                        │
│   "properties": {                                         │
│     "retentionInDays": 30,  # Matches code ✅             │
│     "sku": "PerGB2018"                                    │
│   }                                                       │
│ }                                                         │
│                                                           │
│ GET /subscriptions/.../alertRules                        │
│ # brute_force rule: NOT FOUND                            │
└──────────────────────────────────────────────────────────┘
```

**Terraform's Decision Logic:**

```hcl
// Resource: azurerm_log_analytics_workspace.identity_logs
Code:   retention_in_days = 30
State:  retention_in_days = 30
Azure:  retention_in_days = 30
Decision: ✅ NO CHANGE (all three match, skip this resource)

// Resource: azurerm_sentinel_alert_rule_scheduled.impossible_travel  
Code:   EXISTS (unchanged)
State:  EXISTS (id: /subscriptions/.../impossible-travel)
Azure:  EXISTS (query matches)
Decision: ✅ NO CHANGE (skip this resource)

// Resource: azurerm_sentinel_alert_rule_scheduled.brute_force
Code:   EXISTS (NEW in this commit)
State:  MISSING (not tracked yet)
Azure:  MISSING (not deployed)
Decision: ➕ CREATE (new resource needs to be created)
```

**Plan Output:**
```terraform
Terraform will perform the following actions:

  # azurerm_sentinel_alert_rule_scheduled.brute_force will be created
  + resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
      + id                         = (known after apply)
      + name                       = "Brute Force Attack Detection"
      + log_analytics_workspace_id = "/subscriptions/.../identity-lab-logs-v3"
      + display_name               = "Brute Force Attack Detection"
      + enabled                    = true
      + query                      = <<-EOT
            SigninLogs
            | where TimeGenerated > ago(1h)
            | where ResultType != 0
            | summarize FailedAttempts = count() by UserPrincipalName, IPAddress
            | where FailedAttempts > 10
        EOT
      + query_frequency            = "PT5M"
      + query_period               = "PT1H"
      + severity                   = "High"
      + suppression_duration       = "PT5H"
      + suppression_enabled        = false
      + tactics                    = [
          + "CredentialAccess",
        ]
      + techniques                 = [
          + "T1110",
        ]
      
      + event_grouping {
          + aggregation_method = "AlertPerResult"
        }
      
      + incident_configuration {
          + create_incident        = true
          + grouping {
              + enabled                 = false
              + lookback_duration      = "PT5H"
              + reopen_closed_incidents = false
              + entity_matching_method  = "AllEntities"
            }
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.
─────────────────────────────────────────────────────────────

Saved the plan to: tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"
```

**Why this step is CRITICAL:**
- Shows exactly what will change before it happens
- Catches mistakes (like accidentally deleting resources)
- Provides audit trail for compliance
- Allows human review before deployment
- Prevents surprises in production

---

#### **[06:00 - 13:00] STEP 7: Terraform Apply (Actually Deploy)**

```yaml
- name: Terraform Apply
  working-directory: ./terraform
  run: terraform apply -auto-approve tfplan
```

**Phased Execution:**

```
PHASE 1: Infrastructure Foundation (Already Exists - SKIPPED)
─────────────────────────────────────────────────────────────
azurerm_resource_group.identity_lab: Refreshing state...
  └── Status: ✅ Exists in Azure, no changes needed

azurerm_log_analytics_workspace.identity_logs: Refreshing state...
  └── Status: ✅ Exists in Azure, no changes needed
  └── Time: 0 seconds (skipped API call, used cached state)

azurerm_sentinel_log_analytics_workspace_onboarding.sentinel: Refreshing state...
  └── Status: ✅ Sentinel enabled, no changes needed

PHASE 2: Alert Rules (Create New One)
─────────────────────────────────────────────────────────────
azurerm_sentinel_alert_rule_scheduled.brute_force: Creating...
  
  API Call:
  POST /subscriptions/645a9291.../providers/Microsoft.SecurityInsights/alertRules
  
  Request Body:
  {
    "kind": "Scheduled",
    "properties": {
      "displayName": "Brute Force Attack Detection",
      "enabled": true,
      "query": "SigninLogs | where...",
      "queryFrequency": "PT5M",
      "queryPeriod": "PT1H",
      "severity": "High",
      "incidentConfiguration": {
        "createIncident": true
      }
    }
  }
  
  Response: 201 Created
  {
    "id": "/subscriptions/.../alertRules/brute-force-detection-abc123",
    "name": "brute-force-detection-abc123",
    "properties": {
      "lastModifiedUtc": "2025-11-11T10:35:42Z",
      "provisioningState": "Succeeded"
    }
  }

azurerm_sentinel_alert_rule_scheduled.brute_force: Creation complete after 45s
  └── ID: /subscriptions/.../alertRules/brute-force-detection-abc123

PHASE 3: Other Resources (Already Exist - SKIPPED)
─────────────────────────────────────────────────────────────
azurerm_key_vault.identity_secrets: Refreshing state...
  └── Status: ✅ No changes

azurerm_logic_app_workflow.sentinel_alert: Refreshing state...
  └── Status: ✅ No changes
```

**Apply Complete:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

workspace_id = "/subscriptions/.../identity-lab-logs-v3"
workspace_name = "identity-lab-logs-v3"
alert_rules = [
  "dormant-account-detection",
  "impossible-travel-detection",
  "password-spray-detection",
  "privilege-escalation-detection",
  "vm-deployment-activity",
  "fusion-detection",
  "brute-force-detection"  ← NEW!
]
key_vault_uri = "https://kv-identity-5n7ekf.vault.azure.net/"
logic_app_id = "/subscriptions/.../workflows/sentinel-incident-response"
```

**Time breakdown:**
```
Total: 7 minutes 12 seconds

├── Refreshing existing resources: 1m 30s (check current state)
├── Creating brute_force rule: 45s (API call + provisioning)
├── Waiting for Sentinel to process: 3m 20s (backend processing)
├── Verifying rule is active: 1m 15s (validation queries)
└── Updating state file: 22s (save to Azure Storage)

Comparison to first deployment:
├── First deployment: 14 minutes (created all 15 resources)
└── This deployment: 7 minutes (created only 1 resource)
└── Savings: 50% faster (thanks to idempotency!)
```

---

#### **[13:00 - 14:00] STEP 8: Verification**

```yaml
- name: Verify Deployment
  run: |
    # Test 1: Check Sentinel is responding
    az sentinel workspace show \
      --workspace-name identity-lab-logs-v3 \
      --resource-group Identity-Lab-RG
    
    # Test 2: Verify new alert rule exists and is enabled
    az sentinel alert-rule show \
      --name brute-force-detection-abc123 \
      --workspace-name identity-lab-logs-v3 \
      --resource-group Identity-Lab-RG
    
    # Test 3: Count total alert rules
    az sentinel alert-rule list \
      --workspace-name identity-lab-logs-v3 \
      --query "length(@)"
```

**Verification Results:**
```json
// Test 1: Sentinel Workspace
{
  "name": "identity-lab-logs-v3",
  "provisioningState": "Succeeded",
  "customerId": "abc123-def456-...",
  "sku": {
    "name": "PerGB2018"
  },
  "retentionInDays": 30
}
✅ PASS: Sentinel is operational

// Test 2: Brute Force Alert Rule
{
  "id": "/subscriptions/.../alertRules/brute-force-detection-abc123",
  "name": "Brute Force Attack Detection",
  "properties": {
    "enabled": true,
    "displayName": "Brute Force Attack Detection",
    "severity": "High",
    "query": "SigninLogs | where...",
    "queryFrequency": "PT5M",
    "lastModifiedUtc": "2025-11-11T10:35:42Z",
    "lastExecutionTime": "2025-11-11T10:40:00Z",  ← Already running!
    "lastExecutionStatus": "Succeeded"
  }
}
✅ PASS: New alert rule is enabled and executing

// Test 3: Alert Rules Count
7
✅ PASS: Expected 7 rules (was 6, now 7 with new rule)
```

---

#### **[14:00 - 14:30] STEP 9: State Update & Lock Release**

```bash
# Update state file with new resource
Updating state file...
└── Adding resource to state:
    {
      "type": "azurerm_sentinel_alert_rule_scheduled",
      "name": "brute_force",
      "instances": [{
        "attributes": {
          "id": "/subscriptions/.../alertRules/brute-force-detection-abc123",
          "name": "Brute Force Attack Detection",
          ...
        }
      }]
    }

# Upload state to Azure Storage
PUT https://tfstateb54w9t.blob.core.windows.net/tfstate/terraform.tfstate
Content-Length: 47,234 bytes (was 45,120 bytes)
✅ State file updated

# Release state lock
RELEASE-LEASE https://tfstateb54w9t.blob.core.windows.net/tfstate/terraform.tfstate
Lock ID: 7069b8a4-a844-d0ab-e979-2468a014cffc
✅ Lock released (other workflows can now run)
```

---

#### **[14:30 - 15:00] STEP 10: Reporting & Notification**

```yaml
- name: Post Deployment Summary
  run: |
    echo "## ✅ Deployment Successful" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**Changes:**" >> $GITHUB_STEP_SUMMARY
    echo "- Created: 1 resource (Brute Force Detection alert rule)" >> $GITHUB_STEP_SUMMARY
    echo "- Updated: 0 resources" >> $GITHUB_STEP_SUMMARY
    echo "- Destroyed: 0 resources" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**Metrics:**" >> $GITHUB_STEP_SUMMARY
    echo "- Total alert rules: 7" >> $GITHUB_STEP_SUMMARY
    echo "- Deployment time: 14m 32s" >> $GITHUB_STEP_SUMMARY
    echo "- Status: All systems operational ✅" >> $GITHUB_STEP_SUMMARY
```

**GitHub automatically creates:**

1. **Deployment Badge on Commit:**
   ```
   abc1234 feat: Add brute force attack detection rule
   ✅ Deploy Infrastructure - Successful (14m 32s)
   ```

2. **Deployment Environment Status:**
   ```
   feature/add-brute-force-detection
   └── Deployed to Azure Production
       ├── Environment: eastus
       ├── Resources: 16 total (1 new)
       ├── Time: 2025-11-11 10:45:15 UTC
       └── Triggered by: push event
   ```

3. **Workflow Summary:**
   ```markdown
   ## ✅ Deployment Successful
   
   **Changes:**
   - Created: 1 resource (Brute Force Detection alert rule)
   - Updated: 0 resources
   - Destroyed: 0 resources
   
   **Metrics:**
   - Total alert rules: 7
   - Deployment time: 14m 32s
   - Status: All systems operational ✅
   ```

---

### **STAGE 3: Azure (Your Infrastructure is Now Live)**

```
[TIME: Ongoing - 24/7 Monitoring]

┌──────────────────────────────────────────────────────────┐
│  AZURE SENTINEL (Production Environment)                 │
└──────────────────────────────────────────────────────────┘

New alert rule is now active:
├── Name: Brute Force Attack Detection
├── Status: Enabled ✅
├── Last execution: 2025-11-11T10:40:00Z
├── Next execution: 2025-11-11T10:45:00Z (every 5 minutes)
└── Incidents created: 0 (no threats detected yet)

Monitoring workflow:
Every 5 minutes:
  1. Query runs against SigninLogs table
  2. Checks for users with 10+ failed logins in last hour
  3. If found:
     ├── Create high-severity incident
     ├── Trigger Logic App
     ├── Send Teams notification
     └── Log to incident timeline
  4. If not found:
     └── Log: "No threats detected" (no incident created)
```

---

## 🔄 Terraform Idempotency Explained

### **What is Idempotency?**

**Definition:** Running the same deployment multiple times produces the same result without creating duplicates or errors.

```
Non-Idempotent (BAD):
├── Deploy 1: Creates workspace
├── Deploy 2: ERROR - workspace already exists!
└── Result: Deployment fails

Idempotent (GOOD - Terraform):
├── Deploy 1: Creates workspace
├── Deploy 2: Checks workspace exists → Skips creation
└── Result: Deployment succeeds, no duplicates
```

---

### **How Terraform Achieves Idempotency**

**State File: The Source of Truth**

```json
// terraform.tfstate (simplified)
{
  "version": 4,
  "terraform_version": "1.6.0",
  "serial": 23,  ← Increments with each change
  "resources": [
    {
      "type": "azurerm_log_analytics_workspace",
      "name": "identity_logs",
      "instances": [
        {
          "schema_version": 3,
          "attributes": {
            "id": "/subscriptions/.../identity-lab-logs-v3",
            "name": "identity-lab-logs-v3",
            "location": "eastus",
            "retention_in_days": 30,
            "sku": "PerGB2018",
            "workspace_id": "abc123-def456-...",
            "primary_shared_key": "***"  ← Sensitive, encrypted in state
          },
          "dependencies": [
            "azurerm_resource_group.identity_lab"
          ],
          "create_time": "2025-11-09T08:15:30Z",
          "update_time": "2025-11-09T08:15:30Z"
        }
      ]
    }
  ]
}
```

---

### **Deployment Scenarios (How Terraform Decides)**

#### **Scenario 1: First Deployment (Nothing Exists)**

```
┌──────────────────────────────────────────────────────────┐
│ BEFORE DEPLOYMENT                                        │
├──────────────────────────────────────────────────────────┤
│ Code:   resource "azurerm_log_analytics_workspace" {...}│
│ State:  {} (empty)                                       │
│ Azure:  Nothing deployed                                 │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ CREATE workspace (doesn't exist anywhere)                │
├──────────────────────────────────────────────────────────┤
│ AFTER DEPLOYMENT                                         │
│ Code:   resource "azurerm_log_analytics_workspace" {...}│
│ State:  { workspace: {...} } ← Added to state            │
│ Azure:  workspace exists ✅                               │
└──────────────────────────────────────────────────────────┘

Duration: 14 minutes (creates all resources from scratch)
```

---

#### **Scenario 2: Second Deployment (No Changes)**

```
┌──────────────────────────────────────────────────────────┐
│ BEFORE DEPLOYMENT                                        │
├──────────────────────────────────────────────────────────┤
│ Code:   retention_in_days = 30                           │
│ State:  retention_in_days = 30                           │
│ Azure:  retention_in_days = 30                           │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ NO CHANGE (all three match perfectly)                    │
│ Skip API call (optimization)                             │
├──────────────────────────────────────────────────────────┤
│ AFTER DEPLOYMENT                                         │
│ Nothing changes                                           │
└──────────────────────────────────────────────────────────┘

Duration: 2 minutes (just validates, no API calls to Azure)
Plan output: "No changes. Your infrastructure matches the configuration."
```

---

#### **Scenario 3: Add New Resource**

```
┌──────────────────────────────────────────────────────────┐
│ BEFORE DEPLOYMENT                                        │
├──────────────────────────────────────────────────────────┤
│ Code:   Workspace ✅, 6 alert rules ✅, brute_force ✅  │
│ State:  Workspace ✅, 6 alert rules ✅                   │
│ Azure:  Workspace ✅, 6 alert rules ✅                   │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ - Workspace: SKIP (exists, no changes)                   │
│ - 6 alert rules: SKIP (exist, no changes)                │
│ - brute_force: CREATE (new in code)                      │
├──────────────────────────────────────────────────────────┤
│ AFTER DEPLOYMENT                                         │
│ Code:   Workspace, 7 rules (added 1)                     │
│ State:  Workspace, 7 rules (state updated)               │
│ Azure:  Workspace, 7 rules (deployed)                    │
└──────────────────────────────────────────────────────────┘

Duration: 7 minutes (only creates 1 new resource)
Plan output: "Plan: 1 to add, 0 to change, 0 to destroy"
```

---

#### **Scenario 4: Modify Existing Resource**

```
┌──────────────────────────────────────────────────────────┐
│ BEFORE DEPLOYMENT                                        │
├──────────────────────────────────────────────────────────┤
│ Code:   retention_in_days = 90  ← Changed from 30        │
│ State:  retention_in_days = 30                           │
│ Azure:  retention_in_days = 30                           │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ UPDATE workspace (code changed)                          │
│ API: PATCH /workspaces/identity-lab-logs-v3             │
│ Body: { "properties": { "retentionInDays": 90 } }       │
├──────────────────────────────────────────────────────────┤
│ AFTER DEPLOYMENT                                         │
│ Code:   retention_in_days = 90                           │
│ State:  retention_in_days = 90 ← Updated                 │
│ Azure:  retention_in_days = 90 ← Updated                 │
└──────────────────────────────────────────────────────────┘

Duration: 3 minutes (in-place update, no recreation)
Plan output: "Plan: 0 to add, 1 to change, 0 to destroy"

Note: Terraform UPDATES existing resource, doesn't delete and recreate
```

---

#### **Scenario 5: Drift Detection (Manual Change in Azure)**

```
┌──────────────────────────────────────────────────────────┐
│ SOMEONE MANUALLY CHANGED AZURE PORTAL                    │
├──────────────────────────────────────────────────────────┤
│ Code:   retention_in_days = 30  ← What we want           │
│ State:  retention_in_days = 30  ← What Terraform thinks  │
│ Azure:  retention_in_days = 7   ← Someone changed it!    │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ DRIFT DETECTED! Azure doesn't match code/state          │
│ UPDATE Azure back to 30 (drift correction)              │
│ API: PATCH /workspaces/identity-lab-logs-v3             │
├──────────────────────────────────────────────────────────┤
│ AFTER DEPLOYMENT                                         │
│ Code:   retention_in_days = 30                           │
│ State:  retention_in_days = 30                           │
│ Azure:  retention_in_days = 30 ← Fixed!                  │
└──────────────────────────────────────────────────────────┘

Duration: 3 minutes
Plan output: "Plan: 0 to add, 1 to change, 0 to destroy"
Warning: "⚠️ Drift detected: retention_in_days changed outside Terraform"

This is why we have drift-detection.yml workflow that runs daily!
```

---

#### **Scenario 6: Protected Resource (prevent_destroy)**

```
┌──────────────────────────────────────────────────────────┐
│ DEVELOPER ACCIDENTALLY DELETES CODE                      │
├──────────────────────────────────────────────────────────┤
│ Code:   (workspace deleted from main.tf by mistake)      │
│ State:  Workspace exists                                 │
│ Azure:  Workspace exists                                 │
├──────────────────────────────────────────────────────────┤
│ TERRAFORM DECISION:                                      │
│ Code wants to DELETE workspace                           │
│ BUT: lifecycle { prevent_destroy = true }               │
│ ❌ ERROR: Cannot destroy protected resource              │
│ ❌ Workflow FAILS (this is GOOD!)                        │
├──────────────────────────────────────────────────────────┤
│ RESULT                                                    │
│ Deployment blocked ✅                                     │
│ Production safe ✅                                        │
│ Developer notified of mistake ✅                          │
└──────────────────────────────────────────────────────────┘

Error message:
"Error: Instance cannot be destroyed

  on main.tf line 34:
  34: resource "azurerm_log_analytics_workspace" "identity_logs" {

Resource has lifecycle.prevent_destroy set, but the plan calls for
this resource to be destroyed. To avoid this error, either disable
lifecycle.prevent_destroy or reduce the scope using -target flag."

This safety net prevents catastrophic accidents!
```

---

## 📝 Pull Request Workflow

### **When to Create a Pull Request**

```
Feature branch tested and working?
├── YES: Create PR to merge to main
└── NO: Keep working in feature branch

Signs your feature is ready for PR:
✅ All GitHub Actions workflows passed
✅ Deployed successfully to test environment
✅ Manually tested the new feature
✅ Documentation updated
✅ No errors in logs
✅ Code follows team standards
```

---

### **PR Creation Process**

**Step 1: Push your feature branch (Already done)**
```bash
$ git push origin feature/add-brute-force-detection
✅ Branch pushed to GitHub
```

**Step 2: Create Pull Request on GitHub.com**
```
1. Go to: https://github.com/Jessi1012/azure-identity-lab
2. GitHub shows: "feature/add-brute-force-detection had recent pushes"
3. Click: "Compare & pull request" button
4. Fill in PR details:
```

```markdown
Title: feat: Add brute force attack detection

## 📝 Description
Adds new Sentinel alert rule to detect brute force attacks by monitoring
failed login attempts. Alert triggers when a user has 10+ failed logins
within 1 hour.

## 🎯 Changes Made
- Created `kql-queries/brute-force-detection.kql` with detection logic
- Added `azurerm_sentinel_alert_rule_scheduled.brute_force` resource
- Configured High severity incident creation
- Updated documentation with new rule details

## ✅ Testing
- [x] Deployed to feature/test-deployment branch
- [x] Alert rule is active in Azure Sentinel
- [x] Tested with synthetic failed logins (triggered correctly)
- [x] Logic App notification working
- [x] No performance impact on queries

## 📊 Impact
- **Security:** Detects credential stuffing and password spraying attacks
- **Performance:** Query optimized, runs in <2 seconds
- **Cost:** +$0.05/month (negligible)
- **Risk:** Low (new rule, doesn't modify existing ones)

## 🔍 Checklist
- [x] Security scans passed (CodeQL, tfsec, Checkov)
- [x] Terraform plan reviewed
- [x] Documentation updated
- [x] Deployment successful
- [x] No errors in logs
- [x] Team notified

## 📸 Screenshots
![Alert Rule in Sentinel](screenshot-url)
![Teams Notification Example](notification-url)

## 🔗 Related Issues
Closes #42 (Add brute force detection)
```

**Step 3: PR Validation Runs Automatically**

```yaml
Workflow: .github/workflows/pr-validation.yml
Trigger: Pull request created/updated
```

```
[Runs in GitHub Actions - 8 minutes]

Step 1: Security Scans
├── CodeQL: ✅ No vulnerabilities
├── tfsec: ✅ No security issues
└── Checkov: ✅ Compliant

Step 2: Terraform Validation
├── terraform fmt -check: ✅ Code formatted properly
├── terraform validate: ✅ Syntax correct
└── terraform plan: ✅ Shows 1 resource to add

Step 3: Generate Plan Artifact
└── terraform plan -out=tfplan > plan.json
    ├── Saved as artifact (downloadable)
    └── Used for PR comment

Step 4: Post PR Comment (Automatic)
```

**Automated comment posted on PR:**
```markdown
## 📋 Terraform Plan Summary

**Resources:**
- ➕ Create: 1
  - `azurerm_sentinel_alert_rule_scheduled.brute_force`
- 🔄 Update: 0
- ❌ Delete: 0

**Status:** ⚠️ Changes detected (as expected for new feature)

**Security Scans:**
- ✅ CodeQL: No vulnerabilities found
- ✅ tfsec: 0 HIGH, 1 MEDIUM (Key Vault firewall - optional)
- ✅ Checkov: 95% compliance (passing)

**Details:**
```terraform
# azurerm_sentinel_alert_rule_scheduled.brute_force will be created
+ resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
    + name     = "Brute Force Attack Detection"
    + severity = "High"
    + enabled  = true
    ...
  }
```

**Review Required:** Yes (branch protection enabled)
**Approvals:** 0 / 1 required

---
🤖 Automated by GitHub Actions • View full plan in [Artifacts](link)
```

---

**Step 4: Code Review (Human Process)**

```
Reviewer (Senior Engineer or Team Lead):

1. Reviews code changes
   ├── Checks: Is logic correct?
   ├── Checks: Are there security issues?
   ├── Checks: Is code well-documented?
   └── Checks: Does it follow standards?

2. Reviews Terraform plan
   ├── Checks: Only expected resources changing?
   ├── Checks: No accidental deletions?
   └── Checks: Cost impact acceptable?

3. Reviews test results
   ├── All checks passed?
   ├── Alert rule working?
   └── No errors in logs?

4. Asks questions or requests changes
   Example comments:
   ├── "Can you add more context to this comment?"
   ├── "Have you considered edge case X?"
   ├── "Please update the README with this info"
   └── "LGTM! (Looks Good To Me) ✅"

5. Approves or requests changes
```

**Approval process:**
```
Reviewer clicks: "Review changes"
├── Option 1: Approve ✅
│   └── "Approve changes and allow merging"
├── Option 2: Request changes ❌
│   └── "Must address before merging"
└── Option 3: Comment 💬
    └── "Leave feedback without approval/rejection"
```

---

**Step 5: Merge to Main (After Approval)**

```
Merge options:
├── Merge commit (keeps all commits, full history)
├── Squash and merge (combines all commits into one) ← RECOMMENDED
└── Rebase and merge (linear history, no merge commits)
```

**Squash and merge (recommended):**
```bash
Before merge (feature branch):
├── abc1234: "feat: Add alert rule"
├── def5678: "fix: Typo in query"
├── ghi9012: "docs: Update README"
└── jkl3456: "test: Add validation"

After merge (main branch):
└── mno7890: "feat: Add brute force attack detection (#45)"
    └── Squashed all 4 commits into one clean commit
```

---

**Step 6: Automatic Deployment to Main**

```yaml
Workflow: .github/workflows/deploy.yml
Trigger: Push to main (from PR merge)
```

```
[Runs same deployment process]
├── Security scans
├── Terraform plan
├── Terraform apply
└── Verification

Difference:
- This is PRODUCTION deployment (main branch = prod)
- Higher scrutiny (already reviewed via PR)
- Audit trail shows: "Deployed from PR #45"
```

---

## 🎓 Summary: Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  LOCAL DEVELOPMENT (Your Laptop)                            │
├─────────────────────────────────────────────────────────────┤
│  1. git checkout -b feature/new-feature                     │
│  2. Edit code (main.tf, *.kql)                              │
│  3. git commit -m "feat: Description"                       │
│  4. git push origin feature/new-feature                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS (Automated - 15 min)                        │
├─────────────────────────────────────────────────────────────┤
│  5. Security scans (CodeQL, tfsec, Checkov)                 │
│  6. Terraform validate                                       │
│  7. Azure login (Service Principal)                         │
│  8. Terraform init (download providers, setup backend)      │
│  9. Terraform plan (what will change?)                      │
│  10. Terraform apply (only changed resources!)              │
│  11. Verify deployment                                       │
│  12. Update state file                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  AZURE (Infrastructure Live)                                │
├─────────────────────────────────────────────────────────────┤
│  13. Alert rules monitoring 24/7                            │
│  14. Incidents created on threats                           │
│  15. Logic App sends Teams alerts                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PULL REQUEST (Optional but Recommended)                    │
├─────────────────────────────────────────────────────────────┤
│  16. Create PR (feature → main)                             │
│  17. PR validation runs (terraform plan, security scans)    │
│  18. Team reviews code                                       │
│  19. Approve and merge                                       │
│  20. Deploy to production (main branch)                     │
└─────────────────────────────────────────────────────────────┘
```

---

## ❓ Frequently Asked Questions

### **Q: What if I push to feature branch multiple times?**
**A:** Each push triggers a new deployment. Terraform's idempotency means:
- If no code changed: Deployment completes in 2 minutes (just validates)
- If code changed: Only modified resources are updated
- No duplicates or conflicts

---

### **Q: Can I skip the feature branch and push to main?**
**A:** Technically yes, but **strongly discouraged**:
- No safety net if code has bugs
- No code review
- Harder to rollback
- Against best practices
- May violate branch protection rules (if enabled)

---

### **Q: How does Terraform know not to recreate resources?**
**A:** Three-way comparison:
1. Reads terraform.tfstate (what it thinks exists)
2. Queries Azure API (what actually exists)  
3. Compares with code (what should exist)
4. Only changes what's different

---

### **Q: What happens if two people push at the same time?**
**A:** State locking prevents conflicts:
- First push: Acquires lock, deploys
- Second push: Waits for lock (or fails after timeout)
- After first completes: Second push gets lock and deploys

---

### **Q: Why does the first deployment take 15 minutes but second takes 7 minutes?**
**A:** First deployment creates everything from scratch:
- All 15+ resources created
- Sentinel enablement (slow)
- Alert rules imported one by one

Second deployment (if only 1 change):
- Skips 14 existing resources (idempotency)
- Only creates 1 new resource
- 50% time savings!

---

*Last updated: November 11, 2025*  
*See also: COMPLETE-PROJECT-GUIDE.md for full project documentation*
