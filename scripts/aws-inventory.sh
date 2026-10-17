#!/usr/bin/env bash
# What this project has in AWS right now. After destroying the regions, only the foundation
# rows (state bucket, OIDC, CI roles, ECR) show anything; after foundation.sh down, nothing.
set -uo pipefail
acct=$(aws sts get-caller-identity --query Account --output text)
echo "State bucket:   $(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `eks-gitops`)].Name' --output text)"
echo "OIDC providers: $(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text | sed "s|arn:aws:iam::$acct:oidc-provider/||g")"
echo "CI roles:       $(aws iam list-roles --query 'Roles[?starts_with(RoleName, `gha-`) || starts_with(RoleName, `gitlab-`)].RoleName' --output text)"
for r in ${REGIONS:-ap-southeast-2 eu-west-2}; do
  echo "[$r]"
  echo "  ECR:          $(aws ecr describe-repositories --region "$r" --query 'repositories[].repositoryName' --output text 2>/dev/null)"
  echo "  EKS:          $(aws eks list-clusters --region "$r" --query clusters --output text)"
  echo "  RDS:          $(aws rds describe-db-instances --region "$r" --query 'DBInstances[].DBInstanceIdentifier' --output text)"
  echo "  NAT gateways: $(aws ec2 describe-nat-gateways --region "$r" --filter Name=state,Values=available,pending,deleting --query 'length(NatGateways)')"
  echo "  Project VPCs: $(aws ec2 describe-vpcs --region "$r" --filters Name=tag:project,Values=eks-gitops-platform --query 'length(Vpcs)')"
  echo "  Load bal.:    $(aws elbv2 describe-load-balancers --region "$r" --query 'length(LoadBalancers)')"
  echo "  EBS volumes:  $(aws ec2 describe-volumes --region "$r" --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name --query 'length(Volumes)') created by Kubernetes"
  echo "  Elastic IPs:  $(aws ec2 describe-addresses --region "$r" --query 'length(Addresses)')"
done
