# Onboard Existing Cluster

This example onboards an existing EKS cluster that has not yet been connected to CloudPilot AI. It is for the common local or CI flow where your source AWS credentials are an access key, a named AWS CLI profile, or OIDC credentials, and CloudPilot should assume a target IAM role before touching the cluster.

The AWS provider and the CloudPilot provider are configured separately. The AWS provider `assume_role` block only affects Terraform AWS data sources and resources. It does not pass credentials into the CloudPilot provider, so this example also sets `aws_assume_role` on the CloudPilot EKS module.

## GitHub Links

- Example directory: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/tree/main/examples/onboard-existing-cluster
- `main.tf`: https://github.com/cloudpilot-ai/terraform-cloudpilotai-eks/blob/main/examples/onboard-existing-cluster/main.tf

## What This Example Does

- Uses the Terraform AWS provider to assume a target role and read the existing EKS cluster.
- Uses the CloudPilot provider to assume the same target role for AWS CLI, kubeconfig, kubectl, and helm operations.
- Installs the CloudPilot AI agent and rebalance component.
- Keeps Workload Autoscaler disabled so this example focuses on EKS onboarding and node optimization.
- Disables workload uploading for the first smoke test.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- A CloudPilot AI API key -- see [Getting API Keys](https://docs.cloudpilot.ai/guide/getting_started/get_apikeys)
- An existing EKS cluster that is not already connected to CloudPilot AI
- A source AWS identity that can call `sts:AssumeRole` on the target role
- A target IAM role that can manage the EKS onboarding path and authenticate to Kubernetes

## Local Source Credentials

If your source credentials are an access key, put them in a named profile:

```bash
aws configure --profile cp-source
aws sts get-caller-identity --profile cp-source
```

The identity returned here is the source principal. It must be allowed by the target role trust policy, and it must have an IAM policy that permits `sts:AssumeRole` on that target role.

If the returned ARN is `arn:aws:iam::<account-id>:root`, this profile is using AWS account root user credentials. Do not use root credentials as `aws_source_profile`: root credentials cannot assume IAM roles and should not be used for everyday Terraform runs. Create an IAM user, use IAM Identity Center, or use an existing IAM role/federated identity, then configure `cp-source` with that non-root identity.

If you use environment credentials instead, leave `aws_source_profile = null`:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-west-2
aws sts get-caller-identity
```

## Target Role Trust

The target role trust policy must allow the source principal to assume it. For a local IAM user source, the trust relationship usually looks like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/local-terraform-user"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

For CI/OIDC, use your CI role as the trusted principal instead of a local IAM user.

Confirm the role can be assumed before running Terraform:

```bash
aws sts assume-role \
  --profile cp-source \
  --role-arn arn:aws:iam::123456789012:role/cloudpilot-onboard \
  --role-session-name cloudpilotai-onboard
```

The AWS CLI `assume-role` command requires `--role-arn` and `--role-session-name`; see the [AWS CLI STS assume-role reference](https://docs.aws.amazon.com/cli/latest/reference/sts/assume-role.html).

## Optional: Create A Target Role

If you do not already have a target role, create one from your source AWS identity. This example uses `cp-source` as the local access-key profile and `cloudpilot-onboard` as the target role name.

Set the values you will reuse:

```bash
export AWS_PROFILE=cp-source
export AWS_REGION=us-west-2
export CLUSTER_NAME=my-eks-cluster
export ROLE_NAME=cloudpilot-onboard
export ROLE_SESSION_NAME=cloudpilotai-onboard
export KUBECONFIG_PATH=/tmp/cloudpilot-onboard-kubeconfig

export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export SOURCE_PRINCIPAL_ARN=$(aws sts get-caller-identity --query Arn --output text)
export ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
```

If `SOURCE_PRINCIPAL_ARN` is `arn:aws:iam::${ACCOUNT_ID}:root`, stop and switch `cp-source` to an IAM user, IAM Identity Center, or an IAM role first. A target role trust policy that names the root principal means "the account can delegate access to its IAM identities"; it does not let root access keys assume the role directly.

If `SOURCE_PRINCIPAL_ARN` is an assumed-role ARN such as `arn:aws:sts::123456789012:assumed-role/my-ci-role/session`, trust the underlying IAM role ARN instead, for example `arn:aws:iam::123456789012:role/my-ci-role`.

If you are bootstrapping from a brand-new AWS account, use the root user only to create a non-root administrative identity, then stop using root access keys. One CLI bootstrap path is:

```bash
aws iam create-user --user-name cloudpilot-local-terraform

aws iam create-access-key \
  --user-name cloudpilot-local-terraform
```

Configure the returned access key as `cp-source`, then grant that IAM user the IAM and EKS permissions needed to create the target role and access entry. For a temporary lab account, an administrator-managed policy is the fastest bootstrap; for production, use your normal least-privilege admin process.

Create the role trust policy:

```bash
cat >/tmp/cloudpilot-onboard-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${SOURCE_PRINCIPAL_ARN}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

Create the role:

```bash
aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document file:///tmp/cloudpilot-onboard-trust-policy.json
```

The AWS CLI `create-role` command accepts the trust policy through `--assume-role-policy-document`; see the [AWS CLI IAM create-role reference](https://docs.aws.amazon.com/cli/latest/reference/iam/create-role.html).

Allow your source identity to assume the new role. If your source identity already has this permission from an existing group or policy, skip this step.

For a local IAM user source, attach an inline user policy:

```bash
export SOURCE_USER_NAME=$(basename "${SOURCE_PRINCIPAL_ARN}")

cat >/tmp/cloudpilot-onboard-source-assume-role-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "${ROLE_ARN}"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name "${SOURCE_USER_NAME}" \
  --policy-name CloudPilotOnboardAssumeRole \
  --policy-document file:///tmp/cloudpilot-onboard-source-assume-role-policy.json
```

If your source identity is an IAM role, attach the equivalent inline role policy with `aws iam put-role-policy --role-name <source-role-name> ...`.

Attach an initial target-role permission policy. This is intentionally a broad onboarding smoke-test policy for a non-production first run; replace it with a tighter policy once you know which CloudPilot features you are enabling.

```bash
cat >/tmp/cloudpilot-onboard-target-permissions.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSClusterReadAndAccessEntrySetup",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:ListAccessEntries",
        "eks:DescribeAccessEntry",
        "eks:CreateAccessEntry",
        "eks:DeleteAccessEntry",
        "eks:AssociateAccessPolicy",
        "eks:ListAccessPolicies",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:DescribeAddonVersions",
        "eks:ListNodegroups",
        "eks:DescribeNodegroup"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoscalingRestoreSmokeTest",
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:UpdateAutoScalingGroup"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2ReadForClusterDiscovery",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMReadAndPassRoleForInstall",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:CreateRole",
        "iam:TagRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:GetRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicies",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:CreatePolicyVersion",
        "iam:ListPolicyVersions",
        "iam:DeletePolicyVersion",
        "iam:PutRolePermissionsBoundary",
        "iam:DeleteRolePermissionsBoundary",
        "iam:DeleteRole",
        "iam:ListRoles",
        "iam:CreateInstanceProfile",
        "iam:TagInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:ListInstanceProfiles",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:CreateServiceLinkedRole",
        "iam:ListOpenIDConnectProviders",
        "iam:CreateOpenIDConnectProvider",
        "iam:SimulatePrincipalPolicy",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name CloudPilotOnboardSmokeTest \
  --policy-document file:///tmp/cloudpilot-onboard-target-permissions.json
```

Confirm the role works:

```bash
aws sts assume-role \
  --role-arn "${ROLE_ARN}" \
  --role-session-name "${ROLE_SESSION_NAME}"
```

Use `${ROLE_ARN}` as `aws_assume_role_arn` in `terraform.tfvars`.

## Confirm EKS And Kubernetes Access

First confirm the target role can read the EKS cluster. One direct way is to assume the role into temporary shell credentials and then call EKS:

```bash
read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN < <(
  aws sts assume-role \
    --profile "${AWS_PROFILE}" \
    --role-arn "${ROLE_ARN}" \
    --role-session-name "${ROLE_SESSION_NAME}" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text
)

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws sts get-caller-identity

aws eks describe-cluster \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}"
```

Then create a temporary kubeconfig using the already-assumed target-role credentials:

```bash
aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}" \
  --kubeconfig "${KUBECONFIG_PATH}"
```

Do not add `--role-arn "${ROLE_ARN}"` in this manual check while the shell already has target-role temporary credentials. Doing both makes the generated kubeconfig ask the target role to assume itself again, which fails with `AccessDenied`. For the flag behavior, see the [AWS CLI update-kubeconfig reference](https://docs.aws.amazon.com/cli/latest/reference/eks/update-kubeconfig.html).

Grant the target role Kubernetes access before running kubectl. The access entry must use the stable IAM role ARN in `${ROLE_ARN}`, not the temporary `arn:aws:sts::...:assumed-role/...` session ARN.

```bash
aws eks describe-access-entry \
  --region "${AWS_REGION}" \
  --cluster-name "${CLUSTER_NAME}" \
  --principal-arn "${ROLE_ARN}" >/dev/null 2>&1 || \
aws eks create-access-entry \
  --region "${AWS_REGION}" \
  --cluster-name "${CLUSTER_NAME}" \
  --principal-arn "${ROLE_ARN}" \
  --type STANDARD

aws eks associate-access-policy \
  --region "${AWS_REGION}" \
  --cluster-name "${CLUSTER_NAME}" \
  --principal-arn "${ROLE_ARN}" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

For EKS access entry details, see the [Amazon EKS access policy guide](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html). For older clusters that still use `aws-auth`, map the target role there instead.

Now verify Kubernetes authorization:

```bash
KUBECONFIG="${KUBECONFIG_PATH}" kubectl get nodes
KUBECONFIG="${KUBECONFIG_PATH}" kubectl auth can-i create namespace
KUBECONFIG="${KUBECONFIG_PATH}" kubectl auth can-i create deployment -n kube-system
```

When the checks are done, clear the temporary target-role credentials:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Usage

1. Create `terraform.tfvars`:

   ```hcl
   cloudpilot_api_key = "your-api-key"

   cluster_name = "my-eks-cluster"
   region       = "us-west-2"

   aws_source_profile          = "cp-source"
   aws_assume_role_arn         = "arn:aws:iam::123456789012:role/cloudpilot-onboard"
   aws_assume_role_session_name = "cloudpilotai-onboard"
   ```

   If you are using environment credentials instead of a local profile, set:

   ```hcl
   aws_source_profile = null
   ```

2. Initialize and validate:

   ```bash
   terraform init -backend=false
   terraform validate
   ```

3. Plan and apply:

   ```bash
   terraform plan
   terraform apply
   ```

## Provider Version Requirement

This example depends on `cloudpilot-ai/cloudpilotai` provider `>= 0.4.0`, because the module configuration uses `aws_assume_role`.

For local module checkout testing with `source = "../.."`, install the released provider from the registry with a normal `terraform init`. You only need `dev_overrides` if you are intentionally testing unpublished provider changes.
