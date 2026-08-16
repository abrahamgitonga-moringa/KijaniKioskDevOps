terraform {
  required_version = ">= 1.3.0"
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

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "kijani-staging"
    labels = {
      environment = "staging"
      app         = "kijani-kiosk"
    }
  }
}

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
