output "private_key" {
  description = "Private key contents"
  value       = tls_private_key.ed25519.private_key_openssh
}

output "keypair" {
  value = openstack_compute_keypair_v2.keypair
}
