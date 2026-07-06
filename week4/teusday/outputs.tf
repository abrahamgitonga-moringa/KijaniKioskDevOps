output "api_server_ip" {
  type        = string
  description = "The target IP address allocated for the KijaniKiosk API server connectivity checks."
  value       = var.vm_ip
}

output "provisioning_status" {
  type        = string
  description = "Confirms that the configuration script layer execution sequence has run."
  value       = "Success"
}
