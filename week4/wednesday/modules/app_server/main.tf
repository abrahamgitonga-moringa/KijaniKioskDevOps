resource "null_resource" "this" {
  # Trigger recreation loops if the core IP assignment is modified dynamically
  triggers = {
    ip = var.vm_ip
  }

  connection {
    type        = "ssh"
    host        = var.vm_ip
    user        = "ubuntu"
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==================================================='",
      "echo 'MODULE ENFORCEMENT ENGINE INITIALIZED FOR: ${var.name}'",
      "echo 'Environment Targets: ${var.environment}'",
      "echo 'System Runtime Context Details:'",
      "uname -a",
      "echo '==================================================='"
    ]
  }
}
