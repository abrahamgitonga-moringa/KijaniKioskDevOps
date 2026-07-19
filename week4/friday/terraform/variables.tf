variable "environment" {
  type        = string
  description = "Target deployment lifecycle tier descriptor."
  default     = "staging"
}

variable "server_matrix" {
  type        = map(map(string))
  description = "Configuration data matrix mapping infrastructure targets."
  default = {
    api      = { service_name = "kk-api", port = "3000" }
    payments = { service_name = "kk-payments", port = "3001" }
    logs     = { service_name = "kk-logs", port = "5000" }
  }
}
