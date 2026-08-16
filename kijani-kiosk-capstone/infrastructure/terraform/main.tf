terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Namespace Provisioning
resource "kubernetes_namespace" "staging" {
  metadata {
    name = var.staging_namespace
    labels = {
      environment = "staging"
      app         = "kijani-kiosk"
    }
  }
}

# Resource Quotas for Staging Isolation
resource "kubernetes_resource_quota" "staging_quota" {
  metadata {
    name      = "staging-quota"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }
  spec {
    hard = {
      pods   = "10"
      cpu    = "2"
      memory = "4Gi"
    }
  }
}
