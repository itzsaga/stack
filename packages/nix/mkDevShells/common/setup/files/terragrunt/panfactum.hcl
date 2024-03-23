#################################################################
## DO NOT EDIT - This file is automatically generated.
#################################################################

locals {
  global_file      = find_in_parent_folders("global.yaml", "DNE")
  global_raw_vars  = local.global_file != "DNE" ? yamldecode(file(local.global_file)) : null
  global_user_file = find_in_parent_folders("global.user.yaml", "DNE")
  global_user_vars = local.global_user_file != "DNE" ? yamldecode(file(local.global_user_file)) : null
  global_vars      = merge(local.global_raw_vars, local.global_user_vars)

  environment_file      = find_in_parent_folders("environment.yaml", "DNE")
  environment_raw_vars  = local.environment_file != "DNE" ? yamldecode(file(local.environment_file)) : null
  environment_user_file = find_in_parent_folders("environment.user.yaml", "DNE")
  environment_user_vars = local.environment_user_file != "DNE" ? yamldecode(file(local.environment_user_file)) : null
  environment_vars      = merge(local.environment_raw_vars, local.environment_user_vars)

  region_file      = find_in_parent_folders("region.yaml", "DNE")
  region_raw_vars  = local.region_file != "DNE" ? yamldecode(file(local.region_file)) : null
  region_user_file = find_in_parent_folders("region.user.yaml", "DNE")
  region_user_vars = local.region_user_file != "DNE" ? yamldecode(file(local.region_user_file)) : null
  region_vars      = merge(local.region_raw_vars, local.region_user_vars)

  module_file      = "${get_terragrunt_dir()}/module.yaml"
  module_raw_vars  = fileexists(local.module_file) ? yamldecode(file(local.module_file)) : null
  module_user_file = "${get_terragrunt_dir()}/module.user.yaml"
  module_user_vars = fileexists(local.module_user_file) ? yamldecode(file(local.module_user_file)) : null
  module_vars      = merge(local.module_raw_vars, local.module_user_vars)

  # Merge all of the vars with order of precedence
  vars = merge(
    local.global_vars,
    local.environment_vars,
    local.region_vars,
    local.module_vars
  )

  # Activated providers
  providers         = lookup(local.vars, "providers", [])
  enable_aws        = contains(local.providers, "aws")
  enable_kubernetes = contains(local.providers, "kubernetes")
  enable_vault      = contains(local.providers, "vault")
  enable_helm       = contains(local.providers, "helm")

  # Repo metadata
  repo_url       = get_env("PF_REPO_URL")
  repo_name      = get_env("PF_REPO_NAME")
  primary_branch = get_env("PF_REPO_PRIMARY_BRANCH")

  # Determine the module "version" (git ref to checkout)
  # Use the following priority ordering:
  # 1. The `version` key in any of the `yaml` files
  # 2. Fallback to the repo's primary branch
  version = lookup(local.vars, "version", local.primary_branch)

  # The version_tag needs to be a commit sha
  version_hash = run_cmd("--terragrunt-quiet", "get-version-hash", local.version)


  # Always use the local copy if trying to deploy to mainline branches to resolve performance and caching issues
  use_local_terraform = contains(["latest", "local", local.primary_branch], local.version)
  terraform_dir       = get_env("PF_TERRAFORM_DIR")
  terraform_path      = "${startswith(local.terraform_dir, "/") ? local.terraform_dir : "/${local.terraform_dir}"}//${lookup(local.vars, "module", basename(get_original_terragrunt_dir()))}"
  source              = local.use_local_terraform ? "${get_repo_root()}${local.terraform_path}" : "${local.repo_url}?ref=${local.version}${local.terraform_path}"

  # Folder of shared snippets to generate
  provider_folder = "providers"

  # local dev namespace
  local_dev_namespace = get_env("LOCAL_DEV_NAMESPACE", "")
  is_local            = local.vars.environment == "local"

  # get vault_token (only if the vault provider is enabled)
  vault_address = local.enable_vault ? (local.is_ci ? get_env("VAULT_ADDR") : lookup(local.vars, "vault_address", get_env("VAULT_ADDR"))) : ""
  vault_token   = run_cmd("--terragrunt-quiet", "get-vault-token", local.vault_address) # This will always run even if in a ternary, so no need to add ternary

  # check if in ci system
  is_ci = get_env("CI", "false") == "true"
}

################################################################
### The main terraform source
################################################################

terraform {
  source = local.source

  # Force Terraform to keep trying to acquire a lock for
  # up to 30 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = [
      local.is_local ? "-lock=false" : "-lock-timeout=30m"
    ]
  }
}

