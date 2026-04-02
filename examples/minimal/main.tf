terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudpilotai = {
      source  = "cloudpilot-ai/cloudpilotai"
      version = "~> 0.1"
    }
  }
}

provider "cloudpilotai" {
  api_endpoint = var.cloudpilot_api_endpoint
  api_key      = var.cloudpilot_api_key
}

module "cloudpilotai_eks" {
  source = "../../"

  cluster_name       = var.cluster_name
  region             = var.region
  only_install_agent = true

  enable_workload_autoscaler = false
}
