
resource "openstack_identity_project_v3" "demo" {
  name        = "demo"
  domain_id   = var.domain_id
}

resource "openstack_identity_project_v3" "alt_demo" {
  name        = "alt_demo"
  domain_id   = var.domain_id
}

resource "openstack_identity_user_v3" "demo" {
  default_project_id = openstack_identity_project_v3.demo.id
  name               = "demo"
  domain_id          = var.domain_id
  password           = "pass"
  enabled            = true

  extra = {
    email = "demo@dev.null"
  }
}

resource "openstack_identity_user_v3" "alt_demo" {
  default_project_id = openstack_identity_project_v3.alt_demo.id
  name               = "alt_demo"
  domain_id          = var.domain_id
  password           = "secret"
  enabled            = true

  extra = {
    email = "alt_demo@dev.null"
  }
}

resource "openstack_identity_role_assignment_v3" "demo_user_role_member" {
  user_id    = openstack_identity_user_v3.demo.id
  project_id = openstack_identity_project_v3.demo.id
  role_id    = data.openstack_identity_role_v3.Member.id
}

resource "openstack_identity_role_assignment_v3" "alt_demo_user_role_member" {
  user_id    = openstack_identity_user_v3.alt_demo.id
  project_id = openstack_identity_project_v3.alt_demo.id
  role_id    = data.openstack_identity_role_v3.Member.id
}
