variable "environment" {
  type        = string
  default     = "staging"
  description = "Target operating infrastructure classification block tier."
}

variable "server_network_matrix" {
  type        = map(string)
  description = "The authoritative mapping of target nodes to their respective Multipass internal IPs."
  default = {
    api      = "10.145.218.117"  # <-- Adjust these three values to match your actual 'multipass list' IPs!
    payments = "10.145.218.214"
    logs     = "10.145.218.242"
  }
}
