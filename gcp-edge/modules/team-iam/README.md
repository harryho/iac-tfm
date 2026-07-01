# `team-iam` module

Binds Cloud Identity groups to GCP IAM roles and sets up Workload Identity Federation for GitHub Actions.

## Prerequisites

- The three Cloud Identity groups must exist in the org:
  - `<project_name>-admins@<org_domain>`
  - `<project_name>-developers@<org_domain>`
  - `<project_name>-readonly@<org_domain>`
- `cloudidentity.googleapis.com` must be enabled

## Inputs

| Name | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | — |
| `project_name` | Used as group-name prefix | `gcp-edge` |
| `org_domain` | Cloud Identity org domain | — |
| `state_bucket_name` | GCS state bucket for infra SA access | — |
| `github_org` | GitHub org/username for OIDC trust | `""` (skip WIF) |
| `github_repo` | GitHub repo name for OIDC trust | `""` (skip WIF) |
| `github_envs` | Allowed GitHub environments | `["production"]` |
| `enable_wif` | Create WIF pool, provider, and SAs | `true` |
| `common_labels` | Labels for resources | `{}` |

## Outputs

| Name | Description |
|---|---|
| `infra_sa_email` | `terraform-infra@...` |
| `content_sa_email` | `terraform-content@...` |
| `wif_pool_id` | WIF pool ID |
| `wif_provider_name` | Full provider resource path (for GitHub Actions) |
| `group_bindings` | Summary of group → role bindings |

## GitHub Actions config

After apply, add these secrets:

- `GCP_<ENV>_WIF_PROVIDER` = `<wif_provider_name>`
- `GCP_<ENV>_INFRA_SA` = `<infra_sa_email>`
- `GCP_<ENV>_CONTENT_SA` = `<content_sa_email>`
- `GCP_<ENV>_TFVARS` = full contents of `envs/<env>/terraform.tfvars`