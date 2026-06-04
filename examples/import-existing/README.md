# Import Existing Cluster Example

This example migrates an EKS cluster that is **already registered with CloudPilot AI** into the `cloudpilot-ai/eks/cloudpilotai` module in two phases:

1. Use Terraform's `import` blocks plus `terraform plan -generate-config-out=generated.tf` to discover the current provider resource configuration.
2. Use the bundled migration script to convert `generated.tf` into a module-based `main.tf`, then import the existing resources directly into `module.cloudpilotai_eks.*`.

This follows the discovery flow from [`terraform-provider-cloudpilotai/examples/eks/5_import_test`](https://github.com/cloudpilot-ai/terraform-provider-cloudpilotai/blob/main/examples/eks/5_import_test/README.md), but stops before applying the raw provider resources. The generated provider config still needs operational fields like `kubeconfig`, so this example converts the discovered config into the module form first and only then imports state into the module addresses.

The conversion script is intentionally scoped to the exact `generated.tf` format emitted by Terraform. It is **not** a generic HCL refactoring tool. Run it against a fresh `generated.tf` before manual edits; if you hand-edit the provider resource file first, regenerate it instead of expecting the script to understand arbitrary HCL.

The module covers the AWS/EKS fields that the CloudPilot AI frontend explicitly edits today. For Karpenter CRD fields outside this typed surface, use `origin_nodeclass_json` or `origin_nodepool_json` on the corresponding object.

## GitHub Links

- Example directory: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/tree/main/examples/import-existing
- Bootstrap import file: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/blob/main/examples/import-existing/bootstrap_import.tf
- Migration script: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/blob/main/examples/import-existing/scripts/generated_to_module.py

## What This Example Does

- Uses `terraform plan -generate-config-out=generated.tf` to discover the current `cloudpilotai_eks_cluster` and `cloudpilotai_workload_autoscaler` configuration
- Converts the generated provider resources into a `module "cloudpilotai_eks"` block automatically
- Writes a helper import script so you can import the real resources into `module.cloudpilotai_eks.cloudpilotai_eks_cluster.this` and `module.cloudpilotai_eks.cloudpilotai_workload_autoscaler.this[0]`

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Python 3](https://www.python.org/downloads/) for the migration script
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with EKS permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster operations
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)
- The target cluster must already be connected to CloudPilot AI

## Files in This Example

- [main.tf](main.tf): provider setup shared by both phases
- [bootstrap_import.tf](bootstrap_import.tf): temporary import blocks used only to generate `generated.tf`
- [variables.tf](variables.tf): inputs for the bootstrap step and the final module config
- [scripts/generated_to_module.py](scripts/generated_to_module.py): converts `generated.tf` into a module block and helper import script

## Step 1: Create `terraform.tfvars`

Start from the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Fill in:

- `cloudpilot_api_key`
- `cluster_id`
- optionally `aws_profile`

Important:

- `cluster_id` is used by the bootstrap import blocks and later by the helper import script
- `aws_profile` is optional; if omitted, the default AWS profile or environment credentials are used

## Step 2: Initialize Terraform

```bash
terraform init
```

## Step 3: Generate `generated.tf`

Run:

```bash
terraform plan -generate-config-out=generated.tf
```

This reads the existing CloudPilot AI configuration from the API and writes provider resource blocks into `generated.tf`.

If the cluster does **not** have the Workload Autoscaler installed:

- comment out the `cloudpilotai_workload_autoscaler` import block in [bootstrap_import.tf](bootstrap_import.tf)
- rerun the command

## Step 4: Review the Generated Provider Config

Open `generated.tf` and check that it contains the resources you expect:

- `resource "cloudpilotai_eks_cluster" "imported"`
- optionally `resource "cloudpilotai_workload_autoscaler" "imported"`

This file is still in the raw provider resource format. Do **not** keep it as your final module configuration.

## Step 5: Convert `generated.tf` Into Module Configuration

Run the migration script:

```bash
python3 scripts/generated_to_module.py --input generated.tf
```

