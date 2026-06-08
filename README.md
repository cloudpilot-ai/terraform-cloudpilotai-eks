# CloudPilot AI EKS Terraform Module

Terraform module for deploying [CloudPilot AI](https://cloudpilot.ai/) Node Autoscaler and Workload Autoscaler on Amazon EKS clusters. This module provides a simplified, opinionated interface that wraps the [`cloudpilotai`](https://registry.terraform.io/providers/cloudpilot-ai/cloudpilotai/latest/docs) Terraform provider resources.

## Registry Support

This module supports both Terraform and OpenTofu.

- Terraform Registry: https://registry.terraform.io/modules/cloudpilot-ai/eks/cloudpilotai/latest
- OpenTofu Registry: https://search.opentofu.org/module/cloudpilot-ai/eks/cloudpilotai/latest
- GitHub Repository: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks

## Features

- Install and configure the CloudPilot AI Node Autoscaler on EKS clusters
- Optionally deploy the Workload Autoscaler with recommendation and autoscaling policies
- Manage NodeClasses and NodePools for Karpenter-based node provisioning
- Manage cluster-level CloudPilot AI settings
- Configure workload-level optimization (spot-friendly, rebalance, min non-spot replicas)
- Enable proactive optimization for automatic workload right-sizing

The module covers the AWS/EKS fields that the CloudPilot AI frontend explicitly edits today. For Karpenter CRD fields outside this typed surface, use `origin_nodeclass_json` or `origin_nodepool_json` on the corresponding object.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with EKS permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster operations
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)

## Usage

### Terraform-only CI/CD assume role

```hcl
module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

  cluster_name = "my-eks-cluster"
  region       = "us-west-2"

  aws_assume_role = {
    role_arn     = "arn:aws:iam::123456789012:role/sts-admin"
    session_name = "terraform-user"
  }

  enable_workload_autoscaler = false
}
```

### Minimal -- Install agent only

```hcl
provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}

module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

  cluster_name       = "my-eks-cluster"
  region             = "us-west-2"
  only_install_agent = true

  enable_workload_autoscaler = false
}
```

### Node Autoscaler with rebalance and custom node pools

```hcl
provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}

module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

  cluster_name        = "my-eks-cluster"
  region              = "us-west-2"
  enable_rebalance    = true
  restore_node_number = 3

  cluster_setting = {
    enable_node_repair  = true
    enable_disk_monitor = true
    discount            = 0.15
    pre_run_command = <<-EOT
      set -euo pipefail

      echo "pre run start"
      aws sts get-caller-identity
      kubectl get nodes
    EOT
    post_run_command = <<-EOT
      set -euo pipefail

      echo "post run start"
      kubectl get pods -A
    EOT
  }

  nodeclasses = [
    {
      name          = "cloudpilot"
      ami_alias     = "al2023@latest"
      user_data     = "#!/bin/bash\necho cloudpilot"
      instance_tags = { "cloudpilot.ai/managed" = "true" }
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          root_volume = true
          ebs = {
            volume_size = "80Gi"
            volume_type = "gp3"
            encrypted   = true
          }
        }
      ]
    }
  ]

  nodepools = [
    {
      name          = "cloudpilot-general"
      nodeclass     = "cloudpilot"
      enable        = true
      capacity_type = ["spot", "on-demand"]
      instance_arch = ["amd64"]
      labels        = { team = "platform" }
      taints = [
        {
          key    = "dedicated"
          value  = "wa"
          effect = "NoSchedule"
        }
      ]
    }
  ]

  enable_workload_autoscaler = false
}
```

### Complete -- Node Autoscaler + Workload Autoscaler

```hcl
provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}

module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

  cluster_name        = "my-eks-cluster"
  region              = "us-west-2"
  enable_rebalance    = true
  restore_node_number = 3

  nodeclasses = [
    {
      name                 = "cloudpilot"
      system_disk_size_gib = 30
      instance_tags        = { "cloudpilot.ai/managed" = "true" }
    }
  ]

  nodepools = [
    {
      name          = "cloudpilot-general"
      nodeclass     = "cloudpilot"
      enable        = true
      capacity_type = ["spot", "on-demand"]
      instance_arch = ["amd64"]
    }
  ]

  enable_workload_autoscaler = true

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
      jvm_heap_buffer       = "300Mi"
      jvm_min_heap_xms_ratio_of_memory = "0.25"
      jvm_recent_non_heap_window       = "2h"
      jvm_heap_used_percentile         = 20
    }
  ]

  autoscaling_policies = [
    {
      name                       = "default-ap"
      enable                     = true
      recommendation_policy_name = "balanced"
      disable_runtime_optimization = false
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
          }
        }
      ]

      update_schedules = [
        {
          name = "default"
          mode = "inplace"
        }
      ]
    }
  ]

  enable_proactive = [
    {
      namespaces = ["my-namespace"]
    }
  ]

  disable_proactive = [
    {
      namespaces = ["kube-system"]
    }
  ]
}
```

