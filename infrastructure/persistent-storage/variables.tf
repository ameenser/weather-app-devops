variable "aws_region" {
  description = "AWS Region containing the persistent EBS volumes."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for persistent storage and backup resource names."
  type        = string
  default     = "weather-app"
}

variable "existing_volume_ids" {
  description = <<-EOT
    Existing EBS volumes to adopt. n8n is deliberately excluded because its
    old volume was deleted and no snapshot exists; Terraform will create a new
    empty n8n volume.
  EOT
  type        = map(string)

  validation {
    condition = toset(keys(var.existing_volume_ids)) == toset([
      "alertmanager",
      "gitlab_data",
      "grafana",
      "jenkins_home",
      "prometheus",
      "vault",
    ])
    error_message = "existing_volume_ids must contain exactly: alertmanager, gitlab_data, grafana, jenkins_home, prometheus, and vault."
  }

  validation {
    condition = alltrue([
      for volume_id in values(var.existing_volume_ids) :
      can(regex("^vol-[0-9a-f]+$", volume_id))
    ])
    error_message = "Every existing_volume_ids value must be an EBS volume ID beginning with vol-."
  }
}

variable "enable_backups" {
  description = "Create an AWS Backup vault and daily backup plan for every persistent volume."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain daily EBS recovery points."
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "backup_retention_days must be at least 7."
  }
}

variable "enable_recycle_bin" {
  description = "Protect tagged persistent EBS volumes from immediate manual deletion."
  type        = bool
  default     = true
}

variable "recycle_bin_retention_days" {
  description = "Days deleted EBS volumes remain recoverable in Recycle Bin (AWS supports 1-7)."
  type        = number
  default     = 7

  validation {
    condition     = var.recycle_bin_retention_days >= 1 && var.recycle_bin_retention_days <= 7
    error_message = "recycle_bin_retention_days must be between 1 and 7."
  }
}
