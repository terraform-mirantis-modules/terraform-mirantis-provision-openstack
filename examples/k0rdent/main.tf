locals {
  internal_network_cidr = var.networks["internal-network"].subnets["subnet_1"].cidr
  securitygroups = {
  
    "common_sg" = {
      description = "SG that will be used for both controllers and workers"
      nodegroups  = ["controller", "worker"]
      rules_ipv4 = {
        "ssh" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 22
          port_range_max   = 22
          remote_ip_prefix = "0.0.0.0/0"
        },
        "konnectivity" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 8132
          port_range_max   = 8132
          remote_ip_prefix = local.internal_network_cidr
        },
        "kubelet" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 10250
          port_range_max   = 10250
          remote_ip_prefix = local.internal_network_cidr
        },
        "calico-vxlan" = {
          direction        = "ingress"
          protocol         = "udp"
          port_range_min   = 4789
          port_range_max   = 4789
          remote_ip_prefix = local.internal_network_cidr
        }
    }
  },
    "controller_sg" = {
      description = "SG that will be used only for controller"
      nodegroups  = ["controller"]
      rules_ipv4 = {
        "etcd" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 2380
          port_range_max   = 2380
          remote_ip_prefix = local.internal_network_cidr
        },
        "kube-api" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 6443
          port_range_max   = 6443
          remote_ip_prefix = "0.0.0.0/0" 
        },
        "k0s-controller-join-api" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 9443
          port_range_max   = 9443
          remote_ip_prefix = local.internal_network_cidr
        }
      }
    },
    "workers_sg" = {
      description = "SG that will be used only for workers"
      nodegroups  = ["worker"]
      rules_ipv4 = {
        "bgp" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 179
          port_range_max   = 179
          remote_ip_prefix = local.internal_network_cidr
        }
      }
    }
  }


  ng_user_data = { for k, v in var.nodegroups : k => "#cloud-config\nusers:\n  - name: ${v.user}\n    sudo: ALL=(ALL) NOPASSWD:ALL\n    groups: docker\n    ssh_authorized_keys:\n      - ${module.key.keypair.public_key}\n"
  }
  
}

module "provision" {
  source = "../../"
  
  name = var.name
  securitygroups = { for k, sg in local.securitygroups : k => {
    description = sg.description
    nodegroups = sg.nodegroups
    rules_ipv4 = sg.rules_ipv4
    }
  }

  networks = { for k, net in var.networks : k => {
    nodegroups = net.nodegroups
    subnets = net.subnets
    }
  }
  
  nodegroups = { for k, ngd in var.nodegroups: k => {
    source_image = ngd.source_image
    keypair = "${var.name}-kp"
    flavor = ngd.flavor
    count = ngd.count
    role = ngd.role
    public = ngd.public
    user_data = local.ng_user_data[k]
    }
  }
  
  external_network = {
    id       = var.external_network.id
    fip_pool = var.external_network.fip_pool
  }
  
  ingresses = { for k, ing in local.ingresses : k => {
    nodegroups = ing.nodegroups
    network_name = ing.network_name
    public = ing.public
    listeners = ing.listeners
    }
  }

}
