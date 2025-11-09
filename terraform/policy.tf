# AZURE POLICY: REQUIRE MFA FOR ADMINS

data "azurerm_policy_definition" "require_mfa" {
  display_name = "Require MFA for administrative users"
}

resource "azurerm_resource_group_policy_assignment" "mfa_enforcement" {
  name                 = "enforce-mfa-for-admins"
  display_name         = "Enforce MFA for Administrative Users"
  resource_group_id    = azurerm_resource_group.identity_lab.id
  policy_definition_id = data.azurerm_policy_definition.require_mfa.id
  description          = "Ensures all admin users must have MFA enabled"
}

# CUSTOM POLICY: AUDIT KEY VAULT ACCESS

resource "azurerm_policy_definition" "audit_keyvault_access" {
  name         = "audit-keyvault-access"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit Key Vault Access Without Private Endpoint"
  description  = "Audits Key Vaults that don't use private endpoints"
  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.KeyVault/vaults" },
        { field = "Microsoft.KeyVault/vaults/privateEndpointConnections", exists = false }
      ]
    }
    then = {
      effect = "audit"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "keyvault_audit" {
  name                 = "audit-keyvault-private-endpoint"
  resource_group_id    = azurerm_resource_group.identity_lab.id
  policy_definition_id = azurerm_policy_definition.audit_keyvault_access.id
}
