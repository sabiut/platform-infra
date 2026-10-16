output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "gha_plan_role_arn" {
  value = aws_iam_role.gha_plan.arn
}

output "gha_apply_role_arn" {
  value = aws_iam_role.gha_apply.arn
}

output "gitlab_push_role_arns" {
  value = { for k, r in aws_iam_role.gitlab_push : k => r.arn }
}
