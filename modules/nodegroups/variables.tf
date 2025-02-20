variable "name" {
  description = "Node Group key"
  type        = string
}

variable "source_image" {
  description = "The source image to use for the machine"
  type        = string
}

variable "flavor" {
  description = "Instance flavor"
  type        = string
}

variable "node_count" {
  description = "Number of machines to create"
  type        = number
}

variable "networks" {
  description = "Network list to attach machines to"
  type        = list(string)
}

variable "security_groups" {
  description = "Security group ids"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = list(string)
}

variable "key_pair" {
  description = "Keypair name for nodes"
  type        = string
}

variable "external_network" {
  description = "Existing external network specs"
  type = object({
    id       = optional(string)
    fip_pool = optional(string)
  })
  default = null
}

variable "public" {
  description = "True if machines need to have FIPs assigned, false otherwise. If true, first attached ntwork's port will be used as port for FIP"
  type        = bool
}

variable "user_data" {
  description = "Cloud-init userdata to be passed to the instance"
  type        = string
  default     = ""
}
