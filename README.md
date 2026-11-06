# CloudPilot AI EKS Terraform Module

Terraform module for deploying [CloudPilot AI](https://cloudpilot.ai/) Node Autoscaler and Workload Autoscaler on Amazon EKS clusters. This module provides a simplified, opinionated interface that wraps the [`cloudpilotai`](https://registry.terraform.io/providers/cloudpilot-ai/cloudpilotai/latest/docs) Terraform provider resources.

## Release preparation

Module v0.6.0 targets provider v0.7.0 and server v1.36.4. These versions are release candidates and have not been published yet. Until publication, use this module checkout as a local `source` with a locally built provider containing [provider PR #44](https://github.com/cloudpilot-ai/terraform-provider-cloudpilotai/pull/44). Registry examples below are intended for use after the releases are published.

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

## Server v1.36.4 fields and null values

Provider v0.7.0 is required for these fields; use the local release candidate build until it is published. The module passes nested objects directly to the provider, including the following released configuration:

| Module input | Supported fields |
|--------------|------------------|
| `cluster_setting` | `disruption_cooldown`, `aws_spot_allocation_strategy` |
| `nodeclasses` / `nodeclass_templates` | `memory_extension` |
| `memory_extension` | `enabled`, `reclaim_policy`, `cold_memory`, `cached_memory` |
| `memory_extension.cold_memory` | `sizing_mode`, `memory_ratio_percent`, `min_gib`, `max_gib`, `max_disk_percent` |
| `memory_extension.cached_memory` | `max_memory_percent` |
| `block_device_mappings[].ebs.volume_size_policy` | `per_vcpu_gib`, `max_size_gib` |
| `nodepools` / `nodepool_templates` | `disruption_cooldown`, `job_nodepool_optimization`, `nri_swap_policy` |
| `job_nodepool_optimization` | `min_active_nodes`, `provisioning_delay` |
| `nri_swap_policy` | `enabled`, `memory_limit_multiplier` |
| `recommendation_policies` | `jvm_min_heap_xms`, `jvm_max_heap_xms`, `jvm_min_heap_xmx`, `jvm_max_heap_xmx` |
| `autoscaling_policies` | `startup_boost_recommendation_policy_name`, `startup_boost_update_resources` |
| `enable_proactive` / `disable_proactive` | `startup_boost_enabled` |

For the optional nested fields above, null values remain unmanaged and preserve the server value. Existing public input defaults listed below still apply; pass null explicitly to leave a supported input unmanaged. For templates, an omitted object key inherits its template value; an explicit null key overrides the template with null. Nested objects replace the template object as a whole. Within a non-empty policy, null child fields preserve their server values.

Explicit empty values request a reset: `job_nodepool_optimization = {}` removes the Job policy, `volume_size_policy = {}` removes dynamic disk sizing, and `memory_extension = {}` or `nri_swap_policy = {}` disables that feature. Empty `cold_memory` or `cached_memory` objects restore server defaults. An object whose optional children are all null is treated as an empty object. A pool's `disruption_cooldown = ""` removes its override; `"0s"` explicitly disables the extra delay. Required fields and values rejected by the server cannot be cleared with an invalid empty value.

```hcl
nodeclass_templates = [{
  template_name = "illustrative-memory"
  ami_alias     = "al2023@latest"
  memory_extension = {
    enabled       = true
    cold_memory   = { sizing_mode = "Auto", min_gib = 1, max_gib = 16 }
    cached_memory = { max_memory_percent = 10 }
  }
}]
nodeclasses = [{
  name             = "illustrative-class"
  template_name    = "illustrative-memory"
  memory_extension = null # Preserve the remote policy instead of applying the template policy.
}]
```

Memory Extension requires AL2023 nodes. NRI swap requires EKS 1.34 or later and an enabled Memory Extension policy on the referenced NodeClass. A new dynamic EBS size policy requires `max_size_gib`; it applies to the kubelet root volume. Cooldowns accept non-negative durations such as `0s` or `5m`; setting `0s` disables the extra delay. See the [complete example](examples/complete/) for configured policies and [provider documentation](https://registry.terraform.io/providers/cloudpilot-ai/cloudpilotai/latest/docs/resources/eks_cluster) for validation rules.

To disable Memory Extension or NRI swap explicitly, set its `enabled` field to `false`. Empty JVM bound strings clear those bounds. For limit policies, selecting one action replaces the previous mode; `remove_limit = false`, `keep_limit = false`, or an empty `multiplier` / `auto_headroom` disables only that action. Null action fields preserve the existing mode unless a different action is selected.

Maintenance mode and Saving Report baseline timestamps are outside this module's supported surface. The import converter omits those fields and preserves null values for the supported settings.

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
| `kubeconfig` | Optional explicit kubeconfig path. When omitted, the provider generates execution-local kubeconfigs without storing their paths in state. | `string` | `null` |
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
| `scheduled_rebalances` | Scheduled rebalance policies; null leaves server policies unmanaged | `any` | `null` |

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
| `kubeconfig` | Explicitly configured EKS kubeconfig path, or null when the provider generates execution-local kubeconfigs |
| `enable_rebalance` | Whether workload rebalancing is enabled |
| `agent_version` | Version of the CloudPilot AI agent currently installed on the cluster |
| `onboard_manifest_version` | Latest CloudPilot onboard manifest version reported by the service |
| `need_upgrade` | Whether CloudPilot currently reports that this cluster needs an upgrade |
| `workload_autoscaler_enabled` | Whether the Workload Autoscaler resource was created |

## Upgrading from provider-generated kubeconfig state

Provider versions before 0.5.1 could store a generated path from the local Terraform or Terragrunt working directory. After upgrading the provider and this module, run a fresh plan instead of reusing an older saved plan. When `kubeconfig` is omitted, the plan removes the old path from state in place; no state edit, import, or resource replacement is required. The cluster and Workload Autoscaler resources generate their own kubeconfigs in each execution environment.

If the legacy Workload Autoscaler needs `aws_profile` or `aws_assume_role`, keep `enable_workload_autoscaler = true` for this upgrade apply. Disable it or destroy the stack only after that apply has stored the new access fields; Terraform does not pass module configuration to the provider when deleting an old resource directly.

## Provider Configuration

This module requires the `cloudpilotai` provider to be configured by the caller. The module does **not** include a `provider` block itself. Configure it in your root module:

```hcl
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
  api_key = var.cloudpilotai_api_key
}
```

## Local verification

Run the import conversion and template evaluation regressions with:

```bash
python3 -m unittest discover -s examples/import-existing/scripts -p 'test_*.py' -v
python3 -m unittest discover -s tests -p 'test_*.py' -v
terraform fmt -check -recursive
```

Template tests evaluate the module locals with Terraform and OpenTofu when installed, using temporary directories. For provider validation before v0.7.0 is published, use an isolated CLI configuration with a development override and local provider mirror, then run `init -backend=false` and `validate` against a temporary root pointing at this module. These checks do not apply infrastructure changes.

## License

MIT -- See [LICENSE](LICENSE) for details.
