# 1. Dynamically render the template and write it as a physical file on your disk
resource "local_file" "cloudinit_rendered" {
  content  = templatefile("${path.module}/cloud-config.yaml", {
    ssh_key = file("~/.ssh/id_ed25519.pub")
  })
  filename = "${path.module}/rendered-cloud-config-${var.server_name}.yaml"
}

# 2. Consume the rendered file path inside the multipass resource
resource "multipass_instance" "this" {
  name   = var.server_name
  cpus   = var.cpus
  memory = var.memory
  image  = "22.04"

  # Pass the path to the file on disk, not the raw contents
  cloudinit_file = local_file.cloudinit_rendered.filename
}
