variable "cluster_name" {
  description = "Name of the existing EKS cluster to inspect."
  type        = string
}

variable "region" {
  description = "AWS region where the existing EKS cluster is located."
  type        = string
}

variable "aws_source_profile" {
  description = "Optional local AWS CLI profile that contains the source credentials. Leave null when using environment credentials or CI/OIDC credentials."
  type        = string
  default     = null
}

variable "aws_assume_role_arn" {
  description = "IAM role ARN that both the Terraform AWS provider and the CloudPilot CLI path should assume."
  type        = string
}

variable "aws_assume_role_session_name" {
  description = "STS session name used when assuming aws_assume_role_arn."
  type        = string
  default     = "cloudpilotai-onboard"
}
