# variables.tf
# This file defines all the configurable settings for your project.

# =============================
# Basic Settings
# =============================

variable "resource_group_name" {
  description = "The name of the Azure Resource Group where all resources will be created."
  type        = string
  default     = "Identity-Lab-RG"
  # You can override this value in terraform.tfvars if needed.
}

variable "location" {
  description = "Azure region (data center) where resources will be deployed."
  type        = string
  default     = "eastus"
  # Common options include eastus, westus, uksouth, centralindia, etc.
}

variable "workspace_name" {
  description = "Name of the Log Analytics Workspace. This name must be globally unique."
  type        = string
  default     = "identity-lab-logs-v3" # Fresh workspace to avoid GUID caching issues
  # If the name is already taken, change it to something like 'identity-lab-logs-yourname-2025'
}

variable "log_retention_days" {
  description = "Number of days to keep logs in Log Analytics. Typical values: 7, 30, 90, 180, 365."
  type        = number
  default     = 30
}

variable "backend_suffix" {
  description = "Suffix for storage account name (must be unique, lowercase, no special chars). Example: b54w9t"
  type        = string
  default     = "b54w9t"
  # This should match your existing storage account if you have one
  # Or generate new: https://www.random.org/strings/?num=1&len=6&digits=on&loweralpha=on&unique=on&format=plain
}

variable "create_workspace" {
  description = "Set to true for first deployment to create workspace. Set to false after initial deployment to use existing workspace."
  type        = bool
  default     = false # Default to false to prevent recreation
}

variable "tags" {
  description = "A set of tags (key-value pairs) to label all Azure resources, useful for organization and billing."
  type        = map(string)
  default = {
    Environment = "Lab"
    Project     = "Identity-Detection"
    ManagedBy   = "Terraform"
    Owner       = "Your-Name" # Replace with your actual name
  }
}

# =============================
# Microsoft Teams Webhook URL
# =============================

variable "teams_webhook_url" {
  description = "The Microsoft Teams incoming webhook URL to send alert notifications."
  type        = string
  sensitive   = true
  # This is a secret value and will not be shown in logs or outputs.
  # You will get this URL from your Microsoft Teams channel.
  default = "" # Provide via tfvars or environment TF_VAR_teams_webhook_url
}

# =============================
# Optional Service Principal Credentials for GitHub CI/CD
# =============================

variable "service_principal_client_id" {
  description = "Azure Service Principal Client ID - used for GitHub Actions authentication."
  type        = string
  sensitive   = true
  default     = "" # Leave empty if deploying manually
}

variable "service_principal_client_secret" {
  description = "Azure Service Principal Client Secret - used for GitHub Actions authentication."
  type        = string
  sensitive   = true
  default     = "" # Leave empty if deploying manually
}

# Note:
# The service principal client ID and secret are only needed if you are using GitHub Actions for CI/CD automation.
# If deploying manually, you can ignore these two variables.
