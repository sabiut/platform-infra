environment        = "prod"
region             = "ap-southeast-2"
vpc_cidr           = "10.20.0.0/16"
cluster_name       = "prod-ap-southeast-2"
single_nat_gateway = false # one NAT per AZ: losing an AZ doesn't cut the others off

# ECR and STS interface endpoints: image pulls and token exchange stay inside the VPC
enable_interface_endpoints = true
