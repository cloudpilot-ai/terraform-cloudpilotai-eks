output "cluster_id" {
  description = "CloudPilot AI cluster ID"
  value       = module.cloudpilotai_eks.cluster_id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.cloudpilotai_eks.cluster_name
}
