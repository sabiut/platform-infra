#!/usr/bin/env bash
# Copy one region's 30-data outputs (database host, RDS secret, media bucket) into the
# gitops repo's backend values, ready to commit. These values only exist after Terraform
# applies, which is why they're a hand-off and not hard-coded.
#
#   scripts/gitops-handoff.sh ap-southeast-2 [path-to-gitops-repo]
set -euo pipefail
region=${1:?usage: gitops-handoff.sh <region> [gitops-repo]}
root=$(cd "$(dirname "$0")/.." && pwd)
gitops=${2:-$root/../gitops}
values=$gitops/envs/prod/$region/values/backend.yaml
[[ -f $values ]] || { echo "not found: $values" >&2; exit 1; }

"$root/scripts/tf.sh" init 30-data "$region" >/dev/null
out() { terraform -chdir="$root/stacks/30-data" output -raw "$1"; }
host=$(out db_endpoint); host=${host%:*}           # endpoint is host:port
secret=$(out db_master_secret_arn)
bucket=$(out media_bucket)

# Replace only the value on each key's line, keeping comments.
sed -i -E \
  -e "s|^(  host: )[^ #]+|\1$host|" \
  -e "s|^(  dbSecretName: )[^ #]+|\1$secret|" \
  -e "s|^(  bucket: )[^ #]+|\1$bucket|" \
  "$values"
echo "Updated $values:"
grep -E '^  (host|dbSecretName|bucket): ' "$values"
