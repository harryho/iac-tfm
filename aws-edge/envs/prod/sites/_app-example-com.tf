# envs/prod/sites/_app-example-com.tf
#
# Subdomain app. Contact form enabled (for "contact us" page).
# Rename to app-example-com.tf to enable.
#
# Add to envs/prod/terraform.tfvars:
#
#   sites = {
#     app-example-com = {
#       domain              = "app.example.com"
#       enable_www_redirect = false
#       enable_contact_form = true
#     }
#   }
