resource "openstack_identity_application_credential_v3" "cluster-api-creds" {
  name        = "${var.name}-capi-creds"
  description = "${var.name} k0rdent cluster CAPI credentials"
  roles       = ["member", "load-balancer_member"]
  #roles       = ["member", "load-balancer_admin"]
  #  expires_at  = "2019-02-13T12:12:12Z"
}
