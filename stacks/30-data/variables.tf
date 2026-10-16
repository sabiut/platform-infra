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

variable "db_instance_class" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

variable "db_allocated_storage" {
  type = number
}

variable "db_deletion_protection" {
  description = "Set false only to tear down a lab environment"
  type        = bool
  default     = true
}

variable "app_namespace" {
  description = "Kubernetes namespace the backend runs in"
  type        = string
}

variable "secret_key_version" {
  description = "Bump to generate and store a new Django SECRET_KEY"
  type        = number
  default     = 1
}
