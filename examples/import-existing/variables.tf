variable "cloudpilot_api_key" {
  description = "CloudPilot AI API key. Obtain from https://console.cloudpilot.ai"
  type        = string
  sensitive   = true
}

variable "cloudpilot_api_endpoint" {
  description = "CloudPilot AI API endpoint URL."
  type        = string
  default     = "https://api.cloudpilot.ai"
}

variable "cluster_id" {
  description = "Existing CloudPilot AI cluster ID. Required for the bootstrap import blocks."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI named profile to use for AWS operations after migration. Empty uses the default profile or environment credentials."
  type        = string
  default     = ""
}

variable "aws_assume_role" {
  description = "Optional IAM role to assume for AWS operations after migration. This is local execution context and cannot be recovered from the CloudPilot API."
  type        = any
  default     = null
}