################################################################
### Provider Configurations
################################################################

generate "aws_provider" {
  path      = "aws.tf"
  if_exists = "overwrite_terragrunt"
  contents = local.enable_aws ? templatefile("${local.provider_folder}/aws.tftpl", {
    aws_region     = local.enable_aws ? local.vars.aws_region : ""
    aws_account_id = local.enable_aws ? local.vars.aws_account_id : ""
    aws_profile    = local.enable_aws ? local.vars.aws_profile : ""
  }) : ""
}

generate "aws_secondary_provider" {
  path      = "aws_secondary.tf"
  if_exists = "overwrite_terragrunt"
  # Note: If the aws provider is enabled, always enable the secondary as it removes a footgun at no extra cost
  contents = local.enable_aws ? templatefile("${local.provider_folder}/aws_secondary.tftpl", {
    aws_region     = local.enable_aws ? local.vars.aws_secondary_region : ""
    aws_account_id = local.enable_aws ? local.vars.aws_secondary_account_id : ""
    aws_profile    = local.enable_aws ? local.vars.aws_secondary_profile : ""
  }) : ""
}

generate "aws_global_provider" {
  path      = "aws_global.tf"
  if_exists = "overwrite_terragrunt"
  # Note: If the aws provider is enabled, always enable the global as it removes a footgun at no extra cost
  contents = local.enable_aws ? templatefile("${local.provider_folder}/aws_global.tftpl", {
    aws_account_id = local.enable_aws ? local.vars.aws_account_id : ""
    aws_profile    = local.enable_aws ? local.vars.aws_profile : ""
  }) : ""
}

generate "kubernetes_provider" {
  path      = "kubernetes.tf"
  if_exists = "overwrite_terragrunt"
  contents = local.enable_kubernetes ? templatefile("${local.provider_folder}/kubernetes.tftpl", {
    kube_api_server     = local.enable_kubernetes ? local.vars.kube_api_server : ""
    kube_config_context = local.enable_kubernetes ? local.vars.kube_config_context : ""
  }) : ""
}

generate "helm_provider" {
  path      = "helm.tf"
  if_exists = "overwrite_terragrunt"
  contents = local.enable_helm ? templatefile("${local.provider_folder}/helm.tftpl", {
    kube_api_server     = local.enable_helm ? local.vars.kube_api_server : ""
    kube_config_context = local.enable_helm ? local.vars.kube_config_context : ""
  }) : ""
}

generate "time_provider" {
  path      = "time.tf"
  if_exists = "overwrite_terragrunt"
  contents  = contains(local.vars.providers, "time") ? file("${local.provider_folder}/time.tf") : ""
}

generate "random_provider" {
  path      = "random.tf"
  if_exists = "overwrite_terragrunt"
  contents  = contains(local.vars.providers, "random") ? file("${local.provider_folder}/random.tf") : ""
}

generate "local_provider" {
  path      = "local.tf"
  if_exists = "overwrite_terragrunt"
  contents  = contains(local.vars.providers, "local") ? file("${local.provider_folder}/local.tf") : ""
}

generate "tls_provider" {
  path      = "tls.tf"
  if_exists = "overwrite_terragrunt"
  contents  = contains(local.vars.providers, "tls") ? file("${local.provider_folder}/tls.tf") : ""
}

generate "vault_provider" {
  path      = "vault.tf"
  if_exists = "overwrite_terragrunt"
  contents = local.enable_vault ? templatefile("${local.provider_folder}/vault.tftpl", {
    vault_address = local.vault_address
    vault_token   = local.vault_token
  }) : ""
}


################################################################
### Remote State Configuration
################################################################

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    profile        = local.environment_vars.tf_state_profile
    bucket         = local.environment_vars.tf_state_bucket
    key            = "${local.repo_name}/${local.is_local ? "${local.local_dev_namespace}/" : ""}${path_relative_to_include()}/terraform.tfstate"
    region         = local.environment_vars.tf_state_region
    encrypt        = true
    dynamodb_table = local.environment_vars.tf_state_lock_table
  }
}

################################################################
### Terragrunt Configuration
################################################################

terraform_version_constraint  = "~> 1.7"
terragrunt_version_constraint = "~> 0.53"

// If running in the CI system, enable retries on all of the errors
retryable_errors         = local.is_ci ? [".*"] : []
retry_max_attempts       = 3
retry_sleep_interval_sec = 30

################################################################
### Default Module Inputs
################################################################

inputs = {
  // common vars
  is_local    = local.is_local
  environment = local.vars.environment
  region      = local.vars.region
}