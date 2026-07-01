# --------------------------------------------------------------------------
# Team IAM — group bindings, service accounts, WIF for GitHub Actions
# --------------------------------------------------------------------------
module "team_iam" {
  source = "../../modules/team-iam"

  project_id        = var.project_id
  project_name      = var.project_name
  org_domain        = var.org_domain
  state_bucket_name = var.state_bucket_name
  github_org        = var.github_org
  github_repo       = var.github_repo
  github_envs       = var.github_envs
  enable_wif        = var.github_org != "" && var.github_repo != ""
  common_labels     = local.common_labels
}