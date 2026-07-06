variable "vm_ip" {
  type        = string
  description = "The IPv4 network address of the targeted local Multipass virtual machine instance."
}

variable "environment" {
  type        = string
  description = "The target deployment lifecycle environment tier identifier."
  default     = "staging"
}
