# Outputs of 10-network. In plan-only mode (no state_bucket) placeholders stand in, so this
# stack can be planned before the network exists. They are never used once state is real.
data "terraform_remote_state" "network" {
  count   = var.state_bucket == "" ? 0 : 1
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/${var.region}/10-network.tfstate"
    region = var.state_region
  }
}

locals {
  network = try(data.terraform_remote_state.network[0].outputs, {
    vpc_id             = "vpc-PLANONLY0000000"
    private_subnet_ids = ["subnet-PLANONLY00000a", "subnet-PLANONLY00000b", "subnet-PLANONLY00000c"]
  })
}
