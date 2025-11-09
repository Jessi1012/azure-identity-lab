terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}



 terraform {
   backend "azurerm" {
     resource_group_name  = "Identity-Lab-RG"
     storage_account_name = "yourstorageaccountname"
     container_name       = "tfstate"
     key                  = "terraform.tfstate"
   }
 }


