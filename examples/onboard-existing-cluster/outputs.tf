output "aws_provider_identity_arn" {
  description = "ARN seen by the Terraform AWS provider after assuming aws_assume_role_arn."
  value       = data.aws_caller_identity.assumed.arn
}

output "eks_cluster_arn" {
  description = "ARN of the existing EKS cluster that the AWS provider can describe."
  value       = data.aws_eks_cluster.target.arn
}

output "cloudpilot_cluster_id" {
  description = "CloudPilot AI cluster ID after onboarding."
  value       = module.cloudpilotai_eks.cluster_id
}

output "cloudpilot_kubeconfig" {
  description = "Explicitly configured kubeconfig path, or null when the provider uses execution-local kubeconfigs."
  value       = module.cloudpilotai_eks.kubeconfig
}

output "cloudpilot_agent_version" {
  description = "Version of the CloudPilot AI agent currently installed on the cluster."
  value       = module.cloudpilotai_eks.agent_version
}

output "cloudpilot_onboard_manifest_version" {
  description = "Latest CloudPilot onboard manifest version reported by the service."
  value       = module.cloudpilotai_eks.onboard_manifest_version
}

output "cloudpilot_need_upgrade" {
  description = "Whether CloudPilot currently reports that this cluster needs an upgrade."
  value       = module.cloudpilotai_eks.need_upgrade
}
