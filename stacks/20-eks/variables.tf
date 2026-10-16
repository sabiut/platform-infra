variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "state_bucket" {
  description = "Bucket holding the other stacks' state. Empty = plan-only mode with placeholder inputs."
  type        = string
  default     = ""
}

variable "state_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "kubernetes_version" {
  type = string
}

variable "public_access_cidrs" {
  description = "Who may reach the public API endpoint (IAM auth is still required)"
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "IAM users/roles that get cluster-admin"
  type        = list(string)
  default     = []
}

variable "viewer_principal_arns" {
  description = "IAM users/roles that get read-only access"
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}
