# gcp-edge bootstrap

Creates the GCS state bucket and enables required APIs. Run once, never again.

## Usage

```bash
# Authenticate as the admin who will own the project (or use ADC):
#   gcloud auth application-default login
#   gcloud config set project <your-project-id>

# Create the state bucket + enable APIs
cd gcp-edge/bootstrap
terraform init
terraform plan
terraform apply

# Note the outputs
terraform output instructions

# Then initialise the prod env
cd ../envs/prod
terraform init
```

## Variables

| Name | Description | Default |
|---|---|---|
| `project_id` | GCP project ID (immutable) | — |
| `region` | GCP region for bootstrap resources | `us-central1` |
| `project_name` | Project name used in resource naming | `gcp-edge` |
| `admin_email` | Admin email to grant tfstate bucket access | — |

## What it creates

| Resource | Purpose |
|---|---|
| `google_storage_bucket.tfstate` | GCS bucket for Terraform state (versioned, `prevent_destroy`) |
| `google_project_service.api` | 13 APIs required by the envs and modules |
| `google_storage_bucket_iam_binding.tfstate_admin` | Grants the admin user `objectAdmin` on the bucket |

## Cost

~$0 — GCS is free under 5 GB, APIs have no base charge.