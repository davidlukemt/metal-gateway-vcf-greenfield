 variable "auth_token" {
  type        = string
  description = "Your Equinix Metal API key (https://console.equinix.com/users/-/api-keys)"
  sensitive   = true
}

variable "project_id" {
  type        = string
  description = "Your Equinix Metal project ID, where you want to deploy your nodes to"
  sensitive   = true
}

variable "plan" {
  type        = string
  description = "Metal server type you plan to deploy"
  default     = "m3.large.x86"
}

variable "operating_system" {
  type        = string
  description = "OS you want to deploy"
  default     = ""
}

variable "billing_cycle" {
  type        = string
  description = "Desired Billing model"
  default     = "hourly"
}

variable "metro" {
  type        = string
  description = "Metal's Metro location you want to deploy your servers to"
  default     = "da"
}

variable "host_count" {
  type        = number
  description = "Number of MGW Attached ESXi VCF Instances to create"
  default     = 2
  /*validation {
    condition = var.mgw_subnet_size - 3 >= var.host_count
    error_message = "Too many hosts to fit in specified subnet size. Reduce host_count or increase mgw_subnet_size"
  }*/
}

variable "hostname_prefix" {
  type        = string
  description = "New instance hostname"
  default     = "vcfmgw"
}

variable "domain" {
  type        = string
  description = "New instances domain"
  default     = "lab"
}

variable "password" {
  type        = string
  description = "New instances root password"
}

variable "mgw_vlanid" {
  type        = string
  description = "Metal Gateway VLAN"
  default     = "99"
}

variable "private_vlanid" {
  type        = string
  description = "Private VLAN"
  default     = "900"
}

variable "dns" {
  type        = string
  description = "Initial DNS"
  default     = "1.1.1.1"
}

variable "ntp" {
  type        = string
  description = "Initial DNS"
  default     = "pool.ntp.org"
}

variable "mgw_subnet_size" {
  type        = number
  description = "Metal Gateway Subnet Size, must be 8+. 8=/29, 16=/28, 32=/27"
  default     = "8"
}