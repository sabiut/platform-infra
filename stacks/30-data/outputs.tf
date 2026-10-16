output "db_endpoint" {
  value = module.db.db_instance_endpoint
}

output "db_master_secret_arn" {
  description = "Secrets Manager secret RDS manages; External Secrets reads it"
  value       = module.db.db_instance_master_user_secret_arn
}

output "django_secret_name" {
  value = aws_secretsmanager_secret.django.name
}

output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}
