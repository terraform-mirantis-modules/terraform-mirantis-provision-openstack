output "nodegroups" {
  description = "Node group with generated node lists."
  value       = local.nodegroups
  sensitive   = true
}

output "ingresses" {
  description = "Created ingress data"
  value       = local.ingresses_withlb
}

output "subnets" {
  value = openstack_networking_subnet_v2.subnet
}
