variable "staging_namespace" {
  type        = string
  default     = "kijani-staging"
  description = "Target Kubernetes namespace for staging workloads"
}

variable "staging_db_host" {
  type        = string
  default     = "staging-db.internal"
  description = "Isolated database host for staging"
}
