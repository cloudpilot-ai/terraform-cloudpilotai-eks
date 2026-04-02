# Node Autoscaler Only Example

This example deploys only the CloudPilot AI Node Autoscaler with custom NodeClass and NodePool configurations. The Workload Autoscaler is not deployed.

## What This Example Does

- Installs the CloudPilot AI Node Autoscaler with optimization enabled
- Configures a custom NodeClass (`cloudpilot`) with default settings
- Configures a NodePool (`cloudpilot-general`) with:
  - Both spot and on-demand capacity types
  - AMD64 architecture
  - Max 17 vCPUs and 32 GiB memory per node
  - 2-node disruption limit with 60-minute delay
- Rebalance is enabled by default (configurable via `enable_rebalance` variable)
- Workload Autoscaler is disabled

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with EKS permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster operations
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)

## Usage

1. Create a `terraform.tfvars` file:

   ```hcl
   cloudpilot_api_key  = "your-api-key"
   cluster_name        = "my-eks-cluster"
   region              = "us-west-2"
   restore_node_number = 3
   ```

2. Apply the configuration:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Customization

- Modify `nodeclasses` and `nodepools` in `main.tf` to change instance types, capacity strategies, or disruption behavior
- Add additional nodepools for GPU workloads by setting `enable_gpu = true`
- To also deploy the Workload Autoscaler, see the [complete](../complete/) example
