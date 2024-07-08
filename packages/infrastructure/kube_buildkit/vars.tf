variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "ip_allow_list" {
  description = "A list of IPs that can use the service account token to authenticate with AWS API"
  type        = list(string)
  default     = []
}

variable "min_replicas" {
  description = "The minimum number of replicas of buildkit to use"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "The maximum number of replicas of buildkit to use"
  type        = number
  default     = 10
}

variable "initial_storage_gb" {
  description = "The initial number of GB to use for the local image temp storage"
  type        = number
  default     = 25
}

variable "max_storage_gb" {
  description = "The maximum number of GB to use for the local image temp storage"
  type        = number
  default     = 250
}

variable "cpu_millicores" {
  description = "The number of cpus millicores to request for the buildkit pod"
  type        = number
  default     = 2000
}

variable "memory_mb" {
  description = "The amount of memory in MB to request for the buildkit pod"
  type        = number
  default     = 8000
}

variable "pull_through_cache_enabled" {
  description = "Whether to use the ECR pull through cache for the deployed images"
  type        = bool
  default     = false
}

variable "scale_down_delay_seconds" {
  description = "How long since the last build was initiated that BuildKit will be automatically scaled to zero"
  type        = number
  default     = 60 * 30
}

variable "panfactum_scheduler_enabled" {
  description = "Whether to use the Panfactum pod scheduler with enhanced bin-packing"
  type        = bool
  default     = false
}

variable "panfactum_image_version" {
  description = "The version of the Panfactum image to use for maintenance tasks"
  type        = string
  default     = "95508e2e860c95cee40e61245c8f588b6b73a39b"
}

variable "buildkit_image_version" {
  description = "The version of BuildKit to use"
  type        = string
  default     = "v0.14.1-rootless"
}

variable "vpa_enabled" {
  description = "Whether the VPA resources should be enabled. Does not apply to the actual BuildKit containers."
  type        = bool
  default     = false
}

variable "cache_clear_cron" {
  description = "A cron expression for how often the BuildKit cache should be cleared."
  type        = string
  default     = "0 0 * * 0" # Sunday at midnight
}

