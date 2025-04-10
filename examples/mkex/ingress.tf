locals {
  ingresses = {
    "control_plane" = {
      nodegroups   = ["managers"]
      network_name = "internal-network"
      public       = true
      listeners = {
        "443" = {
          protocol      = "TCP"
          protocol_port = 443
          target_port   = 443 
          lb_method     = "ROUND_ROBIN"
        },
      }
    }
  }
}
