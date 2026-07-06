output "cluster_ips" {
  value = {
    for k, v in module.app_servers : k => v.ipv4_address
  }
  description = "Mapped key-value pairs associating infrastructure identifiers to dynamic IPs."
}