By default it writes:

- `module.generated.tf`
- `import-module.sh`

What the script does:

- converts the discovered provider resource config into `module "cloudpilotai_eks" { source = "cloudpilot-ai/eks/cloudpilotai" ... }`
- preserves `cloudpilotai_eks_cluster.cluster_setting` when the generated config already uses the nested form, and folds legacy standalone `cloudpilotai_cluster_setting` blocks into the same module input
- maps Workload Autoscaler settings into module inputs like `wa_storage_class` and `wa_enable_node_agent`
- normalizes provider defaults like `false`, `0`, and `""` where Terraform generated `null`
- keeps `aws_profile` wired to `var.aws_profile`
- intentionally omits `kubeconfig` so the provider can derive it from `cluster_name + region + aws_profile`

## Manual Validation Required

Some inputs are not reliably recoverable from the CloudPilot API and must be checked after conversion:

- `aws_profile`
  This is purely local execution context. The generated module config keeps it as `var.aws_profile`, but only you know which profile should be used in your environment.
- `custom_node_role`
  The service may expose nodeclass roles, but that is not the same contract as the top-level module/provider `custom_node_role` input. If your original setup used a custom node IAM role to grant controller `PassNodeIAMRole`, verify and set this field explicitly.

Treat these as required post-conversion checks before you import into the module addresses.

If you are testing the local checkout of this module instead of the published module, override the source explicitly:

```bash
python3 scripts/generated_to_module.py --input generated.tf --module-source ../..
```

## Step 6: Switch the Example From Bootstrap Mode to Module Mode

Delete the discovery files:

```bash
rm -f bootstrap_import.tf generated.tf
```

Then rename the generated module config:

```bash
mv module.generated.tf main.module.tf
```

At this point the Terraform configuration should contain:

- provider setup in `main.tf`
- variables in `variables.tf`
- the module call in `main.module.tf`

It should **not** contain the bootstrap import blocks or the raw provider resources anymore.

Before moving on, open `main.module.tf` and explicitly verify:

- `aws_profile`
- `custom_node_role`

## Step 7: Import the Existing Resources Into the Module Addresses

Run the helper script generated in Step 5:

```bash
./import-module.sh
```

It imports into:

- `module.cloudpilotai_eks.cloudpilotai_eks_cluster.this`
- `module.cloudpilotai_eks.cloudpilotai_workload_autoscaler.this[0]` when Workload Autoscaler exists

## Step 8: Verify the Migration

Run:

```bash
terraform plan
```

Expected result:

- You may see a small number of **operational-only** updates on the first module plan, such as:
  - `aws_profile`
  - `kubeconfig = (known after apply)`
  - provider defaults like `only_install_agent = false`, `skip_restore = false`, `restore_node_number = 0`
  - Workload Autoscaler operational fields like `wa_enable_node_agent = true`, `wa_storage_class = ""`, and `kubeconfig = (known after apply)`
- You should **not** see unexpected creates, deletes, or policy/nodepool/nodeclass rewrites

If Terraform still shows drift:

- If the drift is only the operational fields listed above, review it and apply once to normalize state for future runs.
- If the drift includes nodeclasses, nodepools, workloads, recommendation policies, or autoscaling policies being created, deleted, or heavily rewritten, stop and compare `main.module.tf` with the original `generated.tf` before applying.

## Step 9: Start Managing the Cluster Through the Module

Once `terraform plan` is clean, the migration is complete. Future updates should be made by editing the module inputs in `main.module.tf` and `terraform.tfvars`.

## Notes

- This example uses `generated.tf` only as a discovery artifact
- The actual Terraform state import happens **after** the module configuration exists
- This avoids the provider resource `apply` failure path where imported Workload Autoscaler resources still require operational fields like `kubeconfig`

## Next Steps

- If you want a lighter agent-only setup instead of a full migration, see the [minimal](../minimal/) example
- If you are starting from scratch instead of importing, see the [node-autoscaler-only](../node-autoscaler-only/) and [complete](../complete/) examples
