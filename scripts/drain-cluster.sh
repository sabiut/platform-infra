#!/usr/bin/env bash
# Run before destroying a region. The ALB (and its security groups and target groups) is
# created by the AWS Load Balancer Controller from the Ingress, not by Terraform. If the
# cluster is destroyed first, nothing deletes the ALB, and the VPC can't be destroyed
# because the ALB is still in it.
#
# Order: stop Argo CD re-creating things, delete the web app (Ingress -> ALB), wait until AWS
# shows no ALB for this cluster, then Terraform can destroy 40 -> 30 -> 20 -> 10.
#
#   scripts/drain-cluster.sh ap-southeast-2
set -euo pipefail
region=${1:?usage: drain-cluster.sh <region>}
env=${ENVIRONMENT:-prod}
cluster="$env-$region"
if ! aws eks describe-cluster --region "$region" --name "$cluster" >/dev/null 2>&1; then
  echo "No cluster $cluster: nothing to drain."
  exit 0
fi
aws eks update-kubeconfig --region "$region" --name "$cluster" --alias "$cluster" >/dev/null
k() { kubectl --context "$cluster" "$@"; }

echo "1/3 Stop the root app from re-creating what we delete"
k -n argocd patch application root --type merge -p '{"spec":{"syncPolicy":null}}' || true

echo "2/3 Delete the web app; the Ingress finalizer makes the controller delete the ALB"
for app in ingress frontend backend; do
  k -n argocd delete application "$app" --ignore-not-found --wait=true --timeout=5m
done

echo "3/3 Wait until AWS has no load balancer for $cluster"
for i in $(seq 1 60); do
  n=$(aws resourcegroupstaggingapi get-resources --region "$region" \
        --resource-type-filters elasticloadbalancing:loadbalancer \
        --tag-filters "Key=elbv2.k8s.aws/cluster,Values=$cluster" \
        --query 'length(ResourceTagMappingList)' --output text)
  [[ $n == 0 ]] && { echo "No load balancers left. Safe to destroy 40 -> 30 -> 20 -> 10."; exit 0; }
  sleep 10
done
echo "Load balancer still present after 10 minutes; check the EC2 console before destroying." >&2
exit 1
