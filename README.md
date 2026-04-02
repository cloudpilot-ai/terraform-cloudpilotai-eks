# CloudPilot AI EKS Terraform Module

Terraform module for deploying [CloudPilot AI](https://cloudpilot.ai/) Node Autoscaler and Workload Autoscaler on Amazon EKS clusters. This module provides a simplified, opinionated interface that wraps the [`cloudpilotai`](https://registry.terraform.io/providers/cloudpilot-ai/cloudpilotai/latest/docs) Terraform provider resources.

## Features

- Install and configure the CloudPilot AI Node Autoscaler on EKS clusters
- Optionally deploy the Workload Autoscaler with recommendation and autoscaling policies
- Manage NodeClasses and NodePools for Karpenter-based node provisioning
- Configure workload-level optimization (spot-friendly, rebalance, min non-spot replicas)
- Enable proactive optimization for automatic workload right-sizing

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with EKS permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster operations
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)

## Usage

### Minimal -- Install agent only

```hcl
provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}

module "cloudpilotai_eks" {
  source = "github.com/cloudpilot-ai/terraform-cloudpilotai-eks"

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
  source = "github.com/cloudpilot-ai/terraform-cloudpilotai-eks"

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

  enable_workload_autoscaler = false
}
```

### Complete -- Node Autoscaler + Workload Autoscaler

```hcl
provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}

module "cloudpilotai_eks" {
  source = "github.com/cloudpilot-ai/terraform-cloudpilotai-eks"

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
    }
  ]

  autoscaling_policies = [
    {
      name                       = "default-ap"
      enable                     = true
      recommendation_policy_name = "balanced"

      target_refs = [
        {
          api_version = "apps/v1"
          kind        = "Deployment"
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
- [Node Autoscaler Only](examples/node-autoscaler-only/) -- Node autoscaler with custom nodeclasses/nodepools, no Workload Autoscaler
- [Complete](examples/complete/) -- Full configuration with both autoscalers, policies, and proactive optimization

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `cluster_name` | Name of the EKS cluster to be managed by CloudPilot AI | `string` |
| `region` | AWS region where the EKS cluster is located | `string` |

### Node Autoscaler -- Authentication & Access

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `aws_profile` | AWS CLI named profile for AWS operations | `string` | `""` |
| `kubeconfig` | Kubernetes configuration file content | `string` | `null` |
| `custom_node_role` | Custom IAM role name for EC2 instances | `string` | `null` |

### Node Autoscaler -- Behavior

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `only_install_agent` | Only install the agent without optimization | `bool` | `false` |
| `enable_rebalance` | Enable automatic workload rebalancing | `bool` | `false` |
| `disable_workload_uploading` | Disable workload information uploading | `bool` | `false` |
| `enable_upgrade_agent` | Enable agent auto-upgrade | `bool` | `false` |
| `enable_upgrade_rebalance_component` | Enable rebalance component auto-upgrade | `bool` | `false` |
| `enable_upload_config` | Enable nodepool/nodeclass config uploading | `bool` | `true` |
| `enable_diversity_instance_type` | Enable diverse instance types | `bool` | `false` |

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
| `wa_enable_upgrade` | Enable Workload Autoscaler component auto-upgrade | `bool` | `false` |
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
| `kubeconfig` | Kubeconfig content for accessing the EKS cluster |
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
      version = "~> 0.1"
    }
  }
}

provider "cloudpilotai" {
  api_key = var.cloudpilotai_api_key
}
```

## License

Apache 2.0 -- See [LICENSE](LICENSE) for details.
