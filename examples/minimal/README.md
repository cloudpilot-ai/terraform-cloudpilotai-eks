# Minimal Example

This example demonstrates the simplest setup: installing the CloudPilot AI agent on an existing EKS cluster in read-only mode. The Workload Autoscaler is disabled.

## What This Example Does

- Installs the CloudPilot AI Node Autoscaler agent in agent-only mode (`only_install_agent = true`)
- Skips Workload Autoscaler deployment (`enable_workload_autoscaler = false`)
- No rebalance, no custom nodeclasses or nodepools

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with EKS permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster operations
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)

## Usage

1. Create a `terraform.tfvars` file:

   ```hcl
   cloudpilot_api_key = "your-api-key"
   cluster_name       = "my-eks-cluster"
   region             = "us-west-2"
   ```

2. Apply the configuration:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Next Steps

- To enable rebalance and node optimization, see the [node-autoscaler-only](../node-autoscaler-only/) example
- To add Workload Autoscaler with policies, see the [complete](../complete/) example
