resource "openstack_networking_secgroup_v2" "sg" {
  for_each    = var.securitygroups
  name        = "${var.name}-${each.key}"
  description = each.value.description
  tags        = concat([var.name, each.key], var.extra_tags)
}

locals {
  # we need to know security group key(name) in order to get it's id and use it to attach rule to a proper group
  sgname_sgrules = flatten([
    for sg_key, sg in var.securitygroups : [
      for rule_key, rule in sg.rules_ipv4 : {
        sg_key            = sg_key
        rule_key          = rule_key
        direction         = rule.direction
        protocol          = rule.protocol
        ethertype         = "IPv4"
        port_range_min    = rule.port_range_min
        port_range_max    = rule.port_range_max
        remote_ip_prefix  = rule.remote_ip_prefix
        security_group_id = openstack_networking_secgroup_v2.sg[sg_key].id
      }
    ]
  ])
  sgname_sgrules_map = tomap({
    for sgn_sgr in local.sgname_sgrules : "${sgn_sgr.sg_key}-${sgn_sgr.rule_key}" => sgn_sgr
  })
}

resource "openstack_networking_secgroup_rule_v2" "sg_rule" {
  for_each = local.sgname_sgrules_map

  direction         = each.value.direction
  protocol          = each.value.protocol
  ethertype         = each.value.ethertype
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  security_group_id = each.value.security_group_id
}
