# iac-tfm

> IaC Repo based on Terraform — a public template for hosting static sites on AWS
> with OIDC-based CI/CD, per-site contact forms, and an ops baseline.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
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

See [`GETTING_STARTED.md`](GETTING_STARTED.md) for the full step-by-step.

```bash
# 0. Prereqs
./scripts/prereqs.sh

# 1. Click "Use this template" on GitHub, then clone your new repo
git clone https://github.com/YOUR_ORG/iac-tfm.git
cd iac-tfm

# 2. Make it yours
./scripts/init-from-template.sh

# 3. Bootstrap state backend
cd bootstrap && terraform init && terraform apply
cd ..

# 4. Wire up prod
cd envs/prod
terraform init
terraform plan

# 5. After manual DNS setup, deploy content
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

## License

[MIT](LICENSE). No warranty; you own what you ship.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Bug reports and feature
requests: use the issue templates in `.github/ISSUE_TEMPLATE/`.