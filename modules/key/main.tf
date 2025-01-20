resource "tls_private_key" "ed25519" {
  algorithm = "ED25519"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = var.name
  public_key = tls_private_key.ed25519.public_key_openssh

}
