resource "openstack_compute_instance_v2" "instance" {
  count           = var.node_count
  name            = "${var.name}-${count.index}"
  image_name      = var.source_image
  flavor_name     = var.flavor
  key_pair        = var.key_pair
  security_groups = var.security_groups

  dynamic "network" {
    for_each = toset(var.networks)
    content {
      name = network.key
    }
  }
  tags = var.tags
}

data "openstack_networking_port_v2" "instance_port" {
  count      = length(openstack_compute_instance_v2.instance)
  device_id  = openstack_compute_instance_v2.instance[count.index].id
  network_id = openstack_compute_instance_v2.instance[count.index].network.0.uuid
}

resource "openstack_networking_floatingip_v2" "instance_fip" {
  lifecycle {
    precondition {
      condition     = var.public == true && var.external_network != null
      error_message = "If variable 'public' set to true, variable 'external_network' must be defined"
    }
  }
  count   = var.public == true ? var.node_count : 0
  pool    = var.external_network.fip_pool
  port_id = data.openstack_networking_port_v2.instance_port[count.index].id
  tags    = var.tags
}
