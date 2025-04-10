module "key" {
  source = "../modules/key"
  name = "${var.name}-kp"
}

locals {
  pk_path = "${path.cwd}/ssh-keys/${var.name}-common.pem"
}

resource "local_sensitive_file" "ssh_private_key" {
  content              = module.key.private_key
  filename             = local.pk_path
  file_permission      = "0600"
  directory_permission = "0700"
}
