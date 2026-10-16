data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "app" {
  for_each             = toset(var.ecr_repositories)
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 100 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 100 }
      action       = { type = "expire" }
    }]
  })
}

# Every image pushed in the primary region is copied to each replica region, so every
# cluster pulls from ECR in its own region.
resource "aws_ecr_replication_configuration" "this" {
  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = var.replica_regions
        content {
          region      = destination.value
          registry_id = data.aws_caller_identity.current.account_id
        }
      }
      repository_filter {
        filter      = "*"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# Replicated repos are created automatically; this template gives them the same settings.
resource "aws_ecr_repository_creation_template" "replica" {
  prefix               = "ROOT"
  applied_for          = ["REPLICATION"]
  image_tag_mutability = "IMMUTABLE"
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_route53_zone" "public" {
  count = var.domain == "" ? 0 : 1
  name  = var.domain
}
