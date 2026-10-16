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

variable "argocd_chart_version" {
  type = string
}

variable "argocd_apps_chart_version" {
  type = string
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the gitops repo on GitLab"
  type        = string
}

variable "gitops_repo_secret_name" {
  description = "Secrets Manager secret holding a GitLab deploy token as {\"username\":...,\"password\":...}"
  type        = string
  default     = "platform/gitops-repo"
}

variable "gitops_repo_token_version" {
  description = "Bump after rotating the deploy token so the new value is written to the cluster"
  type        = number
  default     = 1
}