## Examples

- [Minimal](examples/minimal/) -- Quick-start with agent-only install
- [Onboard Existing Cluster](examples/onboard-existing-cluster/) -- Connect an existing EKS cluster to CloudPilot AI using AWS provider assume-role and module `aws_assume_role`
- [Node Autoscaler Only](examples/node-autoscaler-only/) -- Node autoscaler with custom nodeclasses/nodepools, no Workload Autoscaler
- [Complete](examples/complete/) -- Full configuration with both autoscalers, policies, and proactive optimization
- [Import Existing](examples/import-existing/) -- Discover existing provider resources with `generated.tf`, convert them into module config, and then import into this module

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `cluster_name` | Name of the EKS cluster to be managed by CloudPilot AI | `string` |
| `region` | AWS region where the EKS cluster is located | `string` |

### Node Autoscaler -- Authentication & Access

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cluster_id` | Optional existing CloudPilot cluster ID override | `string` | `null` |
| `aws_profile` | AWS CLI named profile for AWS operations | `string` | `""` |
| `aws_assume_role` | Optional IAM role to assume for CloudPilot AWS CLI, kubeconfig, kubectl, and helm operations | `any` | `null` |
| `kubeconfig` | Path to the kubeconfig file | `string` | `null` |
| `custom_node_role` | Custom IAM role name for EC2 instances | `string` | `null` |

### Node Autoscaler -- Behavior

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `only_install_agent` | Only install the agent without optimization | `bool` | `false` |
| `enable_rebalance` | Enable automatic workload rebalancing | `bool` | `false` |
| `disable_workload_uploading` | Disable workload information uploading | `bool` | `false` |
| `enable_upgrade` | Enable CloudPilot AI component upgrade through the cluster upgrade script | `bool` | `false` |
### Cluster Setting

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cluster_setting` | Optional cluster-level setting object | `any` | `null` |

### Node Autoscaler -- Destroy / Restore

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `skip_restore` | Skip node restore on resource destruction | `bool` | `false` |
| `restore_node_number` | Nodes to restore from original node groups on destroy | `number` | `0` |

### Node Autoscaler -- NodeClasses & NodePools

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `nodeclass_templates` | List of NodeClass template objects | `any` | `[]` |
| `nodeclasses` | List of NodeClass objects | `any` | `[]` |
| `nodepool_templates` | List of NodePool template objects | `any` | `[]` |
| `nodepools` | List of NodePool objects | `any` | `[]` |

### Node Autoscaler -- Workloads

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `workload_templates` | List of workload template objects | `any` | `[]` |
| `workloads` | List of workload objects | `any` | `[]` |

### Workload Autoscaler

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_workload_autoscaler` | Whether to deploy the Workload Autoscaler | `bool` | `true` |
| `wa_storage_class` | StorageClass for VictoriaMetrics persistent volume | `string` | `""` |
| `wa_enable_node_agent` | Enable Node Agent DaemonSet | `bool` | `true` |
| `wa_enable_new_workloads_proactive_update` | Enable proactive update automatically for new workloads | `bool` | `false` |
| `wa_limiter_quota_per_window` | Workload Autoscaler limiter quota per window | `number` | `5` |
| `wa_limiter_burst` | Workload Autoscaler limiter burst | `number` | `10` |
| `wa_limiter_window_seconds` | Workload Autoscaler limiter window in seconds | `number` | `30` |
| `wa_enable_preempted_pod_gc` | Enable garbage collection for preempted pods | `bool` | `true` |
| `wa_preempted_pod_gc_ttl` | TTL for preempted pod garbage collection | `string` | `"30m"` |
| `wa_enable_initial_optimization_data_window_check` | Require initial optimization data window before enabling update paths | `bool` | `true` |
| `recommendation_policies` | List of RecommendationPolicy objects | `any` | `[]` |
| `autoscaling_policies` | List of AutoscalingPolicy objects | `any` | `[]` |
| `enable_proactive` | Workload filters to enable proactive optimization | `any` | `[]` |
| `disable_proactive` | Workload filters to disable proactive optimization | `any` | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | CloudPilot AI unique identifier for the managed EKS cluster |
| `cluster_name` | Name of the EKS cluster |
| `region` | AWS region where the EKS cluster is located |
| `account_id` | AWS account ID where the cluster is deployed |
| `kubeconfig` | Path to the kubeconfig file used for accessing the EKS cluster |
| `enable_rebalance` | Whether workload rebalancing is enabled |
| `workload_autoscaler_enabled` | Whether the Workload Autoscaler resource was created |

## Provider Configuration

This module requires the `cloudpilotai` provider to be configured by the caller. The module does **not** include a `provider` block itself. Configure it in your root module:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudpilotai = {
      source  = "cloudpilot-ai/cloudpilotai"
      version = ">= 0.4.0"
    }
  }
}

provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}
```

## License

MIT -- See [LICENSE](LICENSE) for details.
