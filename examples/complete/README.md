# Complete Example

This example demonstrates a full CloudPilot AI deployment with both Node Autoscaler and Workload Autoscaler, including custom nodeclasses, nodepools, recommendation policies, autoscaling policies, and proactive optimization filters.

## What This Example Does

- Installs the CloudPilot AI Node Autoscaler with rebalance enabled
- Configures a custom NodeClass (`cloudpilot`) with 30 GiB system disk
- Configures a NodePool (`cloudpilot-general`) with spot and on-demand capacity
- Defines a workload for optimization
- Deploys the Workload Autoscaler with:
  - Two recommendation policies (`balanced` and `cost-savings`)
  - Two autoscaling policies (`default-ap` with inplace mode and `readonly` with off mode)
  - Proactive optimization enabled for `default` and `my-namespace` namespaces
  - Proactive optimization disabled for `kube-system` namespace

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
   enable_rebalance    = true
   ```

2. Apply the configuration:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Customization

- Modify `recommendation_policies` and `autoscaling_policies` in `main.tf` to tune optimization behavior
- Adjust `nodeclasses` and `nodepools` for different instance types, architectures, or capacity strategies
- Update `enable_proactive` / `disable_proactive` to control which namespaces get proactive optimization
