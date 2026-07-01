# --------------------------------------------------------------------------
# Static sites — one module call per entry in var.sites
# --------------------------------------------------------------------------
module "static_site" {
  source   = "../../modules/static-site-cdn"
  for_each = var.sites

  site_key          = each.key
  domain            = each.value.domain
  bucket_prefix     = "${var.project_name}-${var.environment}"
  region            = var.region
  common_labels     = local.common_labels
  deployer_sa_email = module.team_iam.content_sa_email
}