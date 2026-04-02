terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudpilotai = {
      source  = "cloudpilot-ai/cloudpilotai"
      version = "~> 0.1"
    }
  }
}

provider "cloudpilotai" {
  api_endpoint = var.cloudpilot_api_endpoint
  api_key      = var.cloudpilot_api_key
}

module "cloudpilotai_eks" {
  source = "../../"

  ################################################################################
  # EKS Cluster - Required
  ################################################################################

  cluster_name        = var.cluster_name
  region              = var.region
  restore_node_number = var.restore_node_number

  ################################################################################
  # EKS Cluster - Authentication & Access
  # Uncomment if you need to use a specific AWS profile, kubeconfig, or custom
  # IAM node role.
  ################################################################################

  # aws_profile      = "my-aws-profile"
  # kubeconfig       = file("~/.kube/config")
  # custom_node_role = "my-custom-node-role"

  ################################################################################
  # Node Autoscaler - Behavior
  ################################################################################

  only_install_agent = var.only_install_agent
  enable_rebalance   = var.enable_rebalance

  # disable_workload_uploading         = false
  # enable_upgrade_agent               = false
  # enable_upgrade_rebalance_component = false
  # enable_upload_config               = true
  # enable_diversity_instance_type     = false

  ################################################################################
  # Node Autoscaler - Destroy / Restore
  ################################################################################

  # skip_restore = false

  ################################################################################
  # Node Autoscaler - NodeClasses
  ################################################################################

  nodeclasses = [
    {
      name                 = "cloudpilot"
      system_disk_size_gib = 30
      instance_tags        = { "cloudpilot.ai/managed" = "true" }
    }
  ]

  ################################################################################
  # Node Autoscaler - NodePools
  ################################################################################

  nodepools = [
    {
      name              = "cloudpilot-general"
      nodeclass         = "cloudpilot"
      enable            = true
      capacity_type     = ["spot", "on-demand"]
      instance_arch     = ["amd64"]
      instance_cpu_max  = 17
      instance_memory_max = 32769
      node_disruption_limit = "2"
      node_disruption_delay = "60m"
    }
  ]

  ################################################################################
  # Node Autoscaler - Workloads
  ################################################################################

  workloads = [
    {
      name          = "my-app"
      type          = "deployment"
      namespace     = "default"
      spot_friendly = true
      rebalance_able = true
    }
  ]

  ################################################################################
  # Workload Autoscaler - General
  ################################################################################

  enable_workload_autoscaler = true
  wa_storage_class           = var.wa_storage_class
  wa_enable_node_agent       = true
  # wa_enable_upgrade        = false

  ################################################################################
  # Workload Autoscaler - Recommendation Policies
  ################################################################################

  recommendation_policies = [
    {
      name                  = "balanced"
      strategy_type         = "percentile"
      percentile_cpu        = 95
      percentile_memory     = 99
      history_window_cpu    = "24h"
      history_window_memory = "48h"
      evaluation_period     = "1m"
      buffer_cpu            = "10%"
      buffer_memory         = "20%"
      request_min_cpu       = "25%"
      request_min_memory    = "30%"
    },
    {
      name                  = "cost-savings"
      strategy_type         = "percentile"
      percentile_cpu        = 90
      percentile_memory     = 95
      history_window_cpu    = "12h"
      history_window_memory = "24h"
      evaluation_period     = "1m"
      request_min_cpu       = "30m"
      request_min_memory    = "30Mi"
    }
  ]

  ################################################################################
  # Workload Autoscaler - Autoscaling Policies
  ################################################################################

  autoscaling_policies = [
    {
      name                       = "default-ap"
      enable                     = true
      recommendation_policy_name = "balanced"
      priority                   = 10
      update_resources           = ["cpu", "memory"]
      drift_threshold_cpu        = "5%"
      drift_threshold_memory     = "5%"

      target_refs = [
        {
          api_version = "apps/v1"
          kind        = "Deployment"
        },
        {
          api_version = "apps/v1"
          kind        = "StatefulSet"
        }
      ]

      update_schedules = [
        {
          name = "default"
          mode = "inplace"
        }
      ]

      limit_policies = [
        {
          resource     = "cpu"
          remove_limit = true
        },
        {
          resource      = "memory"
          auto_headroom = "2"
        }
      ]
    },
    {
      name                       = "readonly"
      enable                     = true
      recommendation_policy_name = "cost-savings"
      priority                   = 0

      target_refs = [
        {
          api_version = "apps/v1"
          kind        = "Deployment"
        }
      ]

      update_schedules = [
        {
          name = "default"
          mode = "off"
        }
      ]
    }
  ]

  ################################################################################
  # Workload Autoscaler - Proactive Optimization
  ################################################################################

  enable_proactive = [
    {
      namespaces = ["default", "my-namespace"]
    }
  ]

  disable_proactive = [
    {
      namespaces = ["kube-system"]
    }
  ]
}
