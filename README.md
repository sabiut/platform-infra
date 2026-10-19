# platform-infra

Terraform for the production EKS platform: two regional cells (Sydney `ap-southeast-2`,
London `eu-west-2`), each with its own VPC, EKS cluster, RDS database and Argo CD. Argo CD then
deploys everything inside the clusters from the `gitops` repo on GitLab.

Design and reasoning: `eks-gitops-platform/docs/design.html`.

## Layout

| Path | State key | Creates |
|---|---|---|
| `foundation/` | local (`foundation/terraform.tfstate`, gitignored) | State bucket, GitHub + GitLab OIDC providers, `gha-plan`, `gha-apply`, `gitlab-<app>-push` roles, ECR repos in both regions with replication, Route 53 zone (once there's a domain) |
| `stacks/10-network/` | `prod/<region>/10-network.tfstate` | VPC over 3 AZs, public/private/database subnets, NAT per AZ, VPC endpoints |
| `stacks/20-eks/` | `prod/<region>/20-eks.tfstate` | EKS 1.37, managed node group, add-ons, access entries, Pod Identity roles for add-ons |
| `stacks/30-data/` | `prod/<region>/30-data.tfstate` | RDS PostgreSQL 17 Multi-AZ, media bucket, Django secret, backend Pod Identity |
| `stacks/40-argocd/` | `prod/<region>/40-argocd.tfstate` | Argo CD (HA), gitops repo credentials, the root Application |
| `envs/prod/` | | Settings per region, one tfvars file per stack |

Stacks read upstream outputs from S3 (`terraform_remote_state`), so apply them in order:
the foundation, then per region `10 → 20 → 30 → 40`.

## Two lifecycles

| | Foundation | Regions |
|---|---|---|
| What | state bucket, CI roles, ECR | VPC, EKS, RDS, Argo CD per region |
| Cost while up | cents a month | about US$1 an hour for both regions |
| Run from | your laptop: `make foundation-up` / `make foundation-down` | GitHub Actions: `apply` / `destroy` |
| Why there | it creates the bucket and the roles CI signs in with, so CI can't create it | everything goes through review and the `production` approval |

Bring the foundation up when you start working on the project and take it down when you're
done. `foundation-down` refuses while any region state in the bucket still has resources, so
destroy the regions first. Role names and the bucket name are fixed, so the GitHub variables
and GitLab CI settings stay valid across rebuilds.

## Running

    scripts/tf.sh plan  20-eks ap-southeast-2
    scripts/tf.sh apply 20-eks ap-southeast-2
    make plan-only     # plan everything before anything exists (nothing is created)
    make validate

`make plan-only` uses throwaway local state and gives downstream stacks placeholder inputs
(`vpc-PLANONLY…`, a dummy certificate) instead of reading real state. It can't apply.

## First-time setup

1. `make foundation-up` with your own AWS credentials.
2. In the GitHub repo settings:
   - Variables: `GHA_PLAN_ROLE_ARN` and `GHA_APPLY_ROLE_ARN` (foundation outputs).
   - Environment `production` with a required reviewer.
   - Branch protection on `main`: pull requests only, `plan` must pass.
3. In each region, create the Secrets Manager secret `platform/gitops-repo` holding a GitLab
   deploy token with `read_repository`: `{"username": "...", "password": "..."}`.
4. For the Argo CD UI over Tailscale: in each region, create the Secrets Manager secret
   `prod/platform/tailscale-operator` holding a Tailscale OAuth client:
   `{"client_id": "...", "client_secret": "..."}`. The tailnet setup is in the gitops README.
5. Open a pull request. The plan appears as comments. Merge it, approve the `production`
   deployment, and the apply builds Sydney and London in parallel.

## Pipelines

| Workflow | When | Role | Does |
|---|---|---|---|
| `plan.yml` | pull request | `gha-plan` (read-only) | fmt, tflint, trivy, plan per stack and region, PR comments |
| `apply.yml` | merge to `main`, or Run workflow | `gha-plan`, then `gha-apply` after approval | plan all; approve; both regions in parallel |
| `destroy.yml` | Run workflow only (type `destroy`) | `gha-apply` after approval | drain the ALB, then destroy 40 -> 10 per region |
| `drift.yml` | nightly | `gha-plan` | plan all, open an issue if anything changed outside Terraform |

No AWS keys are stored anywhere: GitHub gets short-lived credentials through OIDC, and the
apply role only trusts jobs in the approved `production` environment.

## Destroy

Per region: `scripts/drain-cluster.sh <region>` (removes the ALB, which Terraform doesn't
own), then `scripts/tf.sh destroy` for `40 → 30 → 20 → 10`. Then, when finished with the
project, `make foundation-down`. With the
production values, set `db_deletion_protection = false` and apply `30-data` first, or RDS
refuses to be deleted (a final snapshot is still taken).
