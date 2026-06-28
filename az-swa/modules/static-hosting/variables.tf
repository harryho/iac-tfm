variable "domain" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "azure_location" {
  type = string
}

variable "app_settings" {
  type      = map(string)
  default   = {}
  sensitive = true
}