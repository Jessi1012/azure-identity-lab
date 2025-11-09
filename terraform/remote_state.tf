 resource "azurerm_storage_account" "tfstate" {
   name                     = "tfstate${random_string.suffix.result}"
   resource_group_name      = data.azurerm_resource_group.identity_lab.name
   location                 = data.azurerm_resource_group.identity_lab.location
   account_tier             = "Standard"
   account_replication_type = "LRS"
   min_tls_version          = "TLS1_2"  # Secure TLS version
   tags                     = var.tags
 }

 resource "azurerm_storage_container" "tfstate" {
   name                  = "tfstate"
   storage_account_name  = azurerm_storage_account.tfstate.name
   container_access_type = "private"
 }


