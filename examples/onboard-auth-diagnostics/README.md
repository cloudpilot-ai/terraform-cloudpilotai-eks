# Onboard Auth Diagnostics

This example is a preflight companion to [Onboard Existing Cluster](../onboard-existing-cluster/). It keeps the same AWS auth inputs and target-cluster shape, but it stops short of installing CloudPilot. Instead, it compares:

- the identity seen by the Terraform AWS provider after `assume_role`
- the identity seen by a CloudPilot-style AWS CLI path that mirrors `cloudpilotai_eks_cluster`

Use it when you want to answer: "If I run `terraform apply` in this environment, do the AWS provider path and the CloudPilot EKS path actually end up with the same AWS identity?"

## GitHub Links

- Example directory: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/tree/main/examples/onboard-auth-diagnostics
- Base example: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/tree/main/examples/onboard-existing-cluster

## What This Example Does

- Uses the Terraform AWS provider to assume the target role and read the existing EKS cluster
- Uses a small helper script to reproduce the CloudPilot provider's AWS CLI behavior:
  - optional `--profile` for the source credential
  - `aws sts assume-role`
  - `aws sts get-caller-identity`
  - `aws eks describe-cluster`
  - `aws eks get-token`
- Outputs both resulting identity ARNs side by side
- Flags whether the two resulting identities match

## Why This Example Exists

The Terraform AWS provider and the CloudPilot provider are configured separately. A successful `provider "aws"` read does not prove that `cloudpilotai_eks_cluster` will use the same source credential chain. The CloudPilot provider shells out to the AWS CLI for its EKS path, so this example validates that exact style of execution before you run the real onboarding example.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An existing EKS cluster
- A source AWS identity that can call `sts:AssumeRole` on the target role
- A target IAM role that can read the EKS cluster

## Usage

1. Copy the example vars file and edit it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

The file starts with:

```hcl
cluster_name = "my-eks-cluster"
region       = "us-west-2"

# Set this to a named local AWS CLI profile when your source credentials live
# in ~/.aws/credentials or ~/.aws/config.
aws_source_profile = "cp-source"

aws_assume_role_arn          = "arn:aws:iam::123456789012:role/cloudpilot-onboard"
aws_assume_role_session_name = "cloudpilotai-onboard"
```

If you want Terraform and the CloudPilot-style CLI path to use the environment's default AWS credential chain directly, set `aws_source_profile = null`:

```hcl
cluster_name = "my-eks-cluster"
region       = "us-west-2"

aws_source_profile = null

aws_assume_role_arn          = "arn:aws:iam::123456789012:role/cloudpilot-onboard"
aws_assume_role_session_name = "cloudpilotai-onboard"
```

2. Run the example:

```bash
terraform init
terraform apply
```

3. Inspect the outputs:

- `aws_provider_identity_arn`
- `cloudpilot_cli_source_identity_arn`
- `cloudpilot_cli_assumed_identity_arn`
- `cloudpilot_cli_can_describe_cluster`
- `cloudpilot_cli_token_expiration`
- `cloudpilot_cli_can_get_token`
- `cloudpilot_cli_has_cluster_access_via_aws_cli`
- `aws_provider_identity_matches_cloudpilot_cli`

If the `external` data source fails, Terraform will now print a stage-specific diagnostic that tells you whether the failure happened while resolving the source credential, calling `sts assume-role`, validating the temporary assumed-role credentials, or reading the EKS cluster. The diagnostic also includes `aws configure list` output and non-secret AWS environment hints.
It also checks whether the assumed role can run `aws eks get-token` for the target cluster, which is the closest AWS-CLI-only preflight for the later kubeconfig exec-auth path.
`cloudpilot_cli_source_mode` tells you whether the CloudPilot-style path used an explicit profile, an ambient `AWS_PROFILE`, ambient environment credentials, ambient web identity, or the default AWS credential chain.
Internally this example uses a non-empty placeholder when `aws_source_profile = null`, because the Terraform `external` data source can collapse empty-string program arguments.

## How To Interpret The Result

- If `aws_provider_identity_matches_cloudpilot_cli = true`, the AWS provider path and the CloudPilot-style AWS CLI path landed on the same assumed identity in this environment.
- If `cloudpilot_cli_has_cluster_access_via_aws_cli = true`, then after `sts assume-role` the CloudPilot-style AWS CLI path passes the AWS-side EKS preflight: it can both describe the target EKS cluster and mint an EKS auth token for it.
- If `cloudpilot_cli_token_expiration` is populated, the assumed role could also mint an EKS auth token for this cluster through AWS CLI.
- If it is `false`, your Terraform AWS provider auth and your CloudPilot EKS auth are split. The usual causes are:
  - `provider "aws"` has its own `profile` or `assume_role` behavior that the CloudPilot module did not mirror
  - the shell environment seen by Terraform has different ambient credentials than you expected
  - the source profile or source environment can read the cluster through the AWS provider, but the CloudPilot-style `aws sts assume-role` call is actually using a different starting identity

The current checks do confirm these AWS-side facts:

- `aws eks describe-cluster` succeeded for the specified cluster, so the assumed role had EKS `DescribeCluster` access for that step.
- `aws eks get-token` succeeded for the specified cluster, so the assumed role could mint an EKS authentication token through the same AWS CLI path that the generated kubeconfig later depends on.

The current checks do not fully prove these cluster-side facts:

- that the Kubernetes API server will accept a live HTTPS request made with that token
- that the role has the expected Kubernetes RBAC or EKS access-entry permissions once the request reaches the cluster

Once this example shows the identities you expect, switch to [Onboard Existing Cluster](../onboard-existing-cluster/) and use the same values there.
