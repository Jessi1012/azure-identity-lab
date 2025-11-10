#!/bin/bash
# cleanup-azure.sh - Delete orphaned Azure resources before Terraform apply

set -euo pipefail

echo "🧹 Cleaning up orphaned Azure resources..."

RG_NAME="${TF_VAR_resource_group_name:-Identity-Lab-RG}"
WORKSPACE_NAME="${TF_VAR_workspace_name:-identity-lab-logs-v2}"
SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID}"

# Get the current workspace ID
CURRENT_WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG_NAME" \
    --workspace-name "$WORKSPACE_NAME" \
    --query customerId -o tsv 2>/dev/null || echo "")

if [ -z "$CURRENT_WORKSPACE_ID" ]; then
    echo "✓ Workspace doesn't exist yet, nothing to clean"
    exit 0
fi

echo "Current workspace ID: $CURRENT_WORKSPACE_ID"

# Delete all existing Sentinel alert rules (they may reference old workspace IDs)
echo ""
echo "🚨 Deleting existing Sentinel alert rules..."
ALERT_RULES=$(az rest --method GET \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.OperationalInsights/workspaces/${WORKSPACE_NAME}/providers/Microsoft.SecurityInsights/alertRules?api-version=2023-02-01" \
    --query "value[].name" -o tsv 2>/dev/null || echo "")

if [ -n "$ALERT_RULES" ]; then
    for RULE_NAME in $ALERT_RULES; do
        echo "  🗑️  Deleting alert rule: $RULE_NAME"
        az rest --method DELETE \
            --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.OperationalInsights/workspaces/${WORKSPACE_NAME}/providers/Microsoft.SecurityInsights/alertRules/${RULE_NAME}?api-version=2023-02-01" \
            || echo "  ⚠️  Failed to delete $RULE_NAME (may not exist)"
    done
else
    echo "  ✓ No alert rules to delete"
fi

# Delete Key Vault secret if it exists (to allow fresh import)
echo ""
echo "🔑 Checking Key Vault secrets..."
EXISTING_KVS=$(az keyvault list --resource-group "$RG_NAME" --query "[?starts_with(name, 'kv-identity-')].name" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_KVS" ]; then
    for KV_NAME in $EXISTING_KVS; do
        echo "  Checking vault: $KV_NAME"
        if az keyvault secret show --vault-name "$KV_NAME" --name "teams-webhook-url" >/dev/null 2>&1; then
            echo "  🗑️  Deleting secret 'teams-webhook-url' to force recreation"
            az keyvault secret delete --vault-name "$KV_NAME" --name "teams-webhook-url" || true
        fi
    done
else
    echo "  ✓ No Key Vaults found"
fi

echo ""
echo "✅ Cleanup complete!"
