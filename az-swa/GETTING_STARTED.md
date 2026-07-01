# Getting Started — Azure (az-swa)

This walkthrough takes you from a fresh template fork to a deployed site
with CI/CD pipelines running. Follow it start-to-finish the first time;
after that each step has a reference you can jump to.

**Time estimate:** 20–30 minutes (most of it waiting for the SWA to
provision).

---

## Prerequisites

Tools installed on your machine:

- [git](https://git-scm.com/)
- [Terraform 1.5+](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
  (authenticated via `az login`)
- [jq](https://jqlang.org/download/)
- [Node.js 18+ / npm](https://nodejs.org/) (for the SWA CLI)
- [GitHub CLI `gh`](https://cli.github.com/) (authenticated)

Verify everything:

```bash
for cmd in git terraform az jq node gh; do
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
cd iac-tfm/az-swa
```

---

## Step 2 — Bootstrap the state backend

This is a **one-time** step per Azure subscription. It creates a resource
group, a storage account, and a blob container to store Terraform state.

```bash
cd bootstrap
terraform init
terraform apply   # type "yes" when prompted
cd ..
```

After it finishes, the backend configuration in `envs/dev/main.tf` already
points to the storage account. The default `project_name` (`az-swa`) maps
to `storage_account_name = "azswatfstate"` — if you changed the project
name, update the backend block in `envs/dev/main.tf` to match.

> **What the backend block looks like** (in `envs/dev/main.tf`, lines 13–19):
> ```hcl
> backend "azurerm" {
>   storage_account_name = "azswatfstate"
>   container_name       = "tfstate"
>   key                  = "az-swa/envs/dev/terraform.tfstate"
>   resource_group_name  = "az-swa-tfstate-rg"
> }
> ```

---

## Step 3 — Configure the dev environment

### 3a — Create your tfvars file

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values:

| Variable | What to enter | Example |
|---|---|---|
| `primary_domain` | The domain your sites live under | `dev.example.com` |
| `alert_email` | Email for budget alerts | `ops@example.com` |
| `sites` | Map of site keys to domains | see below |

### 3b — Add your first site

The `sites` map controls which sites are deployed:

```hcl
sites = {
  example = {
    domain = "dev.example.com"
  }
}
```

Each site key (e.g. `example`) becomes part of the content path
and the SWA deployment name. Add as many entries as you need.

---

## Step 4 — Deploy

```bash
terraform init
terraform plan
```

Review the plan. It should show resources being **created** (green `+`
prefix). If something looks wrong, fix the tfvars and re-run `plan`.

```bash
terraform apply   # type "yes" when prompted
cd ../..
```

> **First apply** provisions the Static Web App, which takes 1–3 minutes.
> The custom domain DNS verification happens asynchronously.

Capture the outputs — you'll need them for CI/CD:

```bash
terraform -chdir=envs/dev output
```

---

## Step 5 — Set up CI/CD

CI/CD runs in GitHub Actions using OIDC federated credentials — no
Azure client secrets.

### 5a — Create the GitHub Environment

Go to your repo → **Settings → Environments → New environment**.

Create an environment named **`dev`** (must match `environment` in
`az-swa/envs/dev/variables.tf` — default is `dev`).

### 5b — Capture the OIDC client IDs and Azure IDs

From the Terraform outputs:

```bash
INFRA_CLIENT_ID=$(terraform -chdir=envs/dev output -raw github_infra_client_id)
CONTENT_CLIENT_ID=$(terraform -chdir=envs/dev output -raw github_content_client_id)
TENANT_ID=$(terraform -chdir=envs/dev output -raw tenant_id)
SUBSCRIPTION_ID=$(terraform -chdir=envs/dev output -raw subscription_id)
```

### 5c — Set GitHub secrets

```bash
gh secret set AZ_SWA_DEV_INFRA_CLIENT_ID --env dev --body "$INFRA_CLIENT_ID"
gh secret set AZ_SWA_DEV_CONTENT_CLIENT_ID --env dev --body "$CONTENT_CLIENT_ID"
gh secret set AZ_SWA_DEV_TENANT_ID --env dev --body "$TENANT_ID"
gh secret set AZ_SWA_DEV_SUBSCRIPTION_ID --env dev --body "$SUBSCRIPTION_ID"
gh secret set AZ_SWA_DEV_TFVARS --env dev --body "$(base64 -w0 envs/dev/terraform.tfvars)"
```

> **What these secrets are for:**
> - `*_INFRA_CLIENT_ID` — used by `az-swa-iac-plan.yml` and `az-swa-iac-apply.yml`
>   (terraform operations assume the User-Assigned Identity)
> - `*_CONTENT_CLIENT_ID` — used by `az-swa-deploy-content.yml`
>   (SWA deploy assumes a separate identity with access to the SWA deployment
>   token)
> - `*_TENANT_ID` and `*_SUBSCRIPTION_ID` — Azure AD tenant and subscription
>   for the Azure login action
> - `*_TFVARS` — contents of `terraform.tfvars` so the CI runner always has
>   the correct variables

---

## Step 6 — Push to trigger CI/CD

Azure workflows trigger on the **`deploy/azure`** branch (not `main`).
This lets you keep the AWS and Azure deployment pipelines separate if
you're using both.

Create the branch and push:

```bash
git checkout -b deploy/azure
git push -u origin deploy/azure
```

This triggers three workflows:

1. **`az-swa-iac-plan.yml`** — runs `terraform fmt -check`, `validate`,
   and `plan` against the dev env
2. **`az-swa-iac-apply.yml`** — runs `terraform apply -auto-approve`
   (gated by GitHub Environment `dev`)
3. **`az-swa-deploy-content.yml`** — deploys any content found in
   `az-swa/content/dev/<site>/dist/`

> **Troubleshooting:** If the apply workflow fails with "unable to
> acquire the OIDC token", verify that:
> - The `dev` GitHub Environment exists with the exact name
> - All five secrets are set under that environment
> - The federated credential in Azure matches
>   `repo:<org>/<repo>:environment:dev`

---

## Step 7 — Deploy site content

Place your built site files in the content directory:

```
az-swa/content/dev/example/dist/
├── index.html
├── assets/
└── ...
```

Then deploy:

```bash
./scripts/deploy-site.sh --env dev example
```

This uses the SWA CLI to upload and publish the content.

Verify the deployment:

```bash
./scripts/verify-site.sh --env dev example
```

For contact-form sites, the verification also checks the API endpoint.

---

## What's next

Now that your first env and site are live:

- **Add another site** — see [Expandable capabilities → Add a site](README.md#sites)
- **Add another environment** — see [Expandable capabilities → Add an environment](README.md#environments)
- **Tear down** — see the [teardown instructions](README.md#tear-down-an-environment)

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `terraform plan` shows resources as `+ create` after a successful apply | Backend misconfigured or state not found | Run `terraform init -reconfigure` to reconnect to the storage account |
| Static Web App deploys but custom domain shows "Not verified" | DNS CNAME for the SWA hostname hasn't propagated | Add a CNAME from your domain to `<swa-name>.azureedge.net` at your DNS provider |
| CI workflow fails with "Identity not found" | Federated credential client ID doesn't match | Verify `AZ_SWA_DEV_INFRA_CLIENT_ID` matches the `github_infra_client_id` output |
| CI workflow runs but no sites are deployed | `AZ_SWA_DEV_TFVARS` secret has empty `sites` map | Check the secret value and re-set it |
| `az login` works locally but CI fails | The federated credential doesn't give CLI access (this is expected) | CI uses OIDC via `azure/login@v1` with the UAI client ID — different from `az login` |
