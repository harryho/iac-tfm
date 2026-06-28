# aws-edge

The original AWS implementation of this multi-cloud Terraform templates
repo. CloudFront + S3 + ACM for static sites, Lambda + SES + DynamoDB
for per-site contact forms, IAM groups + OIDC roles for CI/CD, and an
ops baseline (CloudWatch dashboard, AWS Budget, SNS alerts).

> Repo-wide overview, ADRs, and contributor docs live one level up at
> [`/README.md`](../README.md) and [`/ARCHITECTURE.md`](../ARCHITECTURE.md).
> Everything below is scoped to AWS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![Terraform 1.10+](https://img.shields.io/badge/Terraform-1.10+-623CE4.svg)](https://www.terraform.io/)

## What you get

- **Multi-site, multi-environment** — directory-based envs (`envs/<env>/`),
  file-per-site, copy a working env to add another in one command
- **Static sites on AWS** — CloudFront + S3 (private, OAC) + ACM (us-east-1)
- **Per-site contact form** — Lambda + SES + DynamoDB, Cloudflare Turnstile
  optional
- **OIDC-only CI/CD** — no long-lived AWS keys, GitHub Environments map 1:1
  to folders
- **Safe teardown** — `scripts/teardown-env.sh` empties S3, destroys, and
  cleans up state in one command (with confirmation)
- **Ops baseline** — CloudWatch dashboard, AWS Budget, SNS alerts

## Quickstart

```bash
# 0. Prereqs (run from inside aws-edge/)
./scripts/prereqs.sh

# 1. Click "Use this template" on GitHub, then clone your new repo
git clone https://github.com/YOUR_ORG/iac-tfm.git
cd iac-tfm/aws-edge

# 2. Make it yours. The script prompts for:
#    project name, primary region, GitHub org, GitHub repo name,
#    primary domain, SES alert email.
#    It rewrites example.com, YOUR_ORG, YOUR_REPO, ap-southeast-2
#    across the tree.
./scripts/init-from-template.sh

# 3. Bootstrap state backend
cd bootstrap && terraform init && terraform apply
cd ..

# 4. Wire up prod
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # fill in your values
terraform init
terraform plan

# 5. Point DNS and finish setup. After first apply:
#    - ACM validation CNAMEs from `terraform output sites` → acm_validation_records
#    - DKIM CNAMEs from `terraform output ses_dkim_records`
#    - Site CNAMEs: <domain> → CloudFront distribution domain
#    - Confirm SNS alert email subscription (check inbox)
#    - Request SES production access in your region if not done
# Re-run `terraform plan` until ACM certs move to ISSUED.

# 6. Add CI/CD. Capture the OIDC role ARNs from `terraform output`:
#    - github_infra_role_arn, github_content_role_arn
#    In GitHub repo → Settings → Environments → production, add secrets:
#    - AWS_ROLE_ARN_PLAN_PROD, AWS_ROLE_ARN_APPLY_PROD
# Open a PR against main. The iac-plan.yml workflow should fire on the PR.

# 7. Deploy your first site
cd ../..
./scripts/deploy-site.sh prod example-com ./envs/prod/content/example-com/dist
./scripts/verify-site.sh prod example-com
```

## Layout

```
bootstrap/         S3 + DynamoDB state backend (run once per AWS account)
modules/           Reusable Terraform modules
envs/<env>/        Per-environment stacks (envs/prod ships by default)
scripts/           Helper shell scripts
.github/workflows/ CI/CD pipelines (OIDC, env-aware)
docs/decisions/    AWS-specific ADRs
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design.

## Add a new environment

```bash
./scripts/replicate-env.sh stage
# then edit envs/stage/terraform.tfvars, init, plan, apply
```

## Tear down an environment

```bash
./scripts/teardown-env.sh stage
./scripts/teardown-env.sh prod --force   # requires explicit --force for prod
```

## Known issues

The original implementation is the source of the multi-cloud split. An
audit from 2026-06-22 identified 11 real bugs and several AI-tell issues
that have **not** been fixed in this pass. The cleaner pattern lives at
[`/az-swa/`](../az-swa/) — when adding a new cloud, copy from there, not
from here.

## License

[MIT](../../LICENSE). No warranty; you own what you ship.

## Contributing

See [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Bug reports and feature
requests: use the issue templates in `.github/ISSUE_TEMPLATE/`.