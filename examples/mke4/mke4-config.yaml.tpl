# Full MKE 4k configuration (equivalent to mkectl init) with Terraform-provided hosts and apiServer.
# Use: terraform output -raw mkectl_config > mke4.yaml && mkectl apply -f mke4.yaml
apiVersion: mke.mirantis.com/v1alpha1
kind: MkeConfig
metadata:
  name: mke
  namespace: mke
spec:
  version: ${version}
  hosts:
${hosts_yaml}
  authentication:
    ldap:
      enabled: false
    oidc:
      enabled: false
    saml:
      enabled: false
  ingressController:
    enabled: true
    replicaCount: 2
  backup:
    enabled: true
    storage_provider:
      in_cluster_options:
        nodeport: 32100
      type: InCluster
  monitoring:
    enableOpscare: true
  tracking:
    enabled: false
  apiServer:
    externalAddress: ${api_server_external_address}
    sans:
%{for s in api_server_sans~}
    - ${s}
%{endfor~}
  network:
    providers:
      - enabled: true
        provider: calico
        extraConfig:
          values.yaml: |-
            kubeletVolumePluginPath: /var/lib/kubelet
            installation:
              flexVolumePath: /var/lib/kubelet/volumeplugins
    kubeProxy:
      disabled: false
      mode: iptables
      metricsBindAddress: 0.0.0.0:10249
      iptables:
        masqueradeAll: false
        syncPeriod: 0s
        minSyncPeriod: 0s
      ipvs:
        syncPeriod: 0s
        minSyncPeriod: 0s
        scheduler: ""
        excludeCIDRs: []
        strictARP: false
        tcpTimeout: 0s
        tcpFinTimeout: 0s
        udpTimeout: 0s
      nodePortAddresses: []
  registries:
    imageRegistry:
      url: ghcr.io/mirantiscontainers
    chartRegistry:
      url: oci://ghcr.io/mirantiscontainers
  k8sProviderSpecs:
    dataDir: /var/lib/k0s
