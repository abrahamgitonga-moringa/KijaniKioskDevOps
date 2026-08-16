output "namespace_name" {
  value       = kubernetes_namespace.staging.metadata[0].name
  description = "Provisioned staging namespace name"
}

output "staging_db_host" {
  value       = var.staging_db_host
  description = "Configured staging database host"
}
