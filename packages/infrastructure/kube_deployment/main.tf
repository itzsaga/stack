terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    pf = {
      source  = "panfactum/pf"
      version = "0.0.7"
    }
  }
}

locals {
  all_ports = merge([for container_name, config in var.containers : config.ports]...)
  service_ports = { for name, config in local.all_ports : name => {
    pod_port     = config.port
    service_port = config.service_port
    protocol     = config.protocol
  } if config.expose_on_service }

  sla_target = data.pf_metadata.metadata.sla_target
}

// This is needed b/c this can never
// change without destroying the deployment first
resource "random_id" "deployment_id" {
  byte_length = 8
}

data "pf_kube_labels" "labels" {
  module = "kube_deployment"
}

data "pf_metadata" "metadata" {}

module "pod_template" {
  source = "../kube_pod"

  # Pod metadata
  namespace                  = var.namespace
  service_account            = kubernetes_service_account.service_account.metadata[0].name
  workload_name              = var.name
  match_labels               = { id = random_id.deployment_id.hex }
  dns_policy                 = var.dns_policy
  extra_pod_annotations      = var.extra_pod_annotations
  extra_pod_labels           = var.extra_pod_labels
  pod_version_labels_enabled = var.pod_version_labels_enabled
  extra_labels               = data.pf_kube_labels.labels.labels

  # Container configuration
  common_env                  = var.common_env
  common_secrets              = var.common_secrets
  common_env_from_secrets     = var.common_env_from_secrets
  common_env_from_config_maps = var.common_env_from_config_maps
  containers                  = var.containers
  pull_through_cache_enabled  = var.pull_through_cache_enabled

  # Mount configuration
  config_map_mounts = var.config_map_mounts
  secret_mounts     = var.secret_mounts
  tmp_directories   = var.tmp_directories
  mount_owner       = var.mount_owner

  # Scheduling params
  priority_class_name                  = var.priority_class_name
  burstable_nodes_enabled              = var.burstable_nodes_enabled
  spot_nodes_enabled                   = var.spot_nodes_enabled
  arm_nodes_enabled                    = var.arm_nodes_enabled
  controller_nodes_enabled             = var.controller_nodes_enabled
  instance_type_anti_affinity_required = var.instance_type_anti_affinity_required != null ? var.instance_type_anti_affinity_required : local.sla_target == 3
  az_anti_affinity_required            = var.az_anti_affinity_required
  host_anti_affinity_required          = var.host_anti_affinity_required
  extra_tolerations                    = var.extra_tolerations
  controller_nodes_required            = var.controller_nodes_required
  node_requirements                    = var.node_requirements
  node_preferences                     = var.node_preferences
  az_spread_preferred                  = var.az_spread_preferred != null ? var.az_spread_preferred : local.sla_target >= 2
  az_spread_required                   = var.az_spread_required
  panfactum_scheduler_enabled          = var.panfactum_scheduler_enabled
  termination_grace_period_seconds     = var.termination_grace_period_seconds
  restart_policy                       = var.restart_policy
  cilium_required                      = var.cilium_required
  linkerd_required                     = var.linkerd_required
  linkerd_enabled                      = var.linkerd_enabled
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = random_id.deployment_id.hex
    namespace = var.namespace
    labels    = module.pod_template.labels
  }
}

resource "kubectl_manifest" "deployment" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      namespace = var.namespace
      name      = var.name
      labels = merge(
        module.pod_template.labels,
        var.extra_labels
      )
      annotations = merge(
        {
          "reloader.stakater.com/auto" = "true"
        },
        var.extra_annotations
      )
    }
    spec = {
      replicas = var.replicas
      strategy = { for k, v in {
        type = var.update_type
        rollingUpdate = var.update_type == "RollingUpdate" ? {
          maxSurge       = var.max_surge
          maxUnavailable = var.max_unavailable
        } : null
      } : k => v if v != null }
      selector = {
        matchLabels = module.pod_template.match_labels
      }
      template = module.pod_template.pod_template
    }
  })
  server_side_apply = true
  force_conflicts   = true
  ignore_fields = var.ignore_replica_count ? [
    "spec.replicas"
  ] : []
  wait_for_rollout = var.wait_for_rollout
}

module "service" {
  count  = length(keys(local.service_ports)) > 0 ? 1 : 0
  source = "../kube_service"

  type                = var.service_type
  load_balancer_class = var.service_load_balancer_class
  public_domain_names = var.service_public_domain_names
  name                = var.service_name == null ? var.name : var.service_name
  namespace           = var.namespace
  ports               = local.service_ports
  service_ip          = var.service_ip
  match_labels        = module.pod_template.match_labels
  extra_labels = merge(
    module.pod_template.labels,
    var.extra_service_labels
  )
  extra_annotations = var.extra_service_annotations

  depends_on = [kubectl_manifest.deployment]
}

resource "kubectl_manifest" "vpa" {
  count = var.vpa_enabled ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels    = module.pod_template.labels
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = var.name
      }
      updatePolicy = {
        updateMode = "Auto"
        evictionRequirements = [{
          resource          = ["cpu", "memory"]
          changeRequirement = "TargetHigherThanRequests"
        }]
      }
      resourcePolicy = {
        containerPolicies = [for config in var.containers : {
          containerName = config.name
          minAllowed = {
            memory = "${config.minimum_memory}Mi"
            cpu    = "${config.minimum_cpu}m"
          }
          maxAllowed = { for k, v in {
            memory = config.maximum_memory != null ? "${config.maximum_memory}Mi" : null
            cpu    = config.maximum_cpu != null ? "${config.maximum_cpu}Mi" : null
          } : k => v if v != null }
        }]
      }
    }
  })
  depends_on = [kubectl_manifest.deployment]
}

resource "kubectl_manifest" "pdb" {
  yaml_body = yamlencode({
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"
    metadata = {
      name      = "${var.name}-pdb"
      namespace = var.namespace
      labels    = module.pod_template.labels
      labels = merge(
        module.pod_template.labels,
        {
          "panfactum.com/voluntary-disruption-window-id" = var.voluntary_disruption_window_enabled ? module.disruption_window_controller[0].disruption_window_id : "false"
        }
      )
      annotations = {
        "panfactum.com/voluntary-disruption-window-max-unavailable" = "1"
        "panfactum.com/voluntary-disruption-window-seconds"         = tostring(var.voluntary_disruption_window_seconds)
      }
    }
    spec = {
      selector = {
        matchLabels = module.pod_template.match_labels
      }
      maxUnavailable = var.voluntary_disruptions_enabled && !var.voluntary_disruption_window_enabled ? 1 : 0
    }
  })
  force_conflicts   = true
  server_side_apply = true
  depends_on        = [kubectl_manifest.deployment]
  ignore_fields = concat(
    [
      "metadata.annotations.panfactum.com/voluntary-disruption-window-start"
    ],
    var.voluntary_disruption_window_enabled ? [
      "spec.maxUnavailable"
    ] : []
  )
}

/***************************************
* Disruption Windows
***************************************/

module "disruption_window_controller" {
  count  = var.voluntary_disruption_window_enabled ? 1 : 0
  source = "../kube_disruption_window_controller"

  namespace                   = var.namespace
  vpa_enabled                 = var.vpa_enabled
  panfactum_scheduler_enabled = var.panfactum_scheduler_enabled
  pull_through_cache_enabled  = var.pull_through_cache_enabled

  cron_schedule = var.voluntary_disruption_window_cron_schedule
}
