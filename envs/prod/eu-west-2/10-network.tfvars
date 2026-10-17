environment        = "prod"
region             = "eu-west-2"
vpc_cidr           = "10.21.0.0/16"
cluster_name       = "prod-eu-west-2"
single_nat_gateway = true # LAB PROFILE (prod: false, one NAT per AZ)

# LAB PROFILE: keep image pulls on the NAT instead of paying for endpoints (prod: true)
enable_interface_endpoints = false
