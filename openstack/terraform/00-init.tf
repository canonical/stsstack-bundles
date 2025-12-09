terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.49.0"
    }
  }
}

provider "openstack" {
  user_name           = var.os_username
  user_domain_name    = var.os_user_domain_name
  project_domain_name = var.os_project_domain_name
  password            = var.os_password
  auth_url            = var.auth_url
  region              = "RegionOne"
}
