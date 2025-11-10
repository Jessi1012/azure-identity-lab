# State Synchronization Solution

## Problem
When deploying via CI/CD, Terraform state can become out of sync with actual Azure resources, causing "already exists" errors on every run.

## Solution
The `scripts/sync-state.sh` script automatically reconciles Terraform state with existing Azure resources before each deployment.

## How It Works

### Workflow Steps (Updated)
1. **Terraform Init** - Initialize backend and providers
2. **Sync State** ✨ NEW - Check Azure for existing resources and import them into state
3. **Terraform Plan** - Generate execution plan (only shows actual changes)
4. **Security Scan** - Run Trivy for security issues
5. **Terraform Apply** - Apply only the planned changes

### What Gets Synchronized

The sync script checks and imports:
- ✅ Log Analytics Workspace
- ✅ Sentinel Onboarding
- ✅ Key Vaults (with suffix matching)
- ✅ Logic App Workflow
- ✅ Storage Accounts (tfstate)
- ✅ Sentinel Alert Rules (all 4)
- ✅ Storage Containers

### Benefits

**Before (without sync):**
```
Run 1: Creates resources ✅
Run 2: "Already exists" errors ❌
Run 3: "Already exists" errors ❌
```

**After (with sync):**
```
Run 1: Creates resources ✅
Run 2: Syncs state, applies changes only ✅
Run 3: Syncs state, applies changes only ✅
```

### How to Use

#### Automatically (GitHub Actions)
The workflow now runs sync-state.sh automatically before terraform apply.

#### Manually (Local Development)
```bash
cd terraform

# 1. Initialize Terraform
terraform init

# 2. Run state sync
bash ../scripts/sync-state.sh

# 3. Check what will change
terraform plan

# 4. Apply changes
terraform apply
```

### What This Prevents

❌ **Prevents:**
- "Already exists" errors
- Duplicate resource creation
- State drift issues
- Manual resource cleanup

✅ **Enables:**
- Idempotent deployments (safe to run multiple times)
- Partial failure recovery
- State reconstruction after corruption
- Smooth CI/CD operations

### Example Output

```
🔍 Checking Azure resources vs Terraform state...

📋 Resources to check:
  - Resource Group
  - Log Analytics Workspace
  - Sentinel Onboarding
  - Key Vault
  - Logic App
  - Storage Accounts

✓ Resource Group (data source - no import needed)
  📥 Importing: azurerm_log_analytics_workspace.identity_logs
✓ Sentinel Onboarding already in state
  ⚠️  Found existing Key Vault: kv-identity-abc123
  📥 Importing: azurerm_key_vault.identity_vault
✓ Logic App already in state

✅ State synchronization complete!
```

### Troubleshooting

**If sync fails:**
- The workflow continues (non-blocking)
- Check the sync step logs for details
- Resources may still get imported during terraform apply
- You can manually run: `bash scripts/sync-state.sh`

**If you want to start fresh:**
```bash
# Delete all resources
az group delete --name Identity-Lab-RG --yes --no-wait

# Clear local state (if needed)
terraform state rm <resource_address>

# Re-run deployment
git push
```

### Technical Details

**State Import Strategy:**
1. Query Azure API for resource existence
2. Check Terraform state for resource presence
3. If exists in Azure but not in state → Import
4. If exists in both → Skip
5. If doesn't exist in Azure → Will be created

**Random Suffix Handling:**
The script detects existing resource suffixes (e.g., `kv-identity-abc123` → suffix: `abc123`) and ensures the `random_string.suffix` resource matches, preventing name conflicts.

### Files Modified
- `.github/workflows/deploy.yml` - Added state sync step
- `scripts/sync-state.sh` - State reconciliation script (new)

### Next Steps
This deployment should now work smoothly without "already exists" errors! 🎉
