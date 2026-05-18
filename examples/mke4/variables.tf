variable "name" {
  description = "Cluster/stack name used for identification (e.g. MKE 4k cluster name)."
  type        = string
}

# === Networking ===
variable "networks" {
  description = "Networks configuration"
  type = map(object({
    admin_state_up = optional(bool, true)
    nodegroups     = list(string)
    subnets = map(object({
      cidr    = string
      private = bool
    }))
  }))
}

# === Machines ===
variable "nodegroups" {
  description = "Machine group definitions. For MKE 4k: use role 'controller' and 'worker'. Recommended: controller 8GB RAM / 2 vCPUs (fresh) or 16GB / 4 vCPUs (upgrade); worker 8GB / 2 vCPUs."
  type = map(object({
    source_image = string
    keypair      = optional(string) # default: \"${var.name}-kp\" (generated key)
    flavor       = string
    count        = number
    role         = string
    public       = bool
    user         = string
  }))
  default = {}
}

# === Firewalls ===
variable "securitygroups" {
  description = "Security group configuration (overrides; normally use module defaults for MKE 4k)."
  type = map(object({
    description  = string
    nodegroups   = list(string)
    rules_ipv4   = optional(map(object({
      direction        = string
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
  description = "Ingress (load balancer) configuration; see ingress.tf for MKE 4k defaults."
  type = map(object({
    nodegroups   = list(string)
    network_name = string
    public       = bool
    listeners = map(object({
      protocol      = string
      protocol_port = number
      target_port   = number
      lb_method     = string
    }))
  }))
  default = {}
}

variable "external_network" {
  description = "Existing external network for floating IPs and outbound."
  type = object({
    id       = string
    fip_pool = string
  })
}

# === Common ===
variable "extra_tags" {
  description = "Extra tags for all provisioned resources."
  type        = list(string)
  default     = []
}

variable "disable_selinux" {
  description = "If true, cloud-init disables SELinux (setenforce + /etc/selinux/config) and schedules reboot in 1 minute so the change fully applies (RHEL/Rocky/Fedora-like images)."
  type        = bool
  default     = false
}

variable "cloud_init_extra" {
  description = "Optional cloud-config YAML merged into user_data for all nodes (no leading #cloud-config; appended after users and optional SELinux runcmd)."
  type        = string
  default     = null
}


variable "is_bootc_based" {
  description = "If true, deploy system-upgrade-controller manifests to /var/lib/k0s/manifests on controller nodes and configure the MKE 4k ucpauthz exemption for the system-upgrade service account."
  type        = bool
  default     = false
}