terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    kubectl = {
      source  = "alekc/kubectl"
    }
    random = {
      source  = "hashicorp/random"
    }
    pf = {
      source = "panfactum/pf"
    }
  }
}

locals {
  name      = "website"
  namespace = module.namespace.namespace

  port              = 3000
  healthcheck_route = "/"
}

module "constants" {
  source = "${var.pf_module_source}kube_constants${var.pf_module_ref}"
}

module "namespace" {
  source = "${var.pf_module_source}kube_namespace${var.pf_module_ref}"

  namespace = local.name
}

/***********************************************
* Website Deployment
************************************************/

module "website_deployment" {
  source = "${var.pf_module_source}kube_deployment${var.pf_module_ref}"
  namespace = module.namespace.namespace
  name      = local.name

  replicas                             = 2

  common_env = {
    NODE_ENV = "production"
    PORT     = local.port
    HOSTNAME = "0.0.0.0"
  }

  containers = [
    {
      name    = "website"
      image_registry   = "891377197483.dkr.ecr.us-east-2.amazonaws.com"
      image_repository = "website"
      image_tag = var.website_image_version
      command = [
        "node",
        "server.js"
      ]
      liveness_probe_type  = "HTTP"
      liveness_probe_port  = local.port
      liveness_probe_route = local.healthcheck_route

      ports = {
        http ={
          port = local.port
        }
      }
    }
  ]

  vpa_enabled = var.vpa_enabled
  controller_nodes_enabled = true
}

module "ingress" {
  source = "${var.pf_module_source}kube_ingress${var.pf_module_ref}"

  name      = local.name
  namespace = local.namespace

  domains      = [var.website_domain, "www.${var.website_domain}"]
  ingress_configs = [{
    service      = local.name
    service_port = local.port

    cdn = {
      default_cache_behavior = {
        caching_enabled = false
      }
      path_match_behavior = {
        "_next/static/*" = {
          caching_enabled = true
          cookies_in_cache_key = []
        }
      }
    }
  }]

  cdn_mode_enabled = true
  cors_enabled                   = true
  cross_origin_embedder_policy   = "credentialless"
  csp_enabled                    = true
  cross_origin_isolation_enabled = true
  rate_limiting_enabled          = true
  permissions_policy_enabled     = true

  depends_on = [module.website_deployment]
}

module "cdn" {
  source = "${var.pf_module_source}kube_aws_cdn${var.pf_module_ref}"
  providers = {
    aws.global = aws.global
  }

  name           = "website"
  origin_shield_enabled = true
  origin_configs = module.ingress.cdn_origin_configs

  redirect_rules = [{
    source = "https?://www.panfactum.com(/.*)"
    target = "https://panfactum.com$1"
    permanent = true
  }]
}

module "website" {
  source = "${var.pf_module_source}aws_s3_public_website${var.pf_module_ref}"
  providers = {
    aws.global = aws.global
  }
  bucket_name = "pf-website-astro"
  description = "Hosts the new Astro Panfactum website"
  domain      = "website2.panfactum.com"

  path_match_behaviors = {
    "_astro*" = {

    }

  }
}

