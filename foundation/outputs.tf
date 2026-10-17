output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

# Role names are fixed, so these ARNs are the same after every rebuild: the GitHub variables
# and GitLab CI settings never need changing.
output "gha_plan_role_arn" {
  value = aws_iam_role.gha_plan.arn
}

output "gha_apply_role_arn" {
  value = aws_iam_role.gha_apply.arn
}

output "gitlab_push_role_arns" {
  value = { for k, r in aws_iam_role.gitlab_push : k => r.arn }
}

output "ecr_repository_urls" {
  value = {
    primary = { for k, r in aws_ecr_repository.app : k => r.repository_url }
    replica = { for k, r in aws_ecr_repository.replica : k => r.repository_url }
  }
}

output "route53_name_servers" {
  description = "Set these at your domain registrar"
  value       = one(aws_route53_zone.public[*].name_servers)
}
