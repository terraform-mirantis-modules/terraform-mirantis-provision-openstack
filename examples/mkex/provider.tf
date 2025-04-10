terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

#provider "openstack" {
#  user_name = var.openstack.user_name
#  tenant_name = var.openstack.tenant_name
#  password = var.openstack.password
#  auth_url = var.openstack.auth_url
#  region = var.openstack.region
#}
