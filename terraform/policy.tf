# AZURE POLICY: (Removed invalid MFA lookup)
# There is no built-in Azure Policy that can enforce or audit Azure AD MFA status for administrative users.
# MFA enforcement is handled via Conditional Access, not Azure Policy. The previous data source failed because
# the display name "Require MFA for administrative users" does not exist.
# If you want to keep a placeholder, define a custom policy later or remove this section entirely.

# Placeholder example (disabled) showing how you might create a custom policy in future:
# resource "azurerm_policy_definition" "placeholder_mfa" {
#   name         = "placeholder-mfa-admins"
#   policy_type  = "Custom"
#   mode         = "All"
#   display_name = "(Placeholder) MFA Enforcement via Conditional Access"
#   description  = "Informational placeholder; real MFA enforcement must use Conditional Access policies."
#   policy_rule = jsonencode({
#     if = { field = "type", equals = "Microsoft.Resources/subscriptions" }
#     then = { effect = "audit" }
#   })
# }

# resource "azurerm_resource_group_policy_assignment" "mfa_enforcement" {
#   name                 = "placeholder-mfa-assignment"
#   resource_group_id    = azurerm_resource_group.identity_lab.id
#   policy_definition_id = azurerm_policy_definition.placeholder_mfa.id
# }

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
