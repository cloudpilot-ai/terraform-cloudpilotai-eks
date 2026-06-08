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
  description = "Generated kubeconfig path. It carries the CloudPilot provider auth needed by later kubectl and helm calls."
  value       = module.cloudpilotai_eks.kubeconfig
}
