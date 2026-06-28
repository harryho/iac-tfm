# envs/prod/sites/_example-com.tf
#
# Apex marketing site. Rename to example-com.tf to enable.
# Underscore prefix = disabled (not picked up by Terraform).
#
# To enable: `mv _example-com.tf example-com.tf`
# To disable: `mv example-com.tf _example-com.tf`

# Add to envs/prod/terraform.tfvars:
#
#   sites = {
#     example-com = {
#       domain              = "example.com"
#       enable_www_redirect = true
#     }
#   }
