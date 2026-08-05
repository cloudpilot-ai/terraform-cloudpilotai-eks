terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    cloudpilotai = {
      source  = "cloudpilot-ai/cloudpilotai"
      version = ">= 0.6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_source_profile

  assume_role {
    role_arn     = var.aws_assume_role_arn
    session_name = var.aws_assume_role_session_name
  }
}

provider "cloudpilotai" {
  api_endpoint = var.cloudpilot_api_endpoint
  api_key      = var.cloudpilot_api_key
}

data "aws_caller_identity" "assumed" {}

data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

module "cloudpilotai_eks" {
  source = "cloudpilot-ai/eks/cloudpilotai"

  cluster_name = data.aws_eks_cluster.target.name
  region       = var.region

  aws_profile = var.aws_source_profile == null ? "" : var.aws_source_profile
  aws_assume_role = {
    role_arn     = var.aws_assume_role_arn
    session_name = var.aws_assume_role_session_name
  }

  only_install_agent         = false
  enable_rebalance           = true
  enable_workload_autoscaler = false
  disable_workload_uploading = true
  restore_node_number        = 0
}
