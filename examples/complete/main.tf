terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudpilotai = {
      source  = "cloudpilot-ai/cloudpilotai"
      version = ">= 0.7.0"
    }
  }
}

provider "cloudpilotai" {
  api_endpoint = var.cloudpilot_api_endpoint
  api_key      = var.cloudpilot_api_key
}

module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

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
  # kubeconfig       = pathexpand("~/.kube/config")
  # custom_node_role = "my-custom-node-role"

  ################################################################################
  # Node Autoscaler - Behavior
  ################################################################################

  only_install_agent = var.only_install_agent
  enable_rebalance   = var.enable_rebalance

  # disable_workload_uploading         = false
  # enable_upgrade                     = false

  cluster_setting = {
    disruption_cooldown          = "10m"
    aws_spot_allocation_strategy = "price-capacity-optimized"
    enable_node_repair           = true
    enable_disk_monitor          = true
    discount                     = 0.15
    pre_run_command              = <<-EOT
      set -euo pipefail

      echo "pre run start"
      aws sts get-caller-identity
      kubectl get nodes
    EOT
    post_run_command             = <<-EOT
      set -euo pipefail

      echo "post run start"
      kubectl get pods -A
    EOT
  }

  ################################################################################
  # Node Autoscaler - Destroy / Restore
  ################################################################################

  # skip_restore = false

  ################################################################################
  # Node Autoscaler - NodeClasses
  ################################################################################

  nodeclasses = [
    {
      name          = "cloudpilot"
      ami_alias     = "al2023@latest"
      user_data     = "#!/bin/bash\necho cloudpilot"
      instance_tags = { "cloudpilot.ai/managed" = "true" }
      memory_extension = {
        enabled        = true
        reclaim_policy = "Conservative"
        cold_memory = {
          sizing_mode          = "Auto"
          memory_ratio_percent = 25
          min_gib              = 1
          max_gib              = 16
          max_disk_percent     = 25
        }
        cached_memory = { max_memory_percent = 10 }
      }
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          root_volume = true
          ebs = {
            volume_size        = "80Gi"
            volume_type        = "gp3"
            encrypted          = true
            volume_size_policy = { per_vcpu_gib = 2, max_size_gib = 512 }
          }
        }
      ]
    }
  ]

  ################################################################################
  # Node Autoscaler - NodePools
  ################################################################################

  nodepools = [
    {
      name                  = "cloudpilot-general"
      nodeclass             = "cloudpilot"
      enable                = true
      capacity_type         = ["spot", "on-demand"]
      instance_arch         = ["amd64"]
      instance_cpu_max      = 17
      instance_memory_max   = 32769
      node_disruption_limit = "2"
      node_disruption_delay = "60m"
      disruption_cooldown   = "5m"
      job_nodepool_optimization = {
        min_active_nodes   = 1
        provisioning_delay = "30s"
      }
      nri_swap_policy = {
        enabled                 = true
        memory_limit_multiplier = 2
      }
      labels = {
        team = "platform"
      }
      taints = [
        {
          key    = "dedicated"
          value  = "wa"
          effect = "NoSchedule"
        }
      ]
    }
  ]

  ################################################################################
  # Node Autoscaler - Workloads
  ################################################################################

  workloads = [
    {
      name           = "my-app"
      type           = "deployment"
      namespace      = "default"
      spot_friendly  = true
      rebalance_able = true
    }
  ]

  ################################################################################
  # Workload Autoscaler - General
  ################################################################################

  enable_workload_autoscaler = true
  wa_storage_class           = var.wa_storage_class
  wa_enable_node_agent       = true

  wa_enable_new_workloads_proactive_update         = false
  wa_limiter_quota_per_window                      = 5
  wa_limiter_burst                                 = 10
  wa_limiter_window_seconds                        = 30
  wa_enable_preempted_pod_gc                       = true
  wa_preempted_pod_gc_ttl                          = "30m"
  wa_enable_initial_optimization_data_window_check = true

  ################################################################################
  # Workload Autoscaler - Recommendation Policies
  ################################################################################

  recommendation_policies = [
    {
      name                             = "balanced"
      strategy_type                    = "percentile"
      percentile_cpu                   = 95
      percentile_memory                = 99
      history_window_cpu               = "24h"
      history_window_memory            = "48h"
      evaluation_period                = "1m"
      buffer_cpu                       = "10%"
      buffer_memory                    = "20%"
      request_min_cpu                  = "25%"
      request_min_memory               = "30%"
      jvm_heap_buffer                  = "300Mi"
      jvm_min_heap_xms                 = "512Mi"
      jvm_max_heap_xms                 = "2Gi"
      jvm_min_heap_xmx                 = "1Gi"
      jvm_max_heap_xmx                 = "4Gi"
      jvm_min_heap_xms_ratio_of_memory = "0.25"
      jvm_recent_non_heap_window       = "2h"
      jvm_heap_used_percentile         = 20
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
      name                                     = "default-ap"
      enable                                   = true
      recommendation_policy_name               = "balanced"
      priority                                 = 10
      update_resources                         = ["cpu", "memory"]
      drift_threshold_cpu                      = "5%"
      drift_threshold_memory                   = "5%"
      disable_runtime_optimization             = false
      startup_boost_enabled                    = true
      startup_boost_recommendation_policy_name = "cost-savings"
      startup_boost_update_resources           = ["memory"]
      in_place_fallback_reason_policies = {
        JVMHeapDrift = "hold"
      }

      target_refs = [
        {
          api_version = "apps/v1"
          kind        = "Deployment"
          label_selector = {
            match_labels = {
              app = "my-app"
            }
            match_expressions = [
              {
                key      = "tier"
                operator = "In"
                values   = ["backend"]
              }
            ]
          }
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
      namespaces            = ["default", "my-namespace"]
      startup_boost_enabled = true
    }
  ]

  disable_proactive = [
    {
      namespaces = ["kube-system"]
    }
  ]
}
