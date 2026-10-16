variable "environment" {
  type = string
}

variable "primary_region" {
  description = "Where CI pushes images"
  type        = string
}

variable "replica_regions" {
  description = "Regions that receive a copy of every image"
  type        = list(string)
}

variable "ecr_repositories" {
  type = list(string)
}

variable "domain" {
  description = "Public domain for the API, e.g. example.com. Empty = no hosted zone yet."
  type        = string
  default     = ""
}
