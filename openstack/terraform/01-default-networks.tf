resource "openstack_networking_network_v2" "ext_net" {
  name           = "ext_net"
  admin_state_up = true
  shared         = true
  external       = true

  segments {
    physical_network = "physnet1"
    network_type     = var.net_type
  }
}

resource "openstack_networking_subnet_v2" "ext_net_subnet" {
  name        = "ext_net_subnet"
  network_id  = openstack_networking_network_v2.ext_net.id
  cidr        = var.cidr_ext"
  gateway_ip  = var.gateway
  enable_dhcp = false
  ip_version  = 4

  dns_nameservers = [ var.nameserver ]

  allocation_pool {
    start = var.fip_start
    end   = var.fip_end
  }
}

resource "openstack_networking_router_v2" "provider-router" {
  name                = "provider-router"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.ext_net.id
}

resource "openstack_networking_network_v2" "private" {
  name           = "private"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "private_subnet" {
  name       = "private_subnet"
  network_id = openstack_networking_network_v2.private.id
  cidr       = var.cidr_priv

}

resource "openstack_networking_router_interface_v2" "private_ext_route" {
  router_id = openstack_networking_router_v2.provider-router.id
  subnet_id = openstack_networking_subnet_v2.private_subnet.id
}
