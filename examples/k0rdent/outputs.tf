locals {
  
  nodes_info = flatten([
    for k, ng in module.provision.nodegroups: [
      for node in ng.nodes : {
        name = node.name
        fip = node.floating_ip
        role = ng.role
        user = var.nodegroups[k].user
      }
    ]
  ])

  nodes_map = tomap({
    for item in local.nodes_info : "${item.name}" => {"fip" = "${item.fip}", "role" = "${item.role}", "user" = "${item.user}"}
  })

  hosts = [
    for k, v in tomap(local.nodes_map) : {
      ssh = {
            address = v.fip
            user    = v.user
            keyPath = local.pk_path
          }
          role = v.role

      }
  ]
 
  k0s_tmpl = {
    apiVersion = "k0sctl.k0sproject.io/v1beta1"
    kind       = "Cluster"
    spec = {
      hosts = local.hosts
      k0s = {
        version = "1.32.2+k0s.0"
        dynamicConfig = false
        config = {
          apiVersion = "k0s.k0sproject.io/v1beta1"
          kind = "ClusterConfig"
          metadata = {
            name = "${var.name}"
          }
          spec = {
            api = {
              extraArgs = {
                anonymous-auth = "true"
              }
              externalAddress = module.provision.ingresses["control_plane"].floating_ip
              sans = [
                module.provision.ingresses["control_plane"].floating_ip
              ]
            }
            network = {
              provider = "calico"
              calico = {
                mode = "vxlan"
              }
            }
            extensions = {
              helm = {
                repositories = [
                  {
                    name = "cpo"
                    url = "https://kubernetes.github.io/cloud-provider-openstack"
                  },
                ]
                charts = [
                  {
                    name = "openstack-ccm"
                    chartname = "cpo/openstack-cloud-controller-manager"
                    namespace = "kube-system"
                    version = "2.30.0"
                    order = 1
                    values = <<-EOT
                      nodeSelector:
                        node-role.kubernetes.io/control-plane: null
                        node-role.kubernetes.io/control-plane: "true"
                      tolerations:
                        - key: node-role.kubernetes.io/master
                          effect: NoSchedule
                        - key: node.cloudprovider.kubernetes.io/uninitialized
                          value: "true"
                          effect: NoSchedule
                      cloudConfig:
                        global:
                          application-credential-id: ${openstack_identity_application_credential_v3.cluster-api-creds.id}
                          application-credential-secret: ${openstack_identity_application_credential_v3.cluster-api-creds.secret}
                          auth-url: ${var.auth_url}
                        loadBalancer:
                          enabled: true
                          floating-network-id: ${var.external_network.id}
                          subnet-id: ${module.provision.subnets["${var.name}-internal-network-subnet_1"].id}
                    EOT
                  },
                  {
                    name = "cinder-csi"
                    chartname = "cpo/openstack-cinder-csi"
                    namespace = "kube-system"
                    order = 2
                    version = "2.30.0"
                    values = <<-EOT
                      csi:
                        plugin:
                          nodePlugin:
                            kubeletDir: /var/lib/k0s/kubelet
                      secret:
                        enabled: true
                        create: false
                        name: cloud-config
                      storageClass:
                        enabled: true
                        delete:
                          isDefault: true
                          allowVolumeExpansion: false
                    EOT
                  },
                  {
                    name = "k0rdent"
                    chartname = "oci://ghcr.io/k0rdent/kcm/charts/kcm"
                    namespace = "kcm-system"
                    order = 3
                    version = "0.2.0"
                    values = ""
                  }
                ]
              }
            }
            storage = {
              type = "etcd"
            }
            telemetry = {
              enabled = false
            }
          }
        }
      }
    }
  }
}

output "k0s_cluster" {
  value = replace(yamlencode(local.k0s_tmpl), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
  sensitive = true
}
