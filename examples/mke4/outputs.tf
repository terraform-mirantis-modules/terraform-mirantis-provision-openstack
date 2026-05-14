locals {
  # Build mkectl hosts list: MKE 4k uses role "controller+worker" for control-plane nodes, "worker" for workers.
  # Use floating_ip when set (public=true); otherwise fixed IP so mkectl works from inside the network.
  mke4_hosts = flatten([
    for ng_key, ng in module.provision.nodegroups : [
      for node in ng.nodes : {
        role = ng.role == "controller" ? "controller+worker" : "worker"
        ssh = {
          address  = coalesce(node.floating_ip, try(node.network[0].fixed_ip_v4, ""))
          keyPath  = abspath(local.pk_path)
          port     = 22
          user     = var.nodegroups[ng_key].user
        }
      }
    ]
  ])
  lb_ip = try(module.provision.ingresses["control_plane"].floating_ip, null)
  # Indented YAML fragment for spec.hosts (under "  hosts:")
  hosts_yaml_raw    = replace(yamlencode(local.mke4_hosts), "/((?:^|\\n)[\\s-]*)\"([\\w.-]+)\":/", "$1$2:")
  hosts_yaml_indent = join("", ["    ", replace(local.hosts_yaml_raw, "\n", "\n    ")])
  api_server_external_address = local.lb_ip != null ? local.lb_ip : "REPLACE_WITH_LOAD_BALANCER_IP_OR_HOSTNAME"
  api_server_sans             = local.lb_ip != null ? [local.lb_ip] : []
  # Full MKE 4k config (same structure as mkectl init) with our hosts and apiServer
  mkectl_config_full = templatefile("${path.module}/mke4-config.yaml.tpl", {
    version                     = "latest"
    hosts_yaml                  = local.hosts_yaml_indent
    api_server_external_address = local.api_server_external_address
    api_server_sans             = local.api_server_sans
    is_bootc_based              = var.is_bootc_based
  })
}

output "nodegroups" {
  description = "Node groups with node lists (for mkectl / MKE 4k config)."
  value       = module.provision.nodegroups
  sensitive   = true
}

output "control_plane_address" {
  description = "Load balancer address for Kubernetes API and MKE 4k (use as apiServer.externalAddress in MKE 4k config)."
  value       = try(module.provision.ingresses["control_plane"].floating_ip, null)
}

output "ingresses" {
  description = "Created ingress (load balancer) data including floating IPs."
  value       = module.provision.ingresses
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key for node access."
  value       = local.pk_path
  sensitive   = true
}

# Full MKE 4k config (same structure as mkectl init) with Terraform-derived hosts and apiServer.
output "mkectl_config" {
  description = "Complete MKE 4k config for mkectl. Use: terraform output -raw mkectl_config > mke4.yaml && mkectl apply -f mke4.yaml"
  value       = local.mkectl_config_full
  sensitive   = true
}

# Example MKE 4k apiServer.externalAddress: use control_plane_address with port 443 for Dashboard, or 6443 for kubectl.
output "mke4_config_hint" {
  description = "Hint for MKE 4k configuration file (apiServer.externalAddress)."
  value       = "Set apiServer.externalAddress to \"${try(module.provision.ingresses["control_plane"].floating_ip, "LB_IP")}\" (or LB_IP:443 for Dashboard). Ensure SANs include this address."
}
