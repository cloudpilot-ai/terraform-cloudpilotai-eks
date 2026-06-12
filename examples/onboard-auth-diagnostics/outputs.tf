output "aws_provider_identity_arn" {
  description = "ARN seen by the Terraform AWS provider after assuming aws_assume_role_arn."
  value       = data.aws_caller_identity.assumed.arn
}

output "aws_provider_account_id" {
  description = "Account ID seen by the Terraform AWS provider after assuming aws_assume_role_arn."
  value       = data.aws_caller_identity.assumed.account_id
}

output "cloudpilot_cli_source_identity_arn" {
  description = "Source ARN seen by the CloudPilot-style AWS CLI path before assume-role."
  value       = data.external.cloudpilot_cli.result.source_arn
}

output "cloudpilot_cli_source_mode" {
  description = "Whether the CloudPilot-style AWS CLI path used a named profile or ambient credentials as its source."
  value       = data.external.cloudpilot_cli.result.source_mode
}

output "cloudpilot_cli_assumed_identity_arn" {
  description = "ARN seen after the CloudPilot-style AWS CLI path assumes aws_assume_role_arn."
  value       = data.external.cloudpilot_cli.result.assumed_arn
}

output "cloudpilot_cli_describe_cluster_arn" {
  description = "EKS cluster ARN returned by describe-cluster when using the CloudPilot-style assumed-role credentials."
  value       = data.external.cloudpilot_cli.result.cluster_arn
}

output "cloudpilot_cli_can_describe_cluster" {
  description = "True when the CloudPilot-style assumed-role credentials can call aws eks describe-cluster for the target cluster."
  value       = local.cloudpilot_cli_can_describe_cluster
}

output "cloudpilot_cli_token_expiration" {
  description = "Expiration timestamp returned by aws eks get-token when using the CloudPilot-style assumed-role credentials."
  value       = data.external.cloudpilot_cli.result.token_expiration
}

output "cloudpilot_cli_can_get_token" {
  description = "True when the CloudPilot-style assumed-role credentials can call aws eks get-token for the target cluster."
  value       = local.cloudpilot_cli_can_get_token
}

output "cloudpilot_cli_has_cluster_access_via_aws_cli" {
  description = "True when the CloudPilot-style assumed-role credentials pass the AWS-side EKS preflight by both describing the target cluster and minting an auth token for it via AWS CLI. This does not by itself prove Kubernetes API authorization or RBAC inside the cluster."
  value       = local.cloudpilot_cli_has_cluster_access_via_aws_cli
}

output "aws_provider_identity_matches_cloudpilot_cli" {
  description = "True when the Terraform AWS provider and the CloudPilot-style AWS CLI path end up with the same assumed identity ARN."
  value       = local.aws_provider_identity_matches_cloudpilot_cli
}
