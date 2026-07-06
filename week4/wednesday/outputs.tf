output "topology_matrix" {
  description = "The network addressing schema deployed across the app_server modules."
  value = {
    for instance_key, instance_block in module.app_servers : instance_key => instance_block.allocated_ip
  }
}
