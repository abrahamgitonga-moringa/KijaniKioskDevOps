output "namespace_name" {
  value       = kubernetes_namespace.staging.metadata[0].name
  description = "The name of the created staging namespace"
}

output "staging_db_host" {
  value       = "staging-db.internal"
  description = "Internal database endpoint for staging"
}
