variable "kyverno_helm_version" {
  description = "The version of kyverno helm chart to deploy"
  type        = string
  default     = "3.3.4"
}

variable "vpa_enabled" {
  description = "Whether the VPA resources should be enabled"
  type        = bool
  default     = false
}

variable "pull_through_cache_enabled" {
  description = "Whether to use the ECR pull through cache for the deployed images"
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "Whether to add active monitoring to the deployed systems"
  type        = bool
  default     = false
}

variable "enhanced_ha_enabled" {
  description = "Whether to add extra high-availability scheduling constraints at the trade-off of increased cost"
  type        = bool
  default     = true
}

variable "panfactum_scheduler_enabled" {
  description = "Whether to use the Panfactum pod scheduler with enhanced bin-packing"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "The log verbosity (0-9) for the Kyverno pods"
  type        = number
  default     = 0

  validation {
    condition     = var.log_level >= 0 && var.log_level <= 9
    error_message = "log_level must be between 0-9"
  }
}

