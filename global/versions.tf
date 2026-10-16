terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.60" }
  }
  # bucket, key and region come from scripts/tf.sh (-backend-config)
  backend "s3" {}
}

provider "aws" {
  region = var.primary_region
  default_tags { tags = { project = "eks-gitops-platform", stack = "global", environment = var.environment, managed_by = "terraform" } }
}
