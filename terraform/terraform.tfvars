resource_group_name = "Identity-Lab-RG"
location            = "eastus"
workspace_name      = "identity-lab-logs"
log_retention_days  = 30

tags = {
  Environment = "Lab"
  Project     = "Identity-Detection"
  Owner       = "Chait"
  ManagedBy   = "Terraform"
}

