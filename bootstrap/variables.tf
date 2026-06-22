variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "iac-tfm"
}
