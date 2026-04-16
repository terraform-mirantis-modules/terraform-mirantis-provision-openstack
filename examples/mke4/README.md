# MKE 4k on OpenStack

This example provisions OpenStack infrastructure **tuned for [Mirantis Kubernetes Engine 4k (MKE 4k)](https://docs.mirantis.com/mke4k/latest/)** using the Terraform OpenStack provision module.

## What it does

- **Networks**: Internal network and subnet for controllers and workers.
- **Security groups**: Ports opened per [MKE 4k — Open Ports to Incoming Traffic](https://docs.mirantis.com/mke4k/latest/getting-started/open-ports-to-incoming-traffic/) (SSH, etcd 2380, kube-api 6443, k0s join 9443, kubelet 10250, Calico 4789/179/5473, konnectivity 8132, Ingress 33000/33001).
- **Load balancer**: Single TCP load balancer with:
  - **6443** → 6443 (Kubernetes API)
  - **9443** → 9443 (controller join API)
  - **443** → 33001 (Ingress Controller / MKE 4k Dashboard)

  As required by [MKE 4k system requirements](https://docs.mirantis.com/mke4k/latest/getting-started/system-requirements/).

- **Node groups**: `controller` and `worker` roles; flavors and counts are configurable.

## Requirements

- Terraform >= 0.14
- OpenStack provider ~> 1.53
- OpenStack: external network, image (e.g. Rocky Linux 9.4, RHEL 9.6/8.10, Ubuntu 24.04/22.04 per [MKE 4k docs](https://docs.mirantis.com/mke4k/latest/getting-started/system-requirements/)), flavors

## Usage

1. **Configure OpenStack provider** (env vars or a `terraform.tfvars` + provider config).

2. **Set variables** (e.g. `terraform.tfvars`):

```hcl
name = "mke4-demo"

networks = {
  "internal-network" = {
    nodegroups = ["controller", "worker"]
    subnets = {
      "subnet_1" = {
        cidr    = "10.0.0.0/24"
        private = false
      }
    }
  }
}

nodegroups = {
  "controller" = {
    source_image = "<openstack-image-id>"  # e.g. Rocky 9.4, Ubuntu 24.04
    keypair      = "mke4-demo-kp"
    flavor       = "<flavor-id>"          # 8GB RAM, 2 vCPUs min (16GB/4 vCPUs for upgrade path)
    count        = 3
    role         = "controller"
    public       = false
    user         = "cloud-user"            # or ubuntu, ec2-user depending on image
  }
  "worker" = {
    source_image = "<openstack-image-id>"
    keypair      = "mke4-demo-kp"
    flavor       = "<flavor-id>"          # 8GB RAM, 2 vCPUs min
    count        = 2
    role         = "worker"
    public       = false
    user         = "cloud-user"
  }
}

external_network = {
  id       = "<external-network-id>"
  fip_pool = "external"
}
```

3. **Plan and apply**:

```bash
terraform init
terraform plan
terraform apply
```

4. **Use outputs for MKE 4k**:
   - **`mkectl_config`** (recommended): full MKE 4k config (same structure as `mkectl init`) with Terraform-derived **hosts** and **apiServer** (externalAddress, sans). No need to run `mkectl init` or merge fragments.
     ```bash
     terraform output -raw mkectl_config > mke4.yaml
     mkectl apply -f mke4.yaml
     ```
     **Note:** Host addresses use nodes’ floating IPs when `public = true`; otherwise the private IP is used (run `mkectl` from a host that can reach those IPs).
   - `control_plane_address`: load balancer IP for reference.
   - `nodegroups`: raw node lists if you need to build or patch the config manually.

5. **Install MKE 4k** with `mkectl apply -f mke4.yaml` using the generated SSH key at `ssh_private_key_path`.

## MKE 4k references

- [MKE 4k Documentation](https://docs.mirantis.com/mke4k/latest/)
- [System requirements](https://docs.mirantis.com/mke4k/latest/getting-started/system-requirements/)
- [Open ports to incoming traffic](https://docs.mirantis.com/mke4k/latest/getting-started/open-ports-to-incoming-traffic/)
- [Create a cluster](https://docs.mirantis.com/mke4k/latest/getting-started/create-a-cluster/)

## Production Considerations

This chart is not intended for production use because it has firewalld and SELinux disabled by default. These security measures can be easily enabled by adjusting the corresponding variables in the Terraform configuration.