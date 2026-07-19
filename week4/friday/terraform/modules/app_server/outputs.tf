output "ipv4_address" {
  value       = multipass_instance.this.ipv4
  description = "Dynamic primary networking interfaces IPv4 pointer address resolution metric."
}
