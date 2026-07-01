# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Terraform module that wraps the [`cloudpilotai`](https://registry.terraform.io/providers/cloudpilot-ai/cloudpilotai/latest/docs)
provider to deploy CloudPilot AI's Node Autoscaler and Workload Autoscaler onto an
existing Amazon EKS cluster. It is a **published, reusable module** — consumers
reference it by Git/registry source, so the public interface (variables, outputs)
is a contract. Avoid breaking renames without a deprecation path.

## Repository layout

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` — the module itself (repo root).
- `examples/{minimal,node-autoscaler-only,complete}/` — runnable usage examples; keep
  them working whenever the module interface changes.
- Terraform `>= 1.0`; provider `cloudpilot-ai/cloudpilotai >= 0.1`.

## Conventions

- snake_case for resources, variables, and outputs.
- Every `variable` needs a `description` and `type` (add a `validation` block where the
  value is constrained); every `output` needs a `description`.
- Match the existing `####` banner-comment section style in the `.tf` files.
- When you add, rename, or remove a variable or output, update `README.md` **and** every
  affected `examples/*` in the same change.

## Secrets — never commit

- The provider needs a CloudPilot AI `api_key` plus AWS credentials. **Never** hard-code
  them in `.tf`, `.tfvars`, or examples — they come from `var.cloudpilotai_api_key`, the
  AWS profile, or the environment at runtime.
- `output "kubeconfig"` returns live cluster credentials — treat it as sensitive; do not
  print, log, or paste it.

## Safe commands (read-only, auto-allowed)

`terraform fmt`, `terraform validate`, `terraform init`, `terraform providers`,
`terraform output`, `terraform show`, and `tflint` / `checkov` when installed.

## Never do these

- **Never** run `terraform apply`, `terraform destroy`, `terraform import`, or any
  `terraform state rm` / `state push` / `force-unlock`. This module manages a **live EKS
  cluster** — produce diffs only; deployment goes through the PR + CI pipeline.
- **Never** use `-target` or `-exclude` to scope a partial apply/destroy from the agent
  shell. Scoping deployments is the pipeline's job.
- These rules are enforced in `.claude/settings.json`; do not work around them.

## Definition of done

`terraform fmt` is clean and `terraform validate` passes for the root module and every
`examples/*`. Commits are DCO-signed (`git commit -s`) and a PR ships as a single commit,
English-only.
