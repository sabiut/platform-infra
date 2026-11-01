data "aws_caller_identity" "current" {}

locals {
  name = "${var.environment}-${var.region}"
}

# ---- PostgreSQL ----
# The primary region holds the writable database. Each other region holds a cross-region read
# replica of it: a warm standby that serves reads and can be promoted if the primary region
# is lost (docs/database-failover.md).
#
# Everything the backend needs has a fixed name, so the gitops values are committed once and
# never filled in after an apply:
#   prod/webapp/database           username, password. Created in the primary region and
#                                  replicated by Secrets Manager to every replica region.
#   prod/webapp/database-endpoint  host, port of the database in this region.

locals {
  is_replica = var.db_role == "replica"
  # RDS ARNs are predictable from the identifier, so the replica needs no remote state.
  primary_db_arn = "arn:aws:rds:${var.db_primary_region}:${data.aws_caller_identity.current.account_id}:db:${var.environment}-${var.db_primary_region}-webapp"
}

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

# A cross-region encrypted replica needs a KMS key in its own region.
resource "aws_kms_key" "db_replica" {
  count                   = local.is_replica ? 1 : 0
  description             = "${local.name} RDS read replica storage"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# Primary only. Ephemeral and written with write-only attributes, so the password never
# appears in plan output or state.
ephemeral "random_password" "db" {
  length  = 40
  special = false
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

  # A replica takes its database, user and password from the primary.
  replicate_source_db = local.is_replica ? local.primary_db_arn : null
  kms_key_id          = local.is_replica ? aws_kms_key.db_replica[0].arn : null
  db_name             = local.is_replica ? null : "webapp"
  username            = local.is_replica ? null : "webapp_admin"
  # Terraform sets the password (not RDS-managed) so the credentials secret has a fixed name
  # and can be replicated to the replica regions.
  manage_master_user_password = false
  password_wo                 = local.is_replica ? null : ephemeral.random_password.db.result
  password_wo_version         = local.is_replica ? null : var.db_password_version

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

resource "aws_secretsmanager_secret" "db" {
  count                   = local.is_replica ? 0 : 1
  name                    = "${var.environment}/webapp/database"
  description             = "PostgreSQL master user. Replicated to the read replica regions."
  recovery_window_in_days = var.secret_recovery_window_days

  dynamic "replica" {
    for_each = toset(var.db_replica_regions)
    content { region = replica.value }
  }
  force_overwrite_replica_secret = true # a lab rebuild may find a leftover copy
}

# Written after the database, from the same ephemeral password. If this one write fails
# after RDS succeeded, bump db_password_version to write both again.
resource "aws_secretsmanager_secret_version" "db" {
  count                    = local.is_replica ? 0 : 1
  secret_id                = aws_secretsmanager_secret.db[0].id
  secret_string_wo         = jsonencode({ username = "webapp_admin", password = ephemeral.random_password.db.result })
  secret_string_wo_version = var.db_password_version
  depends_on               = [module.db]
}

# Not secret, but kept next to the credentials so External Secrets reads both the same way.
resource "aws_secretsmanager_secret" "db_endpoint" {
  name                    = "${var.environment}/webapp/database-endpoint"
  description             = "Host and port of this region's PostgreSQL"
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "db_endpoint" {
  secret_id = aws_secretsmanager_secret.db_endpoint.id
  secret_string = jsonencode({
    host = module.db.db_instance_address
    port = tostring(module.db.db_instance_port)
  })
}

# ---- Django media files ----

# Fixed name (region + account), so the gitops values can name it before it exists.
resource "aws_s3_bucket" "media" {
  bucket = "${local.name}-webapp-media-${data.aws_caller_identity.current.account_id}"
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
