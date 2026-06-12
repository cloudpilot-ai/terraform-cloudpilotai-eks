terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
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

data "aws_caller_identity" "assumed" {}

data "aws_eks_cluster" "target" {
  name = var.cluster_name
}

data "external" "cloudpilot_cli" {
  program = [
    "bash",
    "${path.module}/scripts/cloudpilot_cli_identity.sh",
    var.cluster_name,
    var.region,
    var.aws_source_profile == null ? "__CLOUDPILOT_EMPTY_PROFILE__" : var.aws_source_profile,
    var.aws_assume_role_arn,
    var.aws_assume_role_session_name,
  ]
}

locals {
  aws_provider_identity_matches_cloudpilot_cli  = data.aws_caller_identity.assumed.arn == data.external.cloudpilot_cli.result.assumed_arn
  cloudpilot_cli_can_describe_cluster           = try(data.external.cloudpilot_cli.result.cluster_arn, "") != ""
  cloudpilot_cli_can_get_token                  = try(data.external.cloudpilot_cli.result.token_expiration, "") != ""
  cloudpilot_cli_has_cluster_access_via_aws_cli = local.cloudpilot_cli_can_describe_cluster && local.cloudpilot_cli_can_get_token
}
