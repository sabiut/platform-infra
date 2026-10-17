#!/usr/bin/env bash
# The long-lived foundation: state bucket, CI roles (GitHub + GitLab OIDC) and ECR in both
# regions. Runs from a laptop with your own AWS credentials, never from CI (CI's roles are
# part of it).
#
#   scripts/foundation.sh plan
#   scripts/foundation.sh up      create or update it
#   scripts/foundation.sh down    destroy it; refuses while any region stack still has resources
#
# Bring it up before working on the project, take it down when finished. The role ARNs and
# bucket name are derived from fixed names, so nothing in GitHub or GitLab needs changing
# after a rebuild.
set -euo pipefail

action=${1:?usage: foundation.sh <plan|up|down>}
cd "$(dirname "$0")/../foundation"
terraform init -input=false >/dev/null

# The region stacks keep their state in the bucket. Deleting it while they still own
# resources would leave EKS, RDS and NAT gateways running with no state to destroy them.
regions_empty() {
  local bucket key n busy=0
  bucket="eks-gitops-tfstate-$(aws sts get-caller-identity --query Account --output text)"
  aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1 || return 0
  for key in $(aws s3api list-objects-v2 --bucket "$bucket" \
                 --query "Contents[?ends_with(Key, '.tfstate')].Key" --output text); do
    [[ $key == None ]] && continue
    n=$(aws s3 cp "s3://$bucket/$key" - | jq '[.resources[]? | select(.mode == "managed")] | length')
    if [[ $n -gt 0 ]]; then echo "  $key: $n resource(s)"; busy=1; fi
  done
  return $busy
}

case $action in
  plan) terraform plan -input=false ;;
  up)   terraform apply -input=false ;;
  down)
    echo "Checking that the region stacks are destroyed..."
    if ! regions_empty; then
      echo "Destroy the regions first (GitHub Actions > destroy), then run this again." >&2
      exit 1
    fi
    terraform destroy -input=false ;;
  *) echo "unknown action: $action" >&2; exit 1 ;;
esac
