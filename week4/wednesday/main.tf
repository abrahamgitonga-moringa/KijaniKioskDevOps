terraform {
  required_version = ">= 1.6.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }

 backend "s3" {
    bucket                      = "kijanikiosk-terraform-state"
    key                         = "staging/services/app_servers/terraform.tfstate"
    region                      = "us-east-1"
    
    endpoints = {
      s3 = "http://127.0.0.1:9000"
    }

    # Use the exact root keys expected by the Docker container
    access_key                  = "minioadmin"
    secret_key                  = "minioadmin"
    
    skip_requesting_account_id  = true  
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_credentials_validation = true
    use_path_style              = true  
  } 
}

locals {
  servers = var.server_network_matrix
}

module "app_servers" {
  source   = "./modules/app_server"
  for_each = local.servers

  name                 = each.key
  vm_ip                = each.value
  environment          = var.environment
  ssh_private_key_path = "~/.ssh/id_ed25519"
}
