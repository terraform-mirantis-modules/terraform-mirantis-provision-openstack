resource "openstack_networking_network_v2" "network" {
  for_each = var.networks

  name           = "${var.name}-${each.key}"
  admin_state_up = true
  tags           = concat([var.name, each.key], var.extra_tags)
}

locals {
  # we need to know network key (name) in order to add subnet to a proper network
  network_subnets = flatten([
    for nw_key, nw in var.networks : [
      for sn_key, sn in nw.subnets : {
        nw_key     = nw_key
        sn_key     = sn_key
        cidr       = sn.cidr
        nodegroups = nw.nodegroups
        private    = sn.private
        nw_id      = openstack_networking_network_v2.network[nw_key].id
      }
    ]
  ])
  network_subnets_map = tomap({
    for subnet in local.network_subnets : "${var.name}-${subnet.nw_key}-${subnet.sn_key}" => subnet
  })
}

resource "openstack_networking_subnet_v2" "subnet" {
  for_each = local.network_subnets_map

  name       = each.key
  network_id = each.value.nw_id
  cidr       = each.value.cidr
  ip_version = 4
  tags       = concat([var.name, each.key], var.extra_tags)
}


resource "openstack_networking_router_v2" "router" {
  for_each       = local.network_subnets_map
  name           = "${each.key}-router"
  admin_state_up = true

  external_network_id = each.value.private ? null : var.external_network.id
  tags                = concat([var.name, each.key], var.extra_tags)
}

resource "openstack_networking_router_interface_v2" "router_iface" {
  for_each  = local.network_subnets_map
  subnet_id = openstack_networking_subnet_v2.subnet[each.key].id
  router_id = openstack_networking_router_v2.router[each.key].id
}

resource "openstack_networking_floatingip_v2" "router_fip" {
  count = length([for sn in local.network_subnets : sn.sn_key if sn.private == false])
  pool  = var.external_network.fip_pool
  tags  = concat([var.name], var.extra_tags)
}

