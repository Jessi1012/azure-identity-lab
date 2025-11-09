terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}



 terraform {
   backend "azurerm" {}
 }
