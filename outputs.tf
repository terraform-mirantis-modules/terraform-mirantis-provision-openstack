output "nodegroups" {
  description = "Node group with generated node lists."
  value       = local.nodegroups
  sensitive   = true
}

output "ingresses" {
  description = "Created ingress data"
  value       = local.ingresses_withlb
}
