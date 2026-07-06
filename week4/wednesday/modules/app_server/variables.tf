variable "name" {
  type        = string
  description = "The target functional component name tag for this server deployment (e.g., api, payments, logs)."
}

variable "vm_ip" {
  type        = string
  description = "The assigned IPv4 network entry point for this specific virtual host."
}

variable "environment" {
  type        = string
  description = "The target system lifecycle environment identifier tier (e.g., staging, production)."
  default     = "staging"
}

variable "ssh_private_key_path" {
  type        = string
  description = "The filesystem location of the local cryptographic identity key used to authenticate connections."
  default     = "~/.ssh/id_ed25519"
}
