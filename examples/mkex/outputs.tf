locals {
  fips = flatten([
    for k, ng in module.provision.nodegroups: [
      for node in ng.nodes : node.floating_ip
    ]
  ])
  ansible_inventory = <<-EOT

all:
  hosts:
  %{~for k, ng in module.provision.nodegroups~}
  %{~for node in ng.nodes~}
      # ${node.name}
      ${node.name}:
          ansible_connection: ssh
          ansible_ssh_private_key_file: ${local.pk_path}
          ansible_user: ${var.nodegroups[k].user}
          ansible_host: ${node.floating_ip}
  %{~endfor~}
  %{~endfor~}
  children:
    managers:
      hosts:
  %{~for k, ng in module.provision.nodegroups~}
  %{~for node in ng.nodes~}
      %{~if ng.role == "manager"~}
        ${node.name}
      %{~endif~}
  %{~endfor~}
  %{~endfor~}
    workers:
      hosts:
  %{~for k, ng in module.provision.nodegroups~}
  %{~for node in ng.nodes~}
      %{~if ng.role == "worker"~}
        ${node.name}
      %{~endif~}
  %{~endfor~}
  %{~endfor~}
  vars:
    mke_url: ${module.provision.ingresses["control_plane"].floating_ip}
EOT
}

output "ansible_inventory" {
  value = local.ansible_inventory
  sensitive = true
}
