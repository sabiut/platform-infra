#!/usr/bin/env bash
# Run Terraform for one stack in one region, the same way locally and in CI.
#
#   scripts/tf.sh plan  20-eks ap-southeast-2       real remote state in S3
#   scripts/tf.sh apply 20-eks ap-southeast-2
#   scripts/tf.sh plan  global
#   PLAN_ONLY=1 scripts/tf.sh plan 30-data eu-west-2
#
# PLAN_ONLY=1 plans before anything exists: local throwaway state, and downstream stacks get
# placeholder inputs instead of reading other stacks' state. It can't apply.
set -euo pipefail

action=${1:?usage: tf.sh <init|plan|apply> <stack> [region]}
stack=${2:?stack: bootstrap, global, 10-network, 20-eks, 30-data, 40-argocd}
region=${3:-}
env=${ENVIRONMENT:-prod}
plan_only=${PLAN_ONLY:-0}

root=$(cd "$(dirname "$0")/.." && pwd)
case $stack in
  bootstrap) dir=$root/bootstrap; varfile=""; key="" ;;
  global)    dir=$root/global; varfile=$root/envs/$env/global.tfvars; key="$env/global.tfstate" ;;
  *)         dir=$root/stacks/$stack
             : "${region:?region is required for $stack}"
             varfile=$root/envs/$env/$region/$stack.tfvars
             key="$env/$region/$stack.tfstate" ;;
esac
[[ -d $dir ]] || { echo "no such stack: $stack" >&2; exit 1; }

state_region=ap-southeast-2
account=$(aws sts get-caller-identity --query Account --output text)
bucket="eks-gitops-tfstate-$account"

args=()
[[ -n $varfile ]] && args+=(-var-file="$varfile")

cd "$dir"
if [[ $stack == bootstrap ]]; then
  terraform init -input=false
elif [[ $plan_only == 1 ]]; then
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

case $action in
  init)  ;;
  plan)  terraform plan -input=false -out="$dir/tfplan" "${args[@]}" ;;
  apply) # In CI the approval is the GitHub "production" environment, so don't prompt.
         [[ ${CI:-} == true ]] && args+=(-auto-approve)
         terraform apply -input=false "${args[@]}" ;;
  *)     echo "unknown action: $action" >&2; exit 1 ;;
esac
