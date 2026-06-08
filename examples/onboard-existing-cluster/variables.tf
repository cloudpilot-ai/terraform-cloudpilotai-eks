variable "cloudpilot_api_key" {
  description = "CloudPilot AI API key. Obtain from https://console.cloudpilot.ai."
  type        = string
  sensitive   = true
}

variable "cloudpilot_api_endpoint" {
  description = "CloudPilot AI API endpoint URL."
  type        = string
  default     = "https://api.cloudpilot.ai"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster to onboard to CloudPilot AI."
  type        = string
}

variable "region" {
  description = "AWS region where the existing EKS cluster is located."
  type        = string
}

variable "aws_source_profile" {
  description = "Optional local AWS CLI profile that contains the source access key credentials. Leave null when using environment credentials or CI/OIDC credentials."
  type        = string
  default     = null
}

variable "aws_assume_role_arn" {
  description = "IAM role ARN that Terraform AWS provider and CloudPilot provider should assume to access the existing EKS cluster."
  type        = string
}

variable "aws_assume_role_session_name" {
  description = "STS session name used when assuming aws_assume_role_arn."
  type        = string
  default     = "cloudpilotai-onboard"
}
