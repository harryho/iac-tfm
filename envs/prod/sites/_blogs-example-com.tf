# envs/prod/sites/_blogs-example-com.tf
#
# Subdomain blog. Contact form disabled by default.
# Rename to blogs-example-com.tf to enable.
#
# Add to envs/prod/terraform.tfvars:
#
#   sites = {
#     blogs-example-com = {
#       domain              = "blogs.example.com"
#       enable_www_redirect = false
#       enable_contact_form = false
#     }
#   }
