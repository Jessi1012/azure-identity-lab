#!/bin/bash
# sync-state.sh - Reconcile Terraform state with actual Azure resources

set -euo pipefail

echo "🔍 Checking Azure resources vs Terraform state..."

RG_NAME="${TF_VAR_resource_group_name:-Identity-Lab-RG}"
WORKSPACE_NAME="${TF_VAR_workspace_name:-identity-lab-logs-v2}"
SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID}"

# Function to check if resource exists in Azure
resource_exists() {
    local resource_id=$1
    az resource show --ids "$resource_id" &>/dev/null
    return $?
}

# Function to check if resource is in Terraform state
in_state() {
    local resource_address=$1
    terraform state show "$resource_address" &>/dev/null
    return $?
}

# Function to import resource into state
import_resource() {
    local tf_address=$1
    local azure_id=$2
    echo "  📥 Importing: $tf_address"
    terraform import "$tf_address" "$azure_id" || echo "  ⚠️  Import failed (resource may not exist)"
}

echo ""
echo "📋 Resources to check:"
echo "  - Resource Group"
echo "  - Log Analytics Workspace"
echo "  - Sentinel Onboarding"
echo "  - Key Vault"
echo "  - Logic App"
echo "  - Storage Accounts"
echo ""

# 1. Check Resource Group (data source - skip)
echo "✓ Resource Group (data source - no import needed)"
# If RG was previously managed, remove it from state to avoid deletion attempts
if in_state "azurerm_resource_group.identity_lab"; then
    echo "  🧹 Removing previously-managed Resource Group from state"
    terraform state rm azurerm_resource_group.identity_lab || true
fi

# 2. Check Log Analytics Workspace
WORKSPACE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.OperationalInsights/workspaces/${WORKSPACE_NAME}"
if resource_exists "$WORKSPACE_ID"; then
    if ! in_state "azurerm_log_analytics_workspace.identity_logs"; then
        import_resource "azurerm_log_analytics_workspace.identity_logs" "$WORKSPACE_ID"
    else
        echo "✓ Log Analytics Workspace already in state"
    fi
else
    echo "✓ Log Analytics Workspace doesn't exist (will be created)"
fi

# 3. Check Sentinel Onboarding
SENTINEL_ID="${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/onboardingStates/default"
if resource_exists "$SENTINEL_ID"; then
    if ! in_state "azurerm_sentinel_log_analytics_workspace_onboarding.sentinel"; then
        import_resource "azurerm_sentinel_log_analytics_workspace_onboarding.sentinel" "$SENTINEL_ID"
    else
        echo "✓ Sentinel Onboarding already in state"
    fi
else
    echo "✓ Sentinel Onboarding doesn't exist (will be created)"
fi

# 4. Check for existing Key Vaults (pattern match)
echo ""
echo "🔑 Checking for Key Vaults..."
EXISTING_KVS=$(az keyvault list --resource-group "$RG_NAME" --query "[?starts_with(name, 'kv-identity-')].name" -o tsv 2>/dev/null || echo "")
if [ -n "$EXISTING_KVS" ]; then
    for KV_NAME in $EXISTING_KVS; do
        echo "  ⚠️  Found existing Key Vault: $KV_NAME"
        KV_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME}"
        if ! in_state "azurerm_key_vault.identity_vault"; then
            # Extract suffix from name
            SUFFIX="${KV_NAME#kv-identity-}"
            # Check if random_string exists with this value
            if ! in_state "random_string.suffix"; then
                echo "  📥 Importing random_string.suffix with value: $SUFFIX"
                # Import random_string by creating a dummy import
                terraform import "random_string.suffix" "$SUFFIX" 2>/dev/null || echo "  ℹ️  Creating new random suffix"
            fi
            import_resource "azurerm_key_vault.identity_vault" "$KV_ID"
        fi

        # Import Teams webhook secret if present
        if az keyvault secret show --vault-name "$KV_NAME" --name "teams-webhook-url" >/dev/null 2>&1; then
            if ! in_state "azurerm_key_vault_secret.teams_webhook"; then
                SECRET_IMPORT_ID="https://${KV_NAME}.vault.azure.net/secrets/teams-webhook-url"
                import_resource "azurerm_key_vault_secret.teams_webhook" "$SECRET_IMPORT_ID"
            else
                echo "  ✓ Key Vault secret 'teams-webhook-url' already in state"
            fi
        else
            echo "  ✓ Key Vault secret 'teams-webhook-url' not found (will be created if var provided)"
        fi
    done
