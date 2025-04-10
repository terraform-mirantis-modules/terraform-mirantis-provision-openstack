locals {

  internal_network_cidr = var.networks["internal-network"].subnets["subnet_1"].cidr

  securitygroups = {
  
    "common_sg" = {
      description = "SG that will be used for both managers and workers"
      nodegroups  = ["managers", "workers"]
      rules_ipv4 = {
        "ssh" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 22
          port_range_max   = 22
          remote_ip_prefix = "0.0.0.0/0"
        },
        "kubelet_api" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 10250
          port_range_max   = 10250
          remote_ip_prefix = local.internal_network_cidr
        },
        "bgp-peers" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 179
          port_range_max   = 179
          remote_ip_prefix = local.internal_network_cidr
        },
        "overlay" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 4789
          port_range_max   = 4789
          remote_ip_prefix = local.internal_network_cidr
        },
        "gossip-tcp" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 7946
          port_range_max   = 7946
          remote_ip_prefix = local.internal_network_cidr
        },
        "gossip-udp" = {
          direction        = "ingress"
          protocol         = "udp"
          port_range_min   = 7946
          port_range_max   = 7946
          remote_ip_prefix = local.internal_network_cidr
        },
        "calico-node-metrics" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 9091
          port_range_max   = 9091
          remote_ip_prefix = local.internal_network_cidr
        },
        "ucp-node-exporter-metrics" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 9100
          port_range_max   = 9100
          remote_ip_prefix = local.internal_network_cidr
        },
        "tls-auth-proxy-mcr" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 12376
          port_range_max   = 12376
          remote_ip_prefix = local.internal_network_cidr
        }
    }
  },
    "managers_sg" = {
      description = "SG that will be used only for managers"
      nodegroups  = ["managers"]
      rules_ipv4 = {
        "swarm-manager" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 2376
          port_range_max   = 2376
          remote_ip_prefix = local.internal_network_cidr
        },
        "swarm-communication" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 2377
          port_range_max   = 2377
          remote_ip_prefix = local.internal_network_cidr
        },
        "kube-api" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 6443
          port_range_max   = 6443
          remote_ip_prefix = "0.0.0.0/0" 
        },
        "ucp-rethinkdb-exporter-metrics" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 9055
          port_range_max   = 9055
          remote_ip_prefix = local.internal_network_cidr
        },
        "managers-port-range" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 12379
          port_range_max   = 12392
          remote_ip_prefix = local.internal_network_cidr
        }
      }
    }
  }


  ng_user_data = { for k, v in var.nodegroups : k => "#cloud-config\nusers:\n  - name: ${v.user}\n    sudo: ALL=(ALL) NOPASSWD:ALL\n    groups: docker\n    ssh_authorized_keys:\n      - ${module.key.keypair.public_key}"
  }
  
}

module "provision" {
  source = "../"
  
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
