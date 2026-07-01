# Getting Started — GCP (gcp-edge)

This walkthrough takes you from a fresh template fork to a deployed site
with CI/CD pipelines running. Follow it start-to-finish the first time;
after that each step has a reference you can jump to.

**Time estimate:** 30–45 minutes (plus DNS propagation and SSL cert
provisioning).

---

## Prerequisites

Tools installed on your machine:

- [git](https://git-scm.com/)
- [Terraform 1.5+](https://developer.hashicorp.com/terraform/install)
- [Google Cloud CLI `gcloud`](https://cloud.google.com/sdk/docs/install)
  authenticated as a **project owner** (used only during bootstrapping;
  CI/CD uses Workload Identity Federation with no long-lived keys)
- [jq](https://jqlang.org/download/)
- [curl](https://curl.se/)
- [GitHub CLI `gh`](https://cli.github.com/) (authenticated)
- A GCP project you own (create one via
  [GCP Console](https://console.cloud.google.com/) — note the project ID)
- A Cloud Identity / Workspace org with admin access (for the
  team-iam groups)
- Your site domain registered at a DNS provider you control

Verify everything:

```bash
for cmd in git terraform gcloud jq curl gh; do
  command -v $cmd >/dev/null && echo "✓ $cmd" || echo "✗ $cmd — install it"
done

gcloud config get-value project   # should match your project ID
gcloud auth application-default print-access-token | head -c 20   # non-empty = OK
```

---

## Step 1 — Fork and clone

Click **"Use this template"** on the iac-tfm GitHub repo to create your
own copy. Then clone it:

```bash
git clone https://github.com/YOUR_ORG/iac-tfm.git
cd iac-tfm/gcp-edge
```

---

## Step 2 — Pick your values

Before any infrastructure exists, choose:

| What | Example | Notes |
|---|---|---|
| Project ID | `my-project-prod` | Must be globally unique, can't change later |
| Region | `us-central1` | Where resources live |
| Apex domain | `example.com` | The domain your sites live under (apex redirects to www) |
| Org domain | `example.org` | Cloud Identity domain for team groups |
| GitHub org | `my-org` | Your GitHub account or org |
| GitHub repo | `iac-tfm` | Must match the repo you cloned |

These will go into `bootstrap/terraform.tfvars` and `envs/prod/terraform.tfvars`.

---

## Step 3 — Bootstrap the state backend

This is a **one-time** step per GCP project. It enables required APIs
and creates a GCS bucket for Terraform state.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars   # set project_id, region, admin_email
terraform init
terraform plan
terraform apply   # type "yes" when prompted
cd ..
```

After it finishes, capture the outputs — you'll need them in the next step:

```bash
terraform -chdir=bootstrap output
```

Expected output (values will differ):

```
state_bucket_name = "gcp-edge-tfstate-my-project-prod"
project_id        = "my-project-prod"
region            = "us-central1"
```

---

## Step 4 — Configure the remote backend

The environment's `main.tf` has the backend block **hardcoded** to
match the bootstrap output. You need to edit the `bucket` value to
match your bootstrap output (Terraform doesn't allow backend values to
be variables).

Open `envs/prod/main.tf` and find the backend block:

```hcl
backend "gcs" {
  bucket = "gcp-edge-tfstate-your-project-id"   # ← replace with your bucket name
  prefix = "gcp-edge/envs/prod"
}
```

Replace `your-project-id` with the actual project ID from bootstrap
output:

```hcl
backend "gcs" {
  bucket = "gcp-edge-tfstate-my-project-prod"
  prefix = "gcp-edge/envs/prod"
}
```

> **Why this matters:** without the backend block pointing at the right
> bucket, `terraform apply` stores state locally. The next person to run
> it won't see any existing resources and will try to create everything
> again. CI/CD also won't find the state.

Commit this change:

```bash
git add -A
git commit -m "configure remote backend for prod"
git push
```

---

## Step 5 — Configure and deploy the prod environment

### 5a — Create Cloud Identity groups (one-time)

In the [Google Admin Console](https://admin.google.com) → Directory →
Groups, create three groups:

| Group email | Purpose |
|---|---|
| `gcp-edge-admins@example.org` | `roles/owner` — full access |
| `gcp-edge-developers@example.org` | `storage.objectAdmin` + `run.invoker` + `monitoring.viewer` |
| `gcp-edge-readonly@example.org` | `roles/viewer` |

(Adjust the prefix if you set a different `project_name` in
`terraform.tfvars`.)

### 5b — Create your tfvars file

```bash
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values. At minimum:

- **`project_id`** — your GCP project ID
- **`alert_email`** — an email address for budget alerts
- **`org_domain`** — your Cloud Identity org domain
- **`sites`** — one or more site entries (the example uses `example.com`)

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

**First apply is slow** — provisioning the Global External HTTPS LB +
managed SSL cert takes 10–15 min. The next step covers what to do while
that propagates.

---

## Step 6 — DNS setup

After `terraform apply` completes, three types of DNS records are needed.
Terraform outputs the values:

```bash
terraform -chdir=envs/prod output
terraform -chdir=envs/prod output dns_instructions
```

### 6a — LB IP A record

From the `lb_ip_address` output, add at your DNS provider (zone for
`example.com`):

| Type | Host | Value |
|---|---|---|
| A | `@` | `<LB IPv4 address>` |

### 6b — Site CNAMEs

For each site, add a CNAME pointing to the apex:

| Type | Host | Value |
|---|---|---|
| CNAME | `www` | `@` |
| CNAME | `blogs` | `@` |

### 6c — Wait for SSL cert to provision

```bash
gcloud compute ssl-certificates describe gcp-edge-prod-cert --global \
  --project=my-project-prod --format="get(managed.status)"
# Should show: ACTIVE  (after both www and blogs resolve to the LB IP)
```

This usually takes 1–15 min after both CNAMEs propagate.

### 6d — (Optional) Set up SendGrid + Turnstile secrets

If you're using the contact form:

1. **SendGrid** — sign up at https://sendgrid.com (free tier, 100 emails/day),
   create an API key with **Mail Send** scope, and authenticate your
   sender domain.
2. **Cloudflare Turnstile** — sign up at https://dash.cloudflare.com →
   Turnstile, create a widget for your site domain.
3. Set the secret values (after the first apply creates the containers):

```bash
echo -n 'SG.xxxxxxxxxxxx' | gcloud secrets versions add sendgrid-api-key \
  --data-file=- --project=my-project-prod

echo -n '0xyyy' | gcloud secrets versions add turnstile-secret \
  --data-file=- --project=my-project-prod
```

4. Put the Turnstile **site key** (public) in your HTML's
   `data-sitekey` attribute, then deploy content.

---

## Step 7 — Set up CI/CD

CI/CD runs in GitHub Actions using **Workload Identity Federation** — no
long-lived service account keys.

### 7a — Capture WIF provider and SA emails

```bash
terraform -chdir=envs/prod output wif_provider_name
terraform -chdir=envs/prod output infra_sa_email
terraform -chdir=envs/prod output content_sa_email
```

### 7b — Create a `production` GitHub Environment

Go to your repo → **Settings → Environments → New environment**.

Create an environment named **`production`** and add required reviewers
(yourself or team) if you want approval gates on apply.

### 7c — Set GitHub Environment secrets

| Secret name | Value |
|---|---|
| `GCP_EDGE_PROD_WIF_PROVIDER` | `wif_provider_name` output |
| `GCP_EDGE_PROD_INFRA_SA` | `infra_sa_email` output |
| `GCP_EDGE_PROD_CONTENT_SA` | `content_sa_email` output |
| `GCP_EDGE_PROD_TFVARS` | Base64-encoded contents of `envs/prod/terraform.tfvars` |

The plan and apply workflows read `GCP_EDGE_PROD_TFVARS` and write it
as `terraform.tfvars` before each run, so the CI runner always has the
correct variables.

Set them via the GitHub UI, or via the CLI:

```bash
gh secret set GCP_EDGE_PROD_WIF_PROVIDER --env production \
  --body "$(terraform -chdir=envs/prod output -raw wif_provider_name)"
gh secret set GCP_EDGE_PROD_INFRA_SA --env production \
  --body "$(terraform -chdir=envs/prod output -raw infra_sa_email)"
gh secret set GCP_EDGE_PROD_CONTENT_SA --env production \
  --body "$(terraform -chdir=envs/prod output -raw content_sa_email)"
gh secret set GCP_EDGE_PROD_TFVARS --env production \
  --body "$(base64 -w0 envs/prod/terraform.tfvars)"
```

> **Troubleshooting:** If workflows fail with "Failed to get OIDC token",
> verify that:
> - The `production` GitHub Environment exists with the exact name
> - All four secrets are set under that environment
> - The WIF provider's `attribute_condition` matches
>   `<github_org>/<github_repo>` (check the `github_org` and
>   `github_repo` vars in your tfvars)

---

## Step 8 — Test CI/CD

Push your current branch and open a Pull Request against `main`:

```bash
git add -A
git commit -m "chore: configure prod environment"
git push -u origin HEAD
```

On GitHub, open a PR. You should see:

1. **`gcp-edge-iac-plan.yml`** trigger on the PR — runs `terraform fmt
   -check`, `terraform validate`, and `terraform plan`. Review the plan
   output in the workflow logs.

If the plan looks correct, merge the PR. The merge triggers:

2. **`gcp-edge-iac-apply.yml`** on push to `main` — runs `terraform
   apply -auto-approve` (gated by the `production` environment if you
   added required reviewers).
3. **`gcp-edge-deploy-content.yml`** — deploys any static content that
   was committed to `gcp-edge/content/prod/<site>/dist/`.

---

## Step 9 — Deploy site content

Place your built site files in the content directory:

```
gcp-edge/content/prod/example/dist/
├── index.html
├── assets/
└── ...
```

Then deploy:

```bash
./scripts/deploy-site.sh --env prod example
```

This syncs the files to GCS and creates a Cloud CDN cache invalidation.

Verify the deployment:

```bash
./scripts/verify-site.sh --env prod example
```

---

## What's next

Now that your first env and site are live:

- **Add another site** — see [README → Sites](README.md#sites)
- **Add another environment** — see [README → Environments](README.md#environments)
- **Tear down** — see [README → Tear down an environment](README.md#tear-down-an-environment)

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `terraform plan` shows all resources as `+ create` after a successful apply | Remote backend not configured (step 4 skipped) | Edit `envs/prod/main.tf` `backend` block to match your bucket; run `terraform init -reconfigure` |
| Managed SSL cert stuck in `PROVISIONING` | DNS CNAMEs not added or haven't propagated | Add the missing CNAMEs; cert becomes `ACTIVE` within minutes once DNS resolves |
| CI workflow fails with "Failed to get OIDC token" | WIF provider's `attribute_condition` doesn't match repo, or environment name wrong | Verify `github_org`/`github_repo` in tfvars match the fork exactly; check the GitHub Environment name |
| Workflow runs but `terraform plan` shows no sites | `GCP_EDGE_PROD_TFVARS` secret has empty `sites` map | Re-set the secret with the base64-encoded tfvars |
| `gcloud storage rsync` returns 401 Anonymous caller | Old `gsutil rsync` doesn't respect WIF | Use `gcloud storage rsync` (the deploy script already does) |
| Contact form returns 401/403 at `/api/contact` | `roles/run.invoker` missing for `allUsers` on the function | Check `google_cloud_run_service_iam_member.public_invoker` is present; re-apply if needed |
| Cloud Function deploys but `/` returns 404 | CDN cached the 404 when bucket was empty | Run `./scripts/invalidate-cache.sh --env prod` |
| `terraform destroy` fails on non-empty buckets | Buckets need to be emptied first | Use `./scripts/teardown-env.sh <env>` (it empties buckets before destroying) |