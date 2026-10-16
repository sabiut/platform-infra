terraform {
  required_version = ">= 1.11"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.60" }
    random = { source = "hashicorp/random", version = "~> 3.8" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags { tags = { project = "eks-gitops-platform", stack = "30-data", environment = var.environment, managed_by = "terraform" } }
}
