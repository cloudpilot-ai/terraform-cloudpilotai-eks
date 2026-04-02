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
  description = "Kubeconfig content for accessing the EKS cluster."
  value       = cloudpilotai_eks_cluster.this.kubeconfig
}

output "enable_rebalance" {
  description = "Whether workload rebalancing is enabled."
  value       = cloudpilotai_eks_cluster.this.enable_rebalance
}

################################################################################
# Workload Autoscaler
################################################################################

output "workload_autoscaler_enabled" {
  description = "Whether the Workload Autoscaler resource was created."
  value       = var.enable_workload_autoscaler
}
