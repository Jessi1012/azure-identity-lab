variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "workspace_name" {
  description = "Log Analytics workspace name "
  type        = string
  default     = "identity-lab-logs"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources for organization"
  type        = map(string)
  default = {
    Environment = "Lab"
    Project     = "Identity-Detection"
    ManagedBy   = "Terraform"
  }
}

variable "alert_email_recipients" {
  description = "Email addresses to receive alert notifications"
  type        = list(string)
  default     = ["chaitra.shashikala@gmail.com"]
}

variable "resource_group_name" {
  description = "The name of the Azure resource group"
  type        = string
  default     = "identity-lab-RG"
}