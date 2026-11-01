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

variable "skip_final_snapshot" {
  description = "true only for throwaway lab databases"
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "0 deletes secrets immediately, so a lab can be rebuilt with the same names"
  type        = number
  default     = 7
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

variable "db_role" {
  description = "primary: the writable database. replica: a cross-region read replica of the database in db_primary_region."
  type        = string
  default     = "primary"
  validation {
    condition     = contains(["primary", "replica"], var.db_role)
    error_message = "db_role must be primary or replica."
  }
}

variable "db_primary_region" {
  description = "Replica only: the region whose database this one replicates"
  type        = string
  default     = "ap-southeast-2"
}

variable "db_replica_regions" {
  description = "Primary only: regions that get a copy of the database credentials secret (one per read replica)"
  type        = list(string)
  default     = []
}

variable "db_password_version" {
  description = "Primary only: bump to generate a new master password and write it to RDS and the credentials secret"
  type        = number
  default     = 1
}
