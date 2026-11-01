output "db_role" {
  value = var.db_role
}

output "db_instance_arn" {
  value = module.db.db_instance_arn
}

output "db_endpoint" {
  value = module.db.db_instance_endpoint
}

output "db_secret_name" {
  description = "username, password; External Secrets reads it (a replicated copy in replica regions)"
  value       = "${var.environment}/webapp/database"
}

output "db_endpoint_secret_name" {
  description = "host, port of this region's database; External Secrets reads it"
  value       = aws_secretsmanager_secret.db_endpoint.name
}

output "django_secret_name" {
  value = aws_secretsmanager_secret.django.name
}

output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}
