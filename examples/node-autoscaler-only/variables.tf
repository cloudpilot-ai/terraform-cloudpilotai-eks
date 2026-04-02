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

variable "cluster_name" {
  description = "Name of the EKS cluster to be managed."
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster is located."
  type        = string
}

variable "restore_node_number" {
  description = "Number of nodes to restore from original node groups on destroy."
  type        = number
  default     = 0
}

variable "enable_rebalance" {
  description = "Enable automatic workload rebalancing across node pools."
  type        = bool
  default     = true
}
