locals {
  lb_listeners = flatten([
    for ingr_key, ingr in var.ingresses : [
      for l_key, l in ingr.listeners : {
        ingress_key   = ingr_key
        listener_key  = l_key
        protocol      = l.protocol
        protocol_port = l.protocol_port
        target_port   = l.target_port
        lb_method     = l.lb_method
        nw_id         = openstack_networking_network_v2.network[ingr.network_name].id
        nodegroups    = ingr.nodegroups
      }
    ]
  ])

  lb_listeners_map = tomap({
    for lb in local.lb_listeners : "${var.name}-${lb.ingress_key}-${lb.listener_key}" => lb
  })
}

resource "openstack_lb_loadbalancer_v2" "lb" {
  for_each       = var.ingresses
  name           = "${var.name}-${each.key}-lb"
  vip_network_id = openstack_networking_network_v2.network[each.value.network_name].id
}

resource "openstack_networking_floatingip_v2" "instance_fip" {
  for_each       = {for k, v in var.ingresses: k => v if v.public == true}
  pool    = var.external_network.fip_pool
  port_id = openstack_lb_loadbalancer_v2.lb[each.key].vip_port_id
}

resource "openstack_lb_listener_v2" "lb_listener" {
  for_each        = local.lb_listeners_map
  name            = "${each.key}-lb-listener"
  protocol        = each.value.protocol
  protocol_port   = each.value.protocol_port
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb[each.value.ingress_key].id
}

resource "openstack_lb_pool_v2" "lb_pool" {
  for_each    = local.lb_listeners_map
  name        = "${each.key}-pool"
  protocol    = each.value.protocol
  lb_method   = each.value.lb_method
  listener_id = openstack_lb_listener_v2.lb_listener[each.key].id
}

locals {
  nodegroups_nodes = flatten([
    for k, v in var.ingresses : [
      for i in v.nodegroups : module.nodegroups[i].nodes
    ]
    ]
  )
}

resource "openstack_lb_members_v2" "lb_members" {
  for_each = local.lb_listeners_map
  pool_id  = openstack_lb_pool_v2.lb_pool[each.key].id
  dynamic "member" {
    for_each = local.nodegroups_nodes
    content {
      name          = member.value["name"]
      address       = member.value["network"][0]["fixed_ip_v4"]
      protocol_port = each.value.target_port
    }
  }
}

// calculated after lb is created
locals {
  // Add the lb for the lb to the ingress
  ingresses_withlb = { for k, i in var.ingresses : k => merge(i, openstack_lb_loadbalancer_v2.lb[k], {"floating_ip": openstack_networking_floatingip_v2.instance_fip[k].address}) }
}
