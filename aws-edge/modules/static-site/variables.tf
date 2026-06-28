terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

variable "domain" {
  description = "Primary domain name (e.g. example.com)"
  type        = string
}

variable "enable_www_redirect" {
  description = "Redirect www.<domain> to <domain> via CloudFront Function"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = NA + EU only)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
