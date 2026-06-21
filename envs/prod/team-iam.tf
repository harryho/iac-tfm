# --------------------------------------------------------------------------
# Team IAM — groups, users, OIDC roles
# --------------------------------------------------------------------------
module "team_iam" {
  source = "../../modules/team-iam"

  project_name           = var.project_name
  role_name_prefix       = var.role_name_prefix
  oidc_environment       = var.oidc_environment != "" ? var.oidc_environment : var.environment_name
  team_members           = var.team_members
  enable_mfa_enforcement = true
  github_org             = var.github_org
  github_repo            = var.github_repo
  common_tags            = local.common_tags
}
