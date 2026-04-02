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

  cluster_name        = var.cluster_name
  region              = var.region
  restore_node_number = var.restore_node_number

  only_install_agent = false
  enable_rebalance   = var.enable_rebalance

  nodeclasses = [
    {
      name                 = "cloudpilot"
      enable_image_accelerator = false
      system_disk_size_gib     = 20
      instance_tags            = { "cloudpilot.ai/managed" = "true" }
    }
  ]

  nodepools = [
    {
      name          = "cloudpilot-general"
      nodeclass     = "cloudpilot"
      enable        = true
      capacity_type = ["spot", "on-demand"]
      instance_arch = ["amd64"]
      instance_cpu_max      = 17
      instance_memory_max   = 32769
      node_disruption_limit = "2"
      node_disruption_delay = "60m"
    }
  ]

  enable_workload_autoscaler = false
}
