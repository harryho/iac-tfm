locals {
  contact_settings_for = {
    for k, v in var.sites : k => merge(
      {
        SITE_DOMAIN      = v.domain
        RECIPIENT_EMAIL  = coalesce(v.recipient_email, var.alert_email)
        SENDER_EMAIL     = "noreply@${var.primary_domain}"
        TURNSTILE_SECRET = var.turnstile_secret
        SES_REGION       = var.ses_region
      },
      var.acs_connection_string != "" ? { ACS_CONNECTION_STRING = var.acs_connection_string } : {},
      var.ses_access_key != "" ? { SES_ACCESS_KEY = var.ses_access_key, SES_SECRET_KEY = var.ses_secret_key } : {},
    ) if v.enable_contact_form
  }
}

module "static_hosting" {
  source   = "../../modules/static-hosting"
  for_each = var.sites

  resource_group_name = azurerm_resource_group.main.name
  azure_location      = var.azure_location
  domain              = each.value.domain

  app_settings = lookup(local.contact_settings_for, each.key, {})
}