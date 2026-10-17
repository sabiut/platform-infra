variable "primary_region" {
  description = "Holds the state bucket; CI pushes images here"
  type        = string
}

variable "replica_region" {
  description = "Receives a copy of every image. A third region needs another provider alias."
  type        = string
}

variable "github_repo" {
  description = "owner/name of the infra repo on GitHub"
  type        = string
}

variable "gitlab_namespace" {
  description = "GitLab group or user that owns the app repos"
  type        = string
}

variable "gitlab_app_repos" {
  description = "App repos that push images, mapped to the ECR repo each may push to"
  type        = map(string)
}

variable "domain" {
  description = "Public domain for the API, e.g. example.com. Empty = no hosted zone yet."
  type        = string
  default     = ""
}
