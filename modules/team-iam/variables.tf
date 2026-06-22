variable "project_name" {
  description = "Project name used for IAM group naming and path scoping"
  type        = string
  default     = "iac-tfm"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens."
  }
}

variable "role_name_prefix" {
  description = "Prefix for OIDC role names (e.g. 'iac-prod', 'iac-stage'). Must be unique per env in the same AWS account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.role_name_prefix))
    error_message = "role_name_prefix must be lowercase alphanumeric with hyphens."
  }
}

variable "oidc_environment" {
  description = "GitHub Environment name to constrain the OIDC trust policy to (e.g. 'production', 'staging'). Workflows must run in this environment to assume the role."
  type        = string
  default     = ""
}

variable "team_members" {
  description = "Team members to create. Each must specify name and role (admin, developer, or tester)."
  type = list(object({
    name  = string
    role  = string
    email = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for m in var.team_members : contains(["admin", "developer", "tester"], m.role)
    ])
    error_message = "role must be one of: admin, developer, tester."
  }
}

variable "enable_mfa_enforcement" {
  description = "Require MFA for admin destructive actions"
  type        = bool
  default     = true
}

variable "enable_console_login" {
  description = "Create console login profiles for team members (passwords stored in state)"
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub org/username for OIDC trust (leave empty to skip CI roles)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo name for OIDC trust (leave empty to skip CI roles)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
