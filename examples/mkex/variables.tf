variable "name" {
  type = string
}

#variable "openstack" {
# description = "Openstack variables"
# type = object({
#    user_name = string
#    tenant_name = string
#    password = string
#    auth_url = string
#    region = string
#    user_dn = string
# })
#  
#}

# ===  Networking ===
variable "networks" {
  description = "Networks configuration"
  type = map(object({
    admin_state_up = optional(bool, true)
    nodegroups     = list(string)
    subnets        = map(object({
      cidr            = string
      private         = bool
      }
    ))
  }))
}

## === Machines ===

variable "nodegroups" {
  description = "A map of machine group definitions"
  type = map(object({
    source_image = string
    keypair      = string
    flavor       = string
    count        = number
    role         = string
    public       = bool #if public, then floating IP will be assigned
    user         = string
    #    tags                  = optional(map(string), {})
  }))
  default = {}
}

## === Firewalls ===

variable "securitygroups" {
  description = "Security group configuration"
  type = map(object({
    description = string
    nodegroups  = list(string) # which nodegroups should get attached to the sg?
    rules_ipv4  = optional(map(object({
      direction        = string # either "ingress" or "egress"
      protocol         = string
      port_range_min   = number
      port_range_max   = number
      remote_ip_prefix = string
    })), {})
    tags = optional(list(string), [])
  }))
  default = {}
}

# === Ingresses ===

variable "ingresses" {
  description = "Ingress traffic configuration for specific nodegroups (load balancer)"
  type = map(object({
    nodegroups    = list(string) # which nodegroups should get attached to the ingress
    network_name  = string
    public        = bool
    listeners     = map(object({
      protocol      = string
      protocol_port = number
      lb_method     = string
    }))
  }))
  default = {}
}

variable "external_network" {
  description = "Existing external network specs"
  type = object({
    id       = string
    fip_pool = string
  })
}

# === Common ===

variable "extra_tags" {
  description = "Extra tags that will be added to all provisioned resources, where possible."
  type        = list(string)
  default     = []
}
