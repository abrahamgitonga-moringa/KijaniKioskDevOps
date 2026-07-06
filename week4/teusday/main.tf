terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 1.0.0"
}

resource "null_resource" "kijanikiosk_api" {
  # Forces recreation if the underlying target host IP modifications occur
  triggers = {
    ip = var.vm_ip
  }

  connection {
    type        = "ssh"
    host        = var.vm_ip
    user        = "ubuntu"
    # Points cleanly to your local SSH identity profile
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==================================================='",
      "echo 'CONNECTED SUCCESSFUL TO KIJANIKIOSK VM HOST'",
      "echo 'Environment: ${var.environment}'",
      "echo 'Target IP: ${var.vm_ip}'",
      "echo '==================================================='",
      "uname -a",
      "lsb_release -a"
    ]
  }
}
