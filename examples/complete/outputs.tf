output "cluster_id" {
  description = "CloudPilot AI cluster ID"
  value       = module.cloudpilotai_eks.cluster_id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.cloudpilotai_eks.cluster_name
}

output "account_id" {
  description = "AWS account ID"
  value       = module.cloudpilotai_eks.account_id
}

output "enable_rebalance" {
  description = "Whether rebalance is enabled"
  value       = module.cloudpilotai_eks.enable_rebalance
}

output "workload_autoscaler_enabled" {
  description = "Whether the Workload Autoscaler is deployed"
  value       = module.cloudpilotai_eks.workload_autoscaler_enabled
}
