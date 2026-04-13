# Load balancer for MKE 4k control plane and dashboard.
# Per docs: Listen 6443 (Kubernetes API), 9443 (controller join API), 443 -> 33001 (Ingress Controller / Dashboard).
# https://docs.mirantis.com/mke4k/latest/getting-started/system-requirements/

locals {
  ingresses = {
    "control_plane" = {
      nodegroups   = ["controller"]
      network_name = "internal-network"
      public       = true
      listeners = {
        "6443" = {
          protocol      = "TCP"
          protocol_port = 6443
          target_port   = 6443
          lb_method     = "ROUND_ROBIN"
        },
        "9443" = {
          protocol      = "TCP"
          protocol_port = 9443
          target_port   = 9443
          lb_method     = "ROUND_ROBIN"
        },
        "443" = {
          protocol      = "TCP"
          protocol_port = 443
          target_port   = 33001 # Ingress Controller HTTPS node port (MKE 4k Dashboard)
          lb_method     = "ROUND_ROBIN"
        }
      }
    }
  }
}
