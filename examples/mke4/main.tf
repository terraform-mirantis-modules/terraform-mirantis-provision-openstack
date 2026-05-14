# MKE 4k example: OpenStack infrastructure tuned for Mirantis Kubernetes Engine 4k.
# See https://docs.mirantis.com/mke4k/latest/

locals {
  internal_network_cidr = var.networks["internal-network"].subnets["subnet_1"].cidr

  # Default: single security group with full TCP+UDP ingress (typical for lab / troubleshooting).
  # Restrictive rules from MKE 4k docs are preserved below (commented) for production hardening.
  securitygroups = {
    "permissive_sg" = {
      description = "Allow all TCP, UDP and IPIP ingress (use restrictive rules in production)"
      nodegroups  = ["controller", "worker"]
      rules_ipv4 = {
        "all-tcp" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 1
          port_range_max   = 65535
          remote_ip_prefix = "0.0.0.0/0"
        }
        "all-udp" = {
          direction        = "ingress"
          protocol         = "udp"
          port_range_min   = 1
          port_range_max   = 65535
          remote_ip_prefix = "0.0.0.0/0"
        }
        # Calico uses IP-in-IP encapsulation (IP protocol 4, not TCP/UDP) for cross-node
        # pod-to-pod traffic. Without this rule, Neutron port security silently drops IPIP
        # packets between nodes, breaking the pod overlay network for any cross-node
        # communication. Concretely: the kube-apiserver cannot reach webhook pods scheduled
        # on a different node, causing Helm operations that trigger admission webhooks
        # (e.g. cert-manager, k0rdent's kcm HelmRelease upgrade) to time out. The symptom
        # is mkectl's 'Setup K0rdent' phase hanging for 15+ minutes and failing with
        # 'context deadline exceeded' even though all nodes show Ready in kubectl.
        # port_range_min/max must be 0 for non-TCP/UDP protocols (Neutron ignores them).

        "ipip" = {
          direction        = "ingress"
          protocol         = "4"
          port_range_min   = 0
          port_range_max   = 0
          remote_ip_prefix = "0.0.0.0/0"
        }

      }
    }
  }

  /*
  # Security groups per MKE 4k docs: Open Ports to Incoming Traffic
  # https://docs.mirantis.com/mke4k/latest/getting-started/open-ports-to-incoming-traffic/
  securitygroups_restrictive = {
    "common_sg" = {
      description = "SG for both controllers and workers (MKE 4k)"
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
        },
        "calico-bgp" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 179
          port_range_max   = 179
          remote_ip_prefix = local.internal_network_cidr
        },
        "calico-typha" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 5473
          port_range_max   = 5473
          remote_ip_prefix = local.internal_network_cidr
        }
      }
    },
    "controller_sg" = {
      description = "SG for MKE 4k controller nodes"
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
        },
        "ingress-http" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 33000
          port_range_max   = 33000
          remote_ip_prefix = "0.0.0.0/0"
        },
        "ingress-https" = {
          direction        = "ingress"
          protocol         = "tcp"
          port_range_min   = 33001
          port_range_max   = 33001
          remote_ip_prefix = "0.0.0.0/0"
        }
      }
    },
    "workers_sg" = {
      description = "SG for MKE 4k worker nodes"
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
  */

  # Base cloud-config for every node; optional SELinux disable (includes deferred reboot) and extra YAML from variables.
  ng_user_data = {
    for k, v in var.nodegroups : k => join("", [
      <<-EOT
#cloud-config
users:
  - name: ${v.user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: docker
    ssh_authorized_keys:
      - ${module.key.keypair.public_key}

EOT
      ,
      var.disable_selinux ? <<-EOT
runcmd:
  - systemctl disable --now firewalld || true
  - setenforce 0 || true
  - sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config || true
  - reboot

EOT
      : ""
      ,
      var.cloud_init_extra != null && trimspace(var.cloud_init_extra) != "" ? "${trimspace(var.cloud_init_extra)}\n" : ""
    ])
  }
}

module "provision" {
  source = "../../"

  name = var.name

  securitygroups = {
    for k, sg in local.securitygroups : k => {
      description  = sg.description
      nodegroups   = sg.nodegroups
      rules_ipv4   = sg.rules_ipv4
    }
  }

  networks = {
    for k, net in var.networks : k => {
      nodegroups = net.nodegroups
      subnets    = net.subnets
    }
  }

  nodegroups = {
    for k, ngd in var.nodegroups : k => {
      source_image = ngd.source_image
      keypair      = try(ngd.keypair, "${var.name}-kp")
      flavor       = ngd.flavor
      count        = ngd.count
      role         = ngd.role
      public       = ngd.public
      user_data    = local.ng_user_data[k]
    }
  }

  external_network = {
    id       = var.external_network.id
    fip_pool = var.external_network.fip_pool
  }

  ingresses = {
    for k, ing in local.ingresses : k => {
      nodegroups   = ing.nodegroups
      network_name = ing.network_name
      public       = ing.public
      listeners    = ing.listeners
    }
  }
}


# Deploy system-upgrade-controller manifests on every controller node when the cluster
# uses bootc-based images.  k0s watches /var/lib/k0s/manifests/ and auto-applies all
# YAML files it finds there on startup, so placing SUC here before mkectl runs ensures
# the controller is present from the first time k0s comes up.
resource "null_resource" "suc_manifests" {
  # count is a static variable value — known at plan time; no for_each/sensitive-value issue.
  count = var.is_bootc_based ? var.nodegroups["controller"].count : 0

  connection {
    type = "ssh"
    # floating_ip is non-null for public=true nodes; fall back to fixed IP for private nodes.
    host = nonsensitive(coalesce(
      module.provision.nodegroups["controller"].nodes[count.index].floating_ip,
      try(module.provision.nodegroups["controller"].nodes[count.index].network[0].fixed_ip_v4, "")
    ))
    user        = var.nodegroups["controller"].user
    private_key = module.key.private_key
    port        = 22
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/k0s/manifests/system-upgrade",
      "curl -fsSL https://github.com/rancher/system-upgrade-controller/releases/download/v0.19.2/crd.yaml | sudo tee /var/lib/k0s/manifests/system-upgrade/crd.yaml > /dev/null",
      "curl -fsSL https://github.com/rancher/system-upgrade-controller/releases/download/v0.19.2/system-upgrade-controller.yaml | sudo tee /var/lib/k0s/manifests/system-upgrade/system-upgrade-controller.yaml > /dev/null",
    ]
  }

  depends_on = [
    module.provision,
    local_sensitive_file.ssh_private_key,
  ]
}