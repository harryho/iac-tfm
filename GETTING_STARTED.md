# Getting Started

This guide walks you from a fresh clone of this template to a live HTTPS
site. Estimated time for a first-time user: **30-60 minutes**, mostly
waiting for ACM certificate validation.

## 0. Before you start

Run the prereqs check:

```bash
./scripts/prereqs.sh
```

You need: `aws` (v2), `terraform` (>= 1.10), `gh` (authenticated), `jq`,
`openssl`, and `bash` (>= 4).

You'll also need:
- An AWS account with admin access
- A domain you control (e.g. `example.com`)
- A GitHub repo (created from this template)

## 1. Get the template

Click the green **"Use this template"** button on GitHub, then clone your
new repo:

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO
```

## 2. Make it yours

```bash
./scripts/init-from-template.sh
```

The script will prompt for:
- project name (used in resource naming and tags)
- AWS account ID
- primary region
- GitHub org / repo
- primary domain (e.g. `example.com`)
- SES notification email
- GitHub Environment name (e.g. `production`)

It will rewrite all `example.com`, `YOUR_ORG`, `YOUR_ACCOUNT_ID`
placeholders across the repo. Idempotent — refuses to run if already
substituted.

After it finishes, edit `envs/prod/sites/_example-com.tf` (drop the
underscore prefix) to enable the first site.

## 3. Bootstrap the state backend

```bash
cd bootstrap
terraform init
terraform apply
cd ..
```

Captures the S3 bucket name and DynamoDB lock table name.

## 4. Wire up the prod environment

```bash
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # fill in your values
terraform init
terraform plan
```

Expect: ACM certificates requested, CloudFront distributions created.

## 5. Point DNS

In your registrar, add:
- ACM validation CNAMEs (from `terraform output` → `acm_validation_records`)
- Apex + `www` ALIAS / CNAME → your CloudFront distribution domain

Re-run `terraform plan` periodically until certs move to `ISSUED`.

## 6. Add CI/CD

Apply the team-iam module (already part of step 4). Capture the OIDC
role ARNs from `terraform output`:

- `github_infra_role_arn_<env>`
- `github_content_role_arn_<env>`

In your GitHub repo → Settings → Environments → `production`, add secrets:
- `AWS_ROLE_ARN_PLAN_PROD`
- `AWS_ROLE_ARN_APPLY_PROD`

Push a commit. The `iac-plan.yml` workflow should fire.

## 7. Deploy your first site

```bash
cd envs/prod
# Drop real content into content/example-com/dist/
git add content/example-com/
git commit -m "feat(content): add example.com landing page"
git push
```

The `deploy-content.yml` workflow syncs to S3 and invalidates CloudFront.

Verify:

```bash
./scripts/verify-site.sh prod example-com
```

## 8. Add another environment

```bash
./scripts/replicate-env.sh stage
# Edit envs/stage/terraform.tfvars
cd envs/stage
terraform init
terraform plan
```

Create a matching GitHub Environment named `staging` with the
`AWS_ROLE_ARN_PLAN_STAGE` and `AWS_ROLE_ARN_APPLY_STAGE` secrets.

## 9. Add a second site within an env

```bash
cp envs/prod/sites/_app-example-com.tf envs/prod/sites/_app-your-domain.tf
$EDITOR envs/prod/sites/_app-your-domain.tf   # change domain, content path
```

PR → plan reviews the diff → merge → apply.

## 10. Tear down an environment

```bash
./scripts/teardown-env.sh stage
./scripts/teardown-env.sh prod --force
```

The script empties S3, runs `terraform destroy`, and cleans up state.