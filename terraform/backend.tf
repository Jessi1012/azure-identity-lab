terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

## To migrate to a remote backend later, replace the above with:
##
## terraform {
##   backend "azurerm" {}
## }
##
## and run:
##   terraform init -migrate-state -backend-config=../terraform/backend.hcl
## (backend.hcl should contain resource_group_name, storage_account_name, container_name, key)
