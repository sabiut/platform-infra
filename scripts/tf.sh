#!/usr/bin/env bash
# Run Terraform for one stack in one region, the same way locally and in CI.
#
#   scripts/tf.sh plan  20-eks ap-southeast-2       real remote state in S3
#   scripts/tf.sh apply 20-eks ap-southeast-2
#   PLAN_ONLY=1 scripts/tf.sh plan 30-data eu-west-2
#   scripts/tf.sh destroy 20-eks ap-southeast-2     asks for confirmation
#
# PLAN_ONLY=1 plans before anything exists: local throwaway state, and downstream stacks get
# placeholder inputs instead of reading other stacks' state. It can't apply.
set -euo pipefail

action=${1:?usage: tf.sh <init|plan|apply|destroy> <stack> [region]}
stack=${2:?stack: 10-network, 20-eks, 30-data, 40-argocd}
region=${3:-}
env=${ENVIRONMENT:-prod}
plan_only=${PLAN_ONLY:-0}

root=$(cd "$(dirname "$0")/.." && pwd)
# The foundation (state bucket, CI roles, ECR) is separate: scripts/foundation.sh.
dir=$root/stacks/$stack
: "${region:?region is required for $stack}"
varfile=$root/envs/$env/$region/$stack.tfvars
key="$env/$region/$stack.tfstate"
[[ -d $dir ]] || { echo "no such stack: $stack" >&2; exit 1; }

state_region=ap-southeast-2
account=$(aws sts get-caller-identity --query Account --output text)
bucket="eks-gitops-tfstate-$account"

args=(-var-file="$varfile")

cd "$dir"
if [[ $plan_only == 1 ]]; then
  [[ $action == plan ]] || { echo "PLAN_ONLY supports plan only" >&2; exit 1; }
  mkdir -p "$root/.planonly"
  cat > backend_override.tf <<HCL
terraform {
  backend "local" { path = "$root/.planonly/${key//\//-}" }
}
HCL
  terraform init -input=false -reconfigure >/dev/null
else
  rm -f backend_override.tf
  terraform init -input=false -reconfigure \
    -backend-config="bucket=$bucket" \
    -backend-config="key=$key" \
    -backend-config="region=$state_region" \
    -backend-config="use_lockfile=true" \
    -backend-config="encrypt=true"
  # Downstream stacks read upstream outputs from the same bucket.
  [[ $stack =~ ^(20|30|40)- ]] && args+=(-var="state_bucket=$bucket")
fi

# A downstream stack can't be planned before its upstream exists (nothing to read). Say so
# and stop cleanly instead of failing, so pipeline plans stay green before the first build.
case $stack in
  20-eks)    upstream="10-network" ;;
  30-data)   upstream="10-network 20-eks" ;;
  40-argocd) upstream="20-eks" ;;
  *)         upstream="" ;;
esac
if [[ $plan_only != 1 && $action == plan ]]; then
  for u in $upstream; do
    if ! aws s3api head-object --bucket "$bucket" --key "$env/$region/$u.tfstate" >/dev/null 2>&1; then
      echo "Skipped: $stack in $region needs $u, which hasn't been applied in $region yet."
      exit 0
    fi
  done
fi

case $action in
  init)  ;;
  plan)  terraform plan -input=false -out="$dir/tfplan" "${args[@]}" ;;
  apply) # In CI the approval is the GitHub "production" environment, so don't prompt.
         [[ ${CI:-} == true ]] && args+=(-auto-approve)
         terraform apply -input=false "${args[@]}" ;;
  destroy) [[ ${CI:-} == true ]] && args+=(-auto-approve)
           terraform destroy -input=false "${args[@]}" ;;
  *)     echo "unknown action: $action" >&2; exit 1 ;;
esac
