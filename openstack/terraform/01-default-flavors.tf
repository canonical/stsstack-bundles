resource "openstack_compute_flavor_v2" "m1_tiny" {
  name      = "m1.tiny"
  ram       = "512"
  vcpus     = "1"
  disk      = "1"
  flavor_id = "1"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_small" {
  name      = "m1.small"
  ram       = "2048"
  vcpus     = "1"
  disk      = "20"
  flavor_id = "2"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_medium" {
  name      = "m1.medium"
  ram       = "4096"
  vcpus     = "2"
  disk      = "20"
  flavor_id = "3"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_large" {
  name      = "m1.large"
  ram       = "8192"
  vcpus     = "4"
  disk      = "20"
  flavor_id = "4"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_xlarge" {
  name      = "m1.xlarge"
  ram       = "16384"
  vcpus     = "4"
  disk      = "20"
  flavor_id = "5"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_cirros" {
  name      = "m1.cirros"
  ram       = "64"
  vcpus     = "1"
  disk      = "1"
  flavor_id = "6"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_tempest" {
  name      = "m1.tempest"
  ram       = "256"
  vcpus     = "1"
  disk      = "0"
  flavor_id = "7"
  is_public = true
}

resource "openstack_compute_flavor_v2" "m2_tempest" {
  name      = "m2.tempest"
  ram       = "512"
  vcpus     = "1"
  disk      = "0"
  flavor_id = "8"
  is_public = true
}
