variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  description = "Must not overlap any other region's VPC (10.20 Sydney, 10.21 London, 10.22 reserved)"
  type        = string
}

variable "cluster_name" {
  description = "Used for the subnet tags the AWS Load Balancer Controller looks for"
  type        = string
}

variable "single_nat_gateway" {
  description = "true = one NAT for the whole VPC (cheaper, fails with its AZ)"
  type        = bool
  default     = false
}

variable "enable_interface_endpoints" {
  description = "ECR and STS interface endpoints; keeps image pulls off the NAT"
  type        = bool
  default     = true
}
