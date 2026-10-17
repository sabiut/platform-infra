environment        = "prod"
region             = "ap-southeast-2"
vpc_cidr           = "10.20.0.0/16"
cluster_name       = "prod-ap-southeast-2"
single_nat_gateway = true # LAB PROFILE (prod: false, one NAT per AZ)

# LAB PROFILE: keep image pulls on the NAT instead of paying for endpoints (prod: true)
enable_interface_endpoints = false
