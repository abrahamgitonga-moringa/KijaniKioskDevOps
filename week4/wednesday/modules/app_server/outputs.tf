output "resource_id" {
  value       = null_resource.this.id
  description = "The unique tracking reference signature assigned by the provider state engine."
}

output "allocated_ip" {
  value       = var.vm_ip
  description = "The registered operational IP address mapping assigned to this server instance."
}
