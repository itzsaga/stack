variable "name" {
  description = "The name of the WorkflowTemplate"
  type        = string
}

variable "namespace" {
  description = "The namespace to deploy the WorkflowTemplate into"
  type        = string
}

variable "pull_through_cache_enabled" {
  description = "Whether to use the ECR pull through cache for the deployed images"
  type        = bool
  default     = true
}

variable "code_repo" {
  description = "The URL of the git repo containing the Dockerfile to build"
  type        = string
}

variable "code_default_git_ref" {
  description = "The default git ref to checkout and build if none is provided to the WorkflowTemplate when executing the Workflow"
  type        = string
  default     = "main"
}

variable "build_context" {
  description = "Relative path from the root of the repository to the build context to submit to BuildKit"
  type        = string
  default     = "."
}

variable "dockerfile_path" {
  description = "Relative path from the root of the repository to the Dockerfile / Containerfile to submit to Buildkit"
  type        = string
  default     = "./Dockerfile"
}

variable "build_timeout" {
  description = "The number of seconds after which the build will be timed out"
  type        = number
  default     = 60 * 60
}

variable "image_repo" {
  description = "The name of the AWS ECR repository where generated images will be pushed"
  type        = string
}

variable "push_image_enabled" {
  description = "True iff images should be pushed to ECR in addition to being built"
  type        = bool
  default     = true
}

variable "secrets" {
  description = "A mapping of build-time secret ids to their respective values"
  type        = map(string)
  default     = {}
}

variable "args" {
  description = "A mapping of build-time arguments to their respective values"
  type        = map(string)
  default     = {}
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster that contains the service account."
  type        = string
}
