output "cluster_id" {
  description = "CloudPilot AI cluster ID"
  value       = module.cloudpilotai_eks.cluster_id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.cloudpilotai_eks.cluster_name
}

output "agent_version" {
  description = "Version of the CloudPilot AI agent currently installed on the cluster"
  value       = module.cloudpilotai_eks.agent_version
}

output "onboard_manifest_version" {
  description = "Latest CloudPilot onboard manifest version reported by the service"
  value       = module.cloudpilotai_eks.onboard_manifest_version
}

output "need_upgrade" {
  description = "Whether CloudPilot currently reports that this cluster needs an upgrade"
  value       = module.cloudpilotai_eks.need_upgrade
}
