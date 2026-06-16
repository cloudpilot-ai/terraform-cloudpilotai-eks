################################################################################
# Node Autoscaler - EKS Cluster
################################################################################

output "cluster_id" {
  description = "CloudPilot AI unique identifier for the managed EKS cluster."
  value       = cloudpilotai_eks_cluster.this.cluster_id
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = cloudpilotai_eks_cluster.this.cluster_name
}

output "region" {
  description = "AWS region where the EKS cluster is located."
  value       = cloudpilotai_eks_cluster.this.region
}

output "account_id" {
  description = "AWS account ID where the cluster is deployed."
  value       = cloudpilotai_eks_cluster.this.account_id
}

output "kubeconfig" {
  description = "Path to the kubeconfig file used for accessing the EKS cluster."
  value       = cloudpilotai_eks_cluster.this.kubeconfig
}

output "enable_rebalance" {
  description = "Whether workload rebalancing is enabled."
  value       = cloudpilotai_eks_cluster.this.enable_rebalance
}

output "agent_version" {
  description = "Version of the CloudPilot AI agent currently installed on the cluster."
  value       = cloudpilotai_eks_cluster.this.agent_version
}

output "onboard_manifest_version" {
  description = "Latest CloudPilot onboard manifest version reported by the service."
  value       = cloudpilotai_eks_cluster.this.onboard_manifest_version
}

output "need_upgrade" {
  description = "Whether CloudPilot currently reports that this cluster needs an upgrade."
  value       = cloudpilotai_eks_cluster.this.need_upgrade
}

################################################################################
# Workload Autoscaler
################################################################################

output "workload_autoscaler_enabled" {
  description = "Whether the Workload Autoscaler resource was created."
  value       = var.enable_workload_autoscaler
}
