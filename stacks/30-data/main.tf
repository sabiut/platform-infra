data "aws_caller_identity" "current" {}

locals {
  name = "${var.environment}-${var.region}"
}

# ---- PostgreSQL ----

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "PostgreSQL, reachable only from EKS nodes"
  vpc_id      = local.network.vpc_id
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_nodes" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = local.eks.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS nodes"
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.2"

  identifier = "${local.name}-webapp"

  engine               = "postgres"
  engine_version       = "17"
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5
  storage_encrypted     = true

  db_name  = "webapp"
  username = "webapp_admin"
  # RDS creates the password in Secrets Manager and rotates it; it never touches Terraform state.
  manage_master_user_password = true

  multi_az               = var.db_multi_az
  create_db_subnet_group = false
  db_subnet_group_name   = local.network.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period          = 7
  deletion_protection              = var.db_deletion_protection
  skip_final_snapshot              = var.skip_final_snapshot
  final_snapshot_identifier_prefix = "${local.name}-webapp-final"
  copy_tags_to_snapshot            = true

  performance_insights_enabled = true

  parameters = [
    { name = "rds.force_ssl", value = "1" },
  ]
}

# ---- Django media files ----

resource "aws_s3_bucket" "media" {
  bucket_prefix = "${local.name}-webapp-media-"
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- Django SECRET_KEY ----
# Generated as an ephemeral value and written with a write-only attribute, so it never
# appears in plan output or state. External Secrets copies it into the cluster.

resource "aws_secretsmanager_secret" "django" {
  name                    = "${var.environment}/webapp/django"
  recovery_window_in_days = var.secret_recovery_window_days
}

ephemeral "random_password" "django_secret_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret_version" "django" {
  secret_id                = aws_secretsmanager_secret.django.id
  secret_string_wo         = jsonencode({ SECRET_KEY = ephemeral.random_password.django_secret_key.result })
  secret_string_wo_version = var.secret_key_version
}

# ---- Backend pod access to its media bucket ----

module "backend_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.8"

  name = "${local.name}-backend"

  attach_custom_policy = true
  policy_statements = [
    {
      sid       = "MediaObjects"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = ["${aws_s3_bucket.media.arn}/*"]
    },
    {
      sid       = "MediaList"
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.media.arn]
    },
  ]

  associations = {
    this = {
      cluster_name    = local.eks.cluster_name
      namespace       = var.app_namespace
      service_account = "backend"
    }
  }
}
