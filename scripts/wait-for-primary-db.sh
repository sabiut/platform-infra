#!/usr/bin/env bash
# A read replica can only be created once its source database is available. apply.yml builds
# the regions in parallel, so the replica region's job runs this before its 30-data.
#
#   scripts/wait-for-primary-db.sh ap-southeast-2 [timeout-minutes]
set -euo pipefail
primary=${1:?usage: wait-for-primary-db.sh <primary-region> [timeout-minutes]}
timeout=${2:-60}
env=${ENVIRONMENT:-prod}
db="$env-$primary-webapp"
for ((i = 0; i < timeout * 2; i++)); do
  status=$(aws rds describe-db-instances --region "$primary" --db-instance-identifier "$db" \
             --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo missing)
  [[ $status == available ]] && { echo "$db is available."; exit 0; }
  echo "$db: $status, waiting..."
  sleep 30
done
echo "$db not available after $timeout minutes; apply 30-data in $primary first." >&2
exit 1
