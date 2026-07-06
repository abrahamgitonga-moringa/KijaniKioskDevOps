terraform {
  required_version = ">= 1.5.0"
  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4.0"
    }
  }
  backend "s3" {
    bucket                      = "kijanikiosk-tfstate"
    key                         = "staging/pipeline/terraform.tfstate"
    region                      = "us-east-1"
    endpoints                   = { s3 = "http://localhost:9000" }
    access_key                  = "minioadmin"
    secret_key                  = "minioadmin"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

provider "multipass" {}

module "app_servers" {
  source   = "./modules/app_server"
  for_each = var.server_matrix

  server_name = "kijanikiosk-${each.key}"
  cpus        = 1
  memory      = "1G"
}
