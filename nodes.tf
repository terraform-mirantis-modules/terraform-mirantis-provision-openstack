module "nodegroups" {
  for_each = var.nodegroups

  source           = "./modules/nodegroups"
  node_count       = each.value.count
  name             = "${var.name}-${each.key}"
  flavor           = each.value.flavor
  source_image     = each.value.source_image
  key_pair         = each.value.keypair
  public           = each.value.public
  external_network = var.external_network

  networks        = [for k, v in var.networks : "${var.name}-${k}" if contains(v.nodegroups, each.key)]
  security_groups = [for k, v in var.securitygroups : "${var.name}-${k}" if contains(v.nodegroups, each.key)]
  tags            = concat([var.name, each.key], var.extra_tags)
  user_data       = each.value.user_data
}

// locals created after node groups are provisioned.
locals {
  // combine node-group asg & node information after creation
  nodegroups = { for k, ng in var.nodegroups : k => merge(ng, {
    nodes : module.nodegroups[k].nodes
  }) }

}
