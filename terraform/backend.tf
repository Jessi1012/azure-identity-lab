# backend.tf
# 
# ⚠️ BOOTSTRAP REQUIRED:
# The backend storage must exist BEFORE running terraform.
# This is a chicken-egg problem: Terraform needs storage to store its state,
# but it can't create the storage if it needs the storage to track what it creates.
#
# SOLUTION: Use local backend initially, then migrate to remote.
#
# For now, we use LOCAL backend (state stored on your computer).
# After first successful apply, you can migrate to remote backend.

terraform {
  # LOCAL BACKEND (state stored in terraform/ directory)
  # No backend block = local state file

  # To migrate to remote backend later, uncomment below and run:
  # terraform init -migrate-state

  # backend "azurerm" {
  #   resource_group_name  = "Identity-Lab-RG"
  #   storage_account_name = "tfstateb54w9t"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}
