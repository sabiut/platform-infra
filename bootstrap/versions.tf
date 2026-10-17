terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.60" }
  }
  # Applied by hand. The very first apply has no bucket to store state in, so it runs with
  # local state (comment this block out); then `scripts/tf.sh init bootstrap` moves the state
  # into the bucket it created.
  backend "s3" {}
}

provider "aws" {
  region = var.state_region
  default_tags { tags = { project = "eks-gitops-platform", stack = "bootstrap", managed_by = "terraform" } }
}