else
    echo "✓ No existing Key Vaults (will be created)"
fi

# 5. Check Logic App
LOGICAPP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Logic/workflows/identity-auto-remediate"
if resource_exists "$LOGICAPP_ID"; then
    if ! in_state "azurerm_logic_app_workflow.auto_remediate"; then
        import_resource "azurerm_logic_app_workflow.auto_remediate" "$LOGICAPP_ID"
    else
        echo "✓ Logic App already in state"
    fi
else
    echo "✓ Logic App doesn't exist (will be created)"
fi

# 6. Check Storage Accounts for Terraform state
echo ""
echo "💾 Checking for Terraform state storage accounts..."
EXISTING_STORAGE=$(az storage account list --resource-group "$RG_NAME" --query "[?starts_with(name, 'tfstate')].name" -o tsv 2>/dev/null || echo "")
if [ -n "$EXISTING_STORAGE" ]; then
    # Find the one that matches our backend config
    BACKEND_STORAGE=$(terraform state pull 2>/dev/null | jq -r '.backend.config.storage_account_name // empty')
    if [ -n "$BACKEND_STORAGE" ] && echo "$EXISTING_STORAGE" | grep -q "$BACKEND_STORAGE"; then
        echo "  ✓ Using backend storage: $BACKEND_STORAGE"
        STORAGE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.Storage/storageAccounts/${BACKEND_STORAGE}"
        if ! in_state "azurerm_storage_account.tfstate"; then
            # Extract suffix
            SUFFIX="${BACKEND_STORAGE#tfstate}"
            if ! in_state "random_string.suffix"; then
                echo "  📥 Setting random_string.suffix to: $SUFFIX"
            fi
            import_resource "azurerm_storage_account.tfstate" "$STORAGE_ID"
            
            # Import container
            CONTAINER_ID="https://${BACKEND_STORAGE}.blob.core.windows.net/tfstate"
            if ! in_state "azurerm_storage_container.tfstate"; then
                import_resource "azurerm_storage_container.tfstate" "$CONTAINER_ID"
            fi
        fi
    fi
else
    echo "✓ No existing storage accounts (will be created)"
fi

# 7. Check Sentinel Alert Rules
echo ""
echo "🚨 Checking Sentinel Alert Rules..."
RULES=("DormantAccountReactivation" "ImpossibleTravelDetection" "FailedLoginFloodDetection" "PrivilegeEscalationDetection")
TF_RULES=("dormant_account" "impossible_travel" "failed_login_flood" "privilege_escalation")

for i in "${!RULES[@]}"; do
    RULE_ID="${WORKSPACE_ID}/providers/Microsoft.SecurityInsights/alertRules/${RULES[$i]}"
    TF_ADDR="azurerm_sentinel_alert_rule_scheduled.${TF_RULES[$i]}"
    
    if resource_exists "$RULE_ID"; then
        if ! in_state "$TF_ADDR"; then
            import_resource "$TF_ADDR" "$RULE_ID"
        else
            echo "✓ Alert rule ${RULES[$i]} already in state"
        fi
    else
        echo "✓ Alert rule ${RULES[$i]} doesn't exist (will be created)"
    fi
done

echo ""
echo "✅ State synchronization complete!"
echo ""
echo "Run 'terraform plan' to see what changes are needed."
