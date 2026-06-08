################################################################################
# EKS Cluster - Required
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster to be managed by CloudPilot AI."
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster is located."
  type        = string
}

variable "cluster_id" {
  description = "Optional existing CloudPilot cluster ID. When set, the provider uses this value instead of re-generating the cluster ID locally."
  type        = string
  default     = null
}

################################################################################
# EKS Cluster - Authentication & Access
################################################################################

variable "aws_profile" {
  description = "AWS CLI named profile to use for all AWS operations (sts, eks). If empty, the default profile or environment credentials are used."
  type        = string
  default     = ""
}

variable "aws_assume_role" {
  description = "Optional IAM role to assume for CloudPilot AWS CLI, kubeconfig, kubectl, and helm operations. Source credentials still come from aws_profile or the ambient AWS credential chain."
  type        = any
  default     = null
}

variable "kubeconfig" {
  description = "Path to the kubeconfig file for accessing the EKS cluster. If not set, the provider generates it automatically."
  type        = string
  default     = null
}

variable "custom_node_role" {
  description = "Custom IAM role name for EC2 instances. When set, this role will be added to the CloudPilot controller's PassNodeIAMRole policy during installation."
  type        = string
  default     = null
}

################################################################################
# Node Autoscaler - Behavior
################################################################################

variable "only_install_agent" {
  description = "Only install the CloudPilot AI agent without additional optimization. Useful for read-only monitoring."
  type        = bool
  default     = false
}

variable "enable_rebalance" {
  description = "Enable automatic workload rebalancing across node pools. Overrides only_install_agent if set to true."
  type        = bool
  default     = false
}

variable "disable_workload_uploading" {
  description = "Disable automatic uploading of workload information to CloudPilot AI."
  type        = bool
  default     = false
}

variable "enable_upgrade" {
  description = "Enable upgrading CloudPilot AI components through the cluster upgrade script. The provider checks whether the cluster needs upgrade first, and only runs the upgrade when required. When custom_node_role is set, it is passed to the upgrade script."
  type        = bool
  default     = false
}

################################################################################
# Cluster Setting
################################################################################

variable "cluster_setting" {
  description = <<-EOT
    Optional cluster-level setting object. When null, this module does not manage
    /api/v1/clusters/{cluster_id}/setting. Supported fields:
    - enable_node_repair
    - enable_disk_monitor
    - discount
    - pre_run_command
    - post_run_command
  EOT
  type        = any
  default     = null
}

################################################################################
# Node Autoscaler - Destroy / Restore
################################################################################

variable "skip_restore" {
  description = "When true, skip the node restore step during resource destruction. Takes precedence over restore_node_number."
  type        = bool
  default     = false
}

variable "restore_node_number" {
  description = "Number of nodes to provision from the original node group when destroying. Set to 0 to leave the cluster in its optimized state."
  type        = number
  default     = 0
}

################################################################################
# Node Autoscaler - NodeClasses
################################################################################

variable "nodeclass_templates" {
  description = <<-EOT
    List of NodeClass template objects for reuse across nodeclasses. Each object supports:
    - template_name (Required) - Template identifier
    - role, enable_image_accelerator, instance_tags, system_disk_size_gib,
      ami_alias, user_data, block_device_mappings,
      extra_cpu_allocation_mcore, extra_memory_allocation_mib,
      subnet_selector_terms, security_group_selector_terms (all Optional)
  EOT
  type        = any
  default     = []
}

variable "nodeclasses" {
  description = <<-EOT
    List of NodeClass objects defining EC2 instance configurations. Each object supports:
    - name (Required) - NodeClass name (default CloudPilot name is "cloudpilot")
    - template_name, role, enable_image_accelerator, origin_nodeclass_json,
      instance_tags, system_disk_size_gib, ami_alias, user_data,
      block_device_mappings, extra_cpu_allocation_mcore,
      extra_memory_allocation_mib, subnet_selector_terms,
      security_group_selector_terms (all Optional)
  EOT
  type        = any
  default     = []
}

################################################################################
# Node Autoscaler - NodePools
################################################################################

variable "nodepool_templates" {
  description = <<-EOT
    List of NodePool template objects for reuse across nodepools. Each object supports:
    - template_name (Required) - Template identifier
    - enable, nodeclass, enable_gpu, enable_image_accelerator, provision_priority,
      instance_arch, instance_family, capacity_type, zone,
      instance_cpu_min, instance_cpu_max, instance_memory_min, instance_memory_max,
      node_disruption_limit, node_disruption_delay, labels, taints (all Optional)
  EOT
  type        = any
  default     = []
}

variable "nodepools" {
  description = <<-EOT
    List of NodePool objects defining node provisioning rules. Each object supports:
    - name (Required) - NodePool name (default CloudPilot name is "cloudpilot-general")
    - template_name, enable, nodeclass, enable_gpu, enable_image_accelerator,
      origin_nodepool_json, provision_priority, instance_arch, instance_family,
      capacity_type, zone, instance_cpu_min, instance_cpu_max,
      instance_memory_min, instance_memory_max, node_disruption_limit,
      node_disruption_delay, labels, taints (all Optional)
  EOT
  type        = any
  default     = []
}

