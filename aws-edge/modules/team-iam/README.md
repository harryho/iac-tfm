# team-iam

IAM groups, users, password policy, and per-env GitHub Actions OIDC roles.

## Usage

```hcl
module "team_iam" {
  source = "../../modules/team-iam"

  project_name    = "iac-tfm"
  role_name_prefix = "iac-prod"     # unique per env in same account
  oidc_environment = "production"   # matches the GitHub Environment name
  github_org      = "myorg"
  github_repo     = "my-iac-repo"
  team_members    = [
    { name = "alice", role = "admin", email = "alice@example.com" },
  ]
  enable_mfa_enforcement = true
  common_tags            = local.common_tags
}
```

## OIDC sub condition

The trust policy uses:

- `repo:${github_org}/${github_repo}:environment:${oidc_environment}:*` if
  `oidc_environment` is set
- `repo:${github_org}/${github_repo}:*` otherwise

This means workflows must run inside the matching GitHub Environment to
assume the role. Set `oidc_environment` to the GitHub Environment name
(production, staging, etc.) — usually the same as `environment_name`
in envs/<env>/.

## Placeholder guard

A `terraform_data` precondition fails the plan if `github_org` or
`github_repo` start with `YOUR_`. Replace the placeholders in
`envs/<env>/terraform.tfvars` before applying.

## Inputs / Outputs

See `variables.tf` and `outputs.tf`.
