terraform {
  backend "azurerm" {
    resource_group_name  = "Identity-Lab-RG"
    storage_account_name = "tfstateb54w9t"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
