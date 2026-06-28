# Getting Started — AWS (aws-edge)

This walkthrough takes you from a fresh template fork to a deployed site
with CI/CD pipelines running. Follow it start-to-finish the first time;
after that each step has a reference you can jump to.

**Time estimate:** 30–45 minutes (plus DNS propagation).

---

## Prerequisites

Tools installed on your machine:

- [git](https://git-scm.com/)
- [Terraform 1.10+](https://developer.hashicorp.com/terraform/install)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  configured with an **administrator-equivalent** profile (used only during
  bootstrapping — CI/CD uses OIDC with no long-lived keys)
- [jq](https://jqlang.org/download/)
- [curl](https://curl.se/)
- [openssl](https://www.openssl.org/)
- [GitHub CLI `gh`](https://cli.github.com/) (authenticated)

Verify everything:

```bash
for cmd in git terraform aws jq curl openssl gh; do
  command -v $cmd >/dev/null && echo "✓ $cmd" || echo "✗ $cmd — install it"
done
```

---

## Step 1 — Fork and clone

Click **"Use this template"** on the
[iac-tfm](https://github.com/<owner>/iac-tfm) GitHub repo to create your
own copy. Then clone it:

```bash
git clone https://github.com/YOUR_ORG/iac-tfm.git
cd iac-tfm/aws-edge
```

---

## Step 2 — Initialize the template

The `init-from-template.sh` script replaces placeholders (`example.com`,
`YOUR_ORG`, `YOUR_REPO`, `ap-southeast-2`) across every file with your
real values.

```bash
./scripts/init-from-template.sh
```

It will prompt you for:

| Prompt | What to enter | Example |
|---|---|---|
| Project name | Lowercase, alphanumeric + hyphens | `my-project` |
| Primary AWS region | Your deployment region | `us-east-1` |
| GitHub org/user | Your GitHub account or org | `my-org` |
| GitHub repo name | Must match the repo you cloned | `iac-tfm` |
| Primary domain | The domain all sites live under | `mycompany.com` |
| SES alert email | (Optional) Ops email for alerts | `ops@mycompany.com` |

After the script finishes, commit the changes:

```bash
git add -A
git commit -m "init: replace placeholders with real values"
git push
```

> **What it touches:** all `.tf`, `.md`, `.yml`, `.sh`, and `.tfvars` files
> (excluding `.git/`). It does **not** uncomment the backend block or
> enable sites — you do those manually in the next steps.

---

## Step 3 — Bootstrap the state backend

This is a **one-time** step per AWS account. It creates an S3 bucket
(for Terraform state) and a DynamoDB table (for state locking).

```bash
cd bootstrap
terraform init
terraform apply   # type "yes" when prompted
cd ..
```

After it finishes, capture the outputs — you'll need them in step 4:

```bash
terraform -chdir=bootstrap output
```

Expected output (values will differ):

```
state_bucket_name = "my-project-tfstate-123456789012"
state_table_name  = "my-project-tfstate-lock"
state_region      = "ap-southeast-2"
```

---

## Step 4 — Configure the remote backend

The environment's `main.tf` has the backend block **commented out** by
default. You need to uncomment it and fill in the bootstrap outputs.

Open `envs/prod/main.tf` and find the commented block (lines ~11–23):

```hcl
# backend "s3" {
#   bucket         = "my-project-tfstate-123456789012"
#   key            = "envs/prod/terraform.tfstate"
#   region         = "ap-southeast-2"
#   dynamodb_table = "my-project-tfstate-lock"
# }
```

Uncomment it and replace the bucket and region values with what
`terraform -chdir=bootstrap output` showed you:

```hcl
backend "s3" {
  bucket         = "my-project-tfstate-123456789012"   # ← your bucket name
  key            = "envs/prod/terraform.tfstate"
  region         = "ap-southeast-2"                     # ← your region
  dynamodb_table = "my-project-tfstate-lock"            # ← your table name
}
```

**Why this matters:** without the backend block, `terraform apply` stores
state locally. The next person to run it won't see any existing resources
and will try to create everything again. CI/CD also won't find the state.

Commit this change:

```bash
git add -A
git commit -m "configure remote backend for prod"
git push
```

---

## Step 5 — Configure and deploy the prod environment

### 5a — Create your tfvars file

```bash
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values. At minimum:

- **`primary_domain`** — the apex domain (e.g. `mycompany.com`)
- **`alert_email`** — an email address for SNS alerts (you'll confirm the
  subscription in step 6)
- **`sites`** — one or more site entries. Each entry has a `domain` and
  optional settings. The three example sites are shown; delete or add as
  needed.
- **`github_org`** and **`github_repo`** — these were already replaced by
  `init-from-template.sh`, but double-check they match your fork.

### 5b — Enable your first site

Sites are enabled in two parts:

1. **Rename the site file** — remove the underscore prefix so Terraform
   picks it up:
   ```bash
   mv sites/_example-com.tf sites/example-com.tf
   ```
2. **Add the site to `terraform.tfvars`** — make sure the `sites` map
   has an entry matching the file name:
   ```hcl
   sites = {
     example-com = {
       domain = "mycompany.com"
     }
   }
   ```

Both parts are required. The underscore-prefix convention lets you keep
disabled site configs in version control without Terraform processing
them.

### 5c — Deploy

```bash
terraform init
terraform plan
```

Review the plan. It should show resources being **created** (green `+`
prefix). If it shows `changes` or `destroy`, stop and investigate.

```bash
terraform apply   # type "yes" when prompted
cd ../..
```

**First apply usually succeeds** but DNS validation (ACM certificates)
may take 10–30 minutes to complete. The next step covers what to do
while that propagates.

---

## Step 6 — DNS setup

After `terraform apply` completes, three types of DNS records are needed.
Terraform outputs the values:

```bash
terraform -chdir=envs/prod output
```

### 6a — ACM validation CNAMEs

From the `sites` output, each site has `acm_validation_records`. Add
these CNAME records at your DNS provider (one per site).

```bash
terraform -chdir=envs/prod output -json sites
```

The validation records look like:

```
_abc123def456.example.com. → _xyz789...acm-validations.aws.
```

After adding them, Terraform will detect the certificates as **issued**
on the next `terraform plan`. This can take 10–30 minutes.

### 6b — DKIM CNAMEs for SES

From the `ses_dkim_records` output:

```bash
terraform -chdir=envs/prod output -json ses_dkim_records
```

Add each record at your DNS provider so SES can send email on your
domain (required for the contact form).

### 6c — Site CNAMEs

Point each site's domain to the CloudFront distribution:

```
mycompany.com   → d1234abcdef8.cloudfront.net
```

Create a CNAME (or ALIAS/ANAME at the apex) at your DNS provider.

### 6d — Confirm SNS subscription

Check the inbox of `alert_email` for a subscription confirmation from
AWS Notifications. Click the confirm link — otherwise SNS alerts
(budget, Lambda errors) will bounce.

### 6e — Request SES production access

By default SES is in sandbox mode (can only send to verified addresses).
Open the AWS Console → SES → Sending Statistics → **Request production
access**. This takes a few hours to approve — do it early.

---

## Step 7 — Set up CI/CD

CI/CD runs in GitHub Actions using OIDC — no long-lived AWS keys.

### 7a — Create GitHub Environments

Go to your repo → **Settings → Environments → New environment**.

Create **two** environments:

| Environment name | Used by |
|---|---|
| `production` | `iac-plan.yml` and `iac-apply.yml` |
| `teardown-prod` | `iac-teardown.yml` (manual trigger) |

Add **required reviewers** to `production` if you want approval gates
on apply.

### 7b — Capture OIDC role ARNs

```bash
terraform -chdir=envs/prod output github_infra_role_arn
terraform -chdir=envs/prod output github_content_role_arn
```

### 7c — Set GitHub secrets

For each environment (`production`), add these secrets:

| Secret name | Value |
|---|---|
| `AWS_ROLE_ARN_PLAN_PROD` | `github_infra_role_arn` output |
| `AWS_ROLE_ARN_APPLY_PROD` | `github_infra_role_arn` output |
| `TFVARS_PROD` | Contents of your `envs/prod/terraform.tfvars` (base64-encoded) |

The plan workflow reads `TFVARS_PROD` and writes it as `terraform.tfvars`
before each run, so the CI runner always has the correct variables.

Set them via the GitHub UI (Settings → Environments → production → Secrets),
or via the CLI:

```bash
gh secret set AWS_ROLE_ARN_PLAN_PROD --env production \
  --body "$(terraform -chdir=envs/prod output -raw github_infra_role_arn)"
gh secret set AWS_ROLE_ARN_APPLY_PROD --env production \
  --body "$(terraform -chdir=envs/prod output -raw github_infra_role_arn)"
gh secret set TFVARS_PROD --env production \
  --body "$(base64 -w0 envs/prod/terraform.tfvars)"
```

---

## Step 8 — Test CI/CD

Push your current branch and open a Pull Request against `main`:

```bash
git add -A
git commit -m "chore: configure prod environment"
git push -u origin HEAD
```

On GitHub, open a PR. You should see:

1. **iac-plan.yml** trigger on the PR — runs `terraform fmt -check`,
   `terraform validate`, and `terraform plan`. Review the plan output
   in the PR comments.
2. **iac-lock-consistency.yml** trigger — verifies `.terraform.lock.hcl`
   hasn't drifted.

If the plan looks correct, merge the PR. The merge triggers:

3. **iac-apply.yml** on push to `main` — runs `terraform apply -auto-approve`.
4. **deploy-content.yml** — deploys static content (if any was
   committed to `envs/prod/content/`).

> **Troubleshooting:** If workflows fail with "not authorized to assume
> role", check that the `github_org` and `github_repo` values match your
> fork exactly. The OIDC trust policy is constrained to
> `repo:<org>/<repo>:environment:production`.

---

## Step 9 — Deploy site content

Place your built site files in the content directory:

```
envs/prod/content/example-com/dist/
├── index.html
├── assets/
└── ...
```

Then deploy:

```bash
./scripts/deploy-site.sh prod example-com ./envs/prod/content/example-com/dist
```

This syncs the files to S3 and creates a CloudFront invalidation.

Verify the deployment:

```bash
./scripts/verify-site.sh prod example-com
```

For contact-form sites, add `--with-contact-form`:

```bash
./scripts/verify-site.sh --with-contact-form prod example-com
```

---

## What's next

Now that your first env and site are live:

- **Add another site** — see [Expandable capabilities → Add a site](README.md#sites)
- **Add another environment** — see [Expandable capabilities → Add an environment](README.md#environments)
- **Tear down** — see the [teardown instructions](README.md#tear-down-an-environment)
- **Set up budgets and alerts** — check your AWS Budget in the console
  (created by the infra module)

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `terraform plan` shows all resources as `+ create` after a successful apply | Remote backend not configured (step 4 skipped) | Uncomment the backend block and run `terraform init -reconfigure` |
| ACM certificate stuck in "Pending validation" | DNS CNAME not added or hasn't propagated | Check the validation record at `whatsmydns.net` |
| CI workflow fails with "AccessDenied" on role assumption | `github_org` / `github_repo` mismatch, or environment name wrong | Verify OIDC trust policy and GitHub Environment name |
| Workflow runs but `terraform plan` shows no sites | `TFVARS_PROD` secret not set or has empty `sites` map | Check the secret value in GitHub → Settings → Environments |
| `scripts/deploy-site.sh` can't find the content directory | Path is relative to repo root, not script location | Use absolute path: `./scripts/deploy-site.sh prod example-com $(pwd)/envs/prod/content/example-com/dist` |
