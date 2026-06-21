variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = contains(["ap-southeast-2", "ap-southeast-4", "us-east-1"], var.aws_region)
    error_message = "aws_region must be ap-southeast-2, ap-southeast-4, or us-east-1."
  }
}

variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "iac-tfm"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens only."
  }
}