################################################################################
# Node Autoscaler - Workloads
################################################################################

variable "workload_templates" {
  description = <<-EOT
    List of workload template objects. Each object supports:
    - template_name (Required) - Template identifier
    - rebalance_able, spot_friendly, min_non_spot_replicas (all Optional)
  EOT
  type        = any
  default     = []
}

variable "workloads" {
  description = <<-EOT
    List of workload objects to be managed by CloudPilot AI. Each object supports:
    - name (Required) - Workload name
    - type (Required) - Workload type (e.g. "deployment", "statefulset")
    - namespace (Required) - Kubernetes namespace
    - template_name, rebalance_able, spot_friendly, min_non_spot_replicas (all Optional)
  EOT
  type        = any
  default     = []
}

################################################################################
# Workload Autoscaler - General
################################################################################

variable "enable_workload_autoscaler" {
  description = "Whether to deploy the CloudPilot AI Workload Autoscaler on this cluster."
  type        = bool
  default     = true
}

variable "wa_storage_class" {
  description = "StorageClass name for VictoriaMetrics persistent volume. If empty, the cluster default StorageClass is used."
  type        = string
  default     = ""
}

variable "wa_enable_node_agent" {
  description = "Whether to enable the Node Agent DaemonSet for per-node metrics collection."
  type        = bool
  default     = true
}

variable "wa_enable_new_workloads_proactive_update" {
  description = "Enable proactive update automatically for new workloads once recommendations are ready."
  type        = bool
  default     = false
}

variable "wa_limiter_quota_per_window" {
  description = "Workload Autoscaler limiter quota per window."
  type        = number
  default     = 5
}

variable "wa_limiter_burst" {
  description = "Workload Autoscaler limiter burst."
  type        = number
  default     = 10
}

variable "wa_limiter_window_seconds" {
  description = "Workload Autoscaler limiter window in seconds."
  type        = number
  default     = 30
}

variable "wa_enable_preempted_pod_gc" {
  description = "Enable garbage collection for preempted pods."
  type        = bool
  default     = true
}

variable "wa_preempted_pod_gc_ttl" {
  description = "TTL for preempted pod garbage collection, for example 30m."
  type        = string
  default     = "30m"
}

variable "wa_enable_initial_optimization_data_window_check" {
  description = "Require initial optimization data window before enabling update paths for new workloads."
  type        = bool
  default     = true
}

################################################################################
# Workload Autoscaler - Recommendation Policies
################################################################################

variable "recommendation_policies" {
  description = <<-EOT
    List of RecommendationPolicy objects. Each object supports:
    - name (Required) - Policy name
    - history_window_cpu (Required) - CPU history window duration (e.g. "24h")
    - history_window_memory (Required) - Memory history window duration (e.g. "48h")
    - evaluation_period (Required) - Evaluation period (e.g. "1m")
    - strategy_type, percentile_cpu, percentile_memory, buffer_cpu, buffer_memory,
      request_min_cpu, request_min_memory, request_max_cpu, request_max_memory,
      jvm_heap_buffer, jvm_min_heap_xms_ratio_of_memory,
      jvm_recent_non_heap_window, jvm_heap_used_percentile (all Optional)
  EOT
  type        = any
  default     = []
}

################################################################################
# Workload Autoscaler - Autoscaling Policies
################################################################################

variable "autoscaling_policies" {
  description = <<-EOT
    List of AutoscalingPolicy objects. Each object supports:
    - name (Required) - Policy name
    - recommendation_policy_name (Required) - Name of the RecommendationPolicy to use
    - enable, priority, target_refs, update_schedules, limit_policies,
      update_resources, drift_threshold_cpu, drift_threshold_memory,
      on_policy_removal, startup_boost_enabled, startup_boost_min_boost_duration,
      startup_boost_min_ready_duration, startup_boost_multiplier_cpu,
      startup_boost_multiplier_memory, disable_runtime_optimization,
      target_refs.label_selector, in_place_fallback_default_policy,
      in_place_fallback_reason_policies (all Optional)
  EOT
  type        = any
  default     = []
}

################################################################################
# Workload Autoscaler - Proactive Optimization
################################################################################

variable "enable_proactive" {
  description = <<-EOT
    List of workload filter objects to enable proactive optimization. Each object supports:
    - namespaces, workload_kinds, workload_name, workload_state,
      autoscaling_policy_names, optimization_states, disable_proactive_update,
      recommendation_policy_names, runtime_languages, optimized (all Optional)
  EOT
  type        = any
  default     = []
}

variable "disable_proactive" {
  description = <<-EOT
    List of workload filter objects to disable proactive optimization. Each object supports:
    - namespaces, workload_kinds, workload_name, workload_state,
      autoscaling_policy_names, optimization_states, disable_proactive_update,
      recommendation_policy_names, runtime_languages, optimized (all Optional)
  EOT
  type        = any
  default     = []
}
