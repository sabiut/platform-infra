terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.60" }
  }
  # Local state, on purpose: this stack creates the S3 bucket and the CI roles, so it can't
  # keep its state in that bucket or run from that CI. Run it from a laptop with your own
  # credentials. terraform.tfstate is gitignored; don't lose it while the foundation is up.
  backend "local" {}
}

provider "aws" {
  region = var.primary_region
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "replica"
  region = var.replica_region
  default_tags { tags = local.tags }
}

locals {
  tags = { project = "eks-gitops-platform", stack = "foundation", managed_by = "terraform" }
}
