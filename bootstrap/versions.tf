terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.60" }
  }
  # Applied once by hand. Its state starts local; after the first apply, move it into the
  # bucket it creates: add a backend "s3" block and run `terraform init -migrate-state`.
}

provider "aws" {
  region = var.state_region
  default_tags { tags = { project = "eks-gitops-platform", stack = "bootstrap", managed_by = "terraform" } }
}
