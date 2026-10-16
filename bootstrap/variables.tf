variable "state_region" {
  type    = string
  default = "ap-southeast-2"
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

variable "regions" {
  description = "Regions the platform runs in; ECR push is allowed only in the primary (first)"
  type        = list(string)
}
