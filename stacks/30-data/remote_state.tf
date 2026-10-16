# Outputs of 10-network and 20-eks; placeholders in plan-only mode (see 20-eks/remote_state.tf).
data "terraform_remote_state" "network" {
  count   = var.state_bucket == "" ? 0 : 1
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/${var.region}/10-network.tfstate"
    region = var.state_region
  }
}

data "terraform_remote_state" "eks" {
  count   = var.state_bucket == "" ? 0 : 1
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/${var.region}/20-eks.tfstate"
    region = var.state_region
  }
}

locals {
  network = try(data.terraform_remote_state.network[0].outputs, {
    vpc_id                     = "vpc-PLANONLY0000000"
    database_subnet_group_name = "planonly-db-subnets"
  })
  eks = try(data.terraform_remote_state.eks[0].outputs, {
    cluster_name           = "${var.environment}-${var.region}"
    node_security_group_id = "sg-PLANONLY00000000"
  })
}
