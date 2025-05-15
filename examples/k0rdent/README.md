# TF chart to deploy k0rdent on Openstack

## Prerequisites

You need to export environment variables that are needed to access Openstack cluster. More information on how to do it can be found [here](https://docs.openstack.org/newton/user-guide/common/cli-set-environment-variables-using-openstack-rc.html)

## Usage


1. Copy `terraform.tfvars.example` to `terraform.tfvars` and put variables there according to your environment and needs
2. Execute `terraform init`
3. Execute `terraform apply`
4. To provision k0rdent cluster, run `terraform output -raw k0s_cluster | k0sctl apply --config -`
5. To get kubeconfig for created cluster, run `terraform output -raw k0s_cluster | k0sctl kubeconfig --config -`
