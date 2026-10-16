output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "route53_zone_id" {
  value = one(aws_route53_zone.public[*].zone_id)
}

output "route53_name_servers" {
  description = "Set these at your domain registrar"
  value       = one(aws_route53_zone.public[*].name_servers)
}
