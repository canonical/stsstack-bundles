data "openstack_identity_role_v3" "admin"{
  name = "admin"
}

data "openstack_identity_role_v3" "Member" {
  name = "Member"
}

resource "openstack_identity_role_v3" "ResellerAdmin" {
  name = "ResellerAdmin"
}

