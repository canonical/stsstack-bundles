variable "domain_id" {
  type    = string
  default = ""
}

variable "cloud" {
  type    = string
  default = ""
}

variable "nameserver" {
  type = string
  default = "10.230.64.2"
}

variable "swift_ip" {
  type = string
  default = "10.230.19.58"
}

variable "gateway" {
  type = string
  defaut = "10.5.0.1"
}

variable "cidr_ext" {
  type = string
  default = "10.5.0.0/16"
}

variable "fip_start" {
  type = string
  default = "10.5.150.0"
}

variable "fip_end" {
  type = string
  default = "10.5.200.254"
}

variable "cidr_priv" {
  type = string
  default = "192.168.21.0/24"
}

variable "net_type" {
  type = string
  default = "vxlan"
}

variable "os_username" {
  type = string
  default = "admin"
}

variable "os_user_domain_name" {
  type = string
  default = "admin_domain"
}

variable "os_project_name" {
  type = string
  default = "admin"
}

variable "os_project_domain_name" {
  type = string
  default = "admin_domain"
}

variable "os_password" {
  type = string
  default = "openstack"
}
