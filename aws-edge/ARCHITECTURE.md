# Architecture

## Layers

| Layer | Location | State | Run by |
|---|---|---|---|
| Bootstrap | `bootstrap/` | `s3://<bucket>/bootstrap/terraform.tfstate` | Once per AWS account |
| Environment | `envs/<env>/` | `s3://<bucket>/envs/<env>/terraform.tfstate` | Once per env |
| Module | `modules/<name>/` | (no state) | Called by envs |

`bootstrap/` is independent. `envs/<env>/` reads bootstrap outputs via
`terraform_remote_state`. Modules are pure code.

## Components

### `bootstrap/`
- S3 bucket for Terraform state (versioned, encrypted, lifecycle rules)
- DynamoDB table for state locking
- Outputs: backend config block + state bucket name

### `modules/static-site/`
- S3 bucket (private, OAC-only access)
- CloudFront distribution with OAC
- ACM certificate in `us-east-1` (required for CloudFront)
- Optional www → apex redirect via CloudFront Function
- Custom 404 page

### `modules/contact-form/`
- Lambda function (Node.js 20, SES + DynamoDB)
- Function URL (public, CORS locked to site domain)
- DynamoDB table for submission log
- CloudWatch log group + error alarm
- Optional Cloudflare Turnstile

### `modules/team-iam/`
- IAM groups (admin / developer / tester)
- IAM users from `team_members` variable
- Password policy + MFA enforcement
- OIDC roles for GitHub Actions (per-env via `role_name_prefix`)

### `envs/prod/`
- Wires the modules together for one environment
- Declares the SES domain identity (one per env)
- SNS alerts topic + email subscription
- CloudWatch dashboard
- AWS Budget

## State

All state lives in S3 with DynamoDB locking. Bootstrap is at key
`bootstrap/terraform.tfstate`; each env is at `envs/<env>/terraform.tfstate`.

Destroying an env: see `scripts/teardown-env.sh`.

## CI/CD

Five GitHub Actions workflows, all OIDC:

- `iac-plan.yml` — PR plan against every stack
- `iac-apply.yml` — apply on main, gated by GitHub Environment
- `deploy-content.yml` — content sync, matrix over env+site
- `iac-test.yml` — `terraform test` on every PR
- `iac-teardown.yml` — manual env destroy, gated by `teardown-<env>`

Secrets naming: `AWS_ROLE_ARN_PLAN_<ENV>` and `AWS_ROLE_ARN_APPLY_<ENV>`
(uppercased env name).

## Tagging

Every resource has:
```
Project   = "iac-tfm"
Env       = "<env_name>"
Owner     = "platform-team"
ManagedBy = "terraform"
Site      = "<domain>"   # for per-site resources
```