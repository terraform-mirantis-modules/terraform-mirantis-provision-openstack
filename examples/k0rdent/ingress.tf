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
        "8132" = {
          protocol      = "TCP"
          protocol_port = 8132
          target_port   = 8132 
          lb_method     = "ROUND_ROBIN"
        },
        "9443" = {
          protocol      = "TCP"
          protocol_port = 9443
          target_port   = 9443 
          lb_method     = "ROUND_ROBIN"
        },
      }
    }
  }
}
