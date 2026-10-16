# platform-infra

Terraform for the production EKS platform: two regional cells (Sydney `ap-southeast-2`,
London `eu-west-2`), each with its own VPC, EKS cluster, RDS database and Argo CD. Argo CD then
deploys everything inside the clusters from the `gitops` repo on GitLab.

Design and reasoning: `eks-gitops-platform/docs/design.html`.

## Layout

| Path | State key | Creates |
|---|---|---|
| `bootstrap/` | local, then moved to S3 | State bucket, GitHub + GitLab OIDC providers, `gha-plan`, `gha-apply`, `gitlab-<app>-push` roles |
| `global/` | `prod/global.tfstate` | ECR repos, replication to the other regions, Route 53 zone (once there's a domain) |
| `stacks/10-network/` | `prod/<region>/10-network.tfstate` | VPC over 3 AZs, public/private/database subnets, NAT per AZ, VPC endpoints |
| `stacks/20-eks/` | `prod/<region>/20-eks.tfstate` | EKS 1.37, managed node group, add-ons, access entries, Pod Identity roles for add-ons |
| `stacks/30-data/` | `prod/<region>/30-data.tfstate` | RDS PostgreSQL 17 Multi-AZ, media bucket, Django secret, backend Pod Identity |
| `stacks/40-argocd/` | `prod/<region>/40-argocd.tfstate` | Argo CD (HA), gitops repo credentials, the root Application |
| `envs/prod/` | | Settings per region, one tfvars file per stack |

Stacks read upstream outputs from S3 (`terraform_remote_state`), so apply them in order:
`global`, then per region `10 → 20 → 30 → 40`.

## Running

    scripts/tf.sh plan  20-eks ap-southeast-2
    scripts/tf.sh apply 20-eks ap-southeast-2
    make plan-only     # plan everything before anything exists (nothing is created)
    make validate

`make plan-only` uses throwaway local state and gives downstream stacks placeholder inputs
(`vpc-PLANONLY…`, a dummy certificate) instead of reading real state. It can't apply.

## First-time setup

1. `cd bootstrap && terraform apply` with your own AWS credentials. Then add a `backend "s3"`
   block pointing at the new bucket and run `terraform init -migrate-state`.
2. In the GitHub repo settings:
   - Variables: `GHA_PLAN_ROLE_ARN` and `GHA_APPLY_ROLE_ARN` (bootstrap outputs).
   - Environment `production` with a required reviewer.
   - Branch protection on `main`: pull requests only, `plan` must pass.
3. In each region, create the Secrets Manager secret `platform/gitops-repo` holding a GitLab
   deploy token with `read_repository`: `{"username": "...", "password": "..."}`.
4. Open a pull request. The plan appears as comments. Merge it, approve the `production`
   deployment, and the apply runs global, Sydney, then London.

## Pipelines

| Workflow | When | Role | Does |
|---|---|---|---|
| `plan.yml` | pull request | `gha-plan` (read-only) | fmt, tflint, trivy, plan per stack and region, PR comments |
| `apply.yml` | merge to `main` | `gha-plan`, then `gha-apply` after approval | plan all, wait for approval, apply in order |
| `drift.yml` | nightly | `gha-plan` | plan all, open an issue if anything changed outside Terraform |

No AWS keys are stored anywhere: GitHub gets short-lived credentials through OIDC, and the
apply role only trusts jobs in the approved `production` environment.

## Lab profile

The comments in `envs/prod/*/*.tfvars` show cheaper values: one NAT gateway, `t3.medium`
nodes, single-AZ `db.t4g.micro`. Use them for practice runs, and destroy afterwards.

## Destroy

Reverse order, per region: `40 → 30 → 20 → 10`, then `global`. Set
`db_deletion_protection = false` and apply `30-data` first, or RDS refuses to be deleted
(a final snapshot is still taken).
