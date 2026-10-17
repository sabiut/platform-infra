# One set of repos per region. CI pushes to the primary region only; ECR replication copies
# every image to the replica, so each cluster pulls from its own region. The replica repos
# are created here (not left to replication to create on first push) so that Terraform also
# deletes them on destroy.

locals {
  ecr_repositories = toset(distinct(values(var.gitlab_app_repos)))
  ecr_lifecycle = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 100 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 100 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_ecr_repository" "app" {
  for_each             = local.ecr_repositories
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # destroy even when it holds images

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy     = local.ecr_lifecycle
}

resource "aws_ecr_repository" "replica" {
  provider             = aws.replica
  for_each             = local.ecr_repositories
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "replica" {
  provider   = aws.replica
  for_each   = aws_ecr_repository.replica
  repository = each.value.name
  policy     = local.ecr_lifecycle
}

resource "aws_ecr_replication_configuration" "this" {
  replication_configuration {
    rule {
      destination {
        region      = var.replica_region
        registry_id = local.account_id
      }
      # ECR has no wildcard here (filters need 2+ characters), so one prefix per repo.
      dynamic "repository_filter" {
        for_each = local.ecr_repositories
        content {
          filter      = repository_filter.value
          filter_type = "PREFIX_MATCH"
        }
      }
    }
  }
}
