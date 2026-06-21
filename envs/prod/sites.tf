# --------------------------------------------------------------------------
# Static sites — one module call per entry in var.sites
# --------------------------------------------------------------------------
module "static_site" {
  source   = "../../modules/static-site"
  for_each = var.sites

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain              = each.value.domain
  enable_www_redirect = try(each.value.enable_www_redirect, true)
  price_class         = try(each.value.price_class, "PriceClass_100")
  common_tags         = local.common_tags
}

# --------------------------------------------------------------------------
# Contact forms — one per site that has contact form enabled
# --------------------------------------------------------------------------
module "contact_form" {
  source = "../../modules/contact-form"
  for_each = {
    for k, v in var.sites : k => v if try(v.enable_contact_form, true)
  }

  site_domain      = each.value.domain
  recipient_email  = coalesce(each.value.recipient_email, var.alert_email)
  sender_email     = "noreply@${var.primary_domain}"
  ses_identity_arn = aws_ses_domain_identity.this.arn
  turnstile_secret = var.turnstile_secret
  alert_topic_arn  = aws_sns_topic.alerts.arn
  common_tags      = local.common_tags
}
