# `static-site-cdn` module

Creates a private GCS bucket + Cloud CDN-enabled backend bucket for a single static site. Called once per site via `for_each`.

## Inputs

| Name | Description |
|---|---|
| `site_key` | Short identifier (Terraform map key, e.g. `www_example_com`) |
| `domain` | FQDN (e.g. `www.example.com`) |
| `bucket_prefix` | Naming prefix (e.g. `gcp-edge-prod`) |
| `region` | GCS bucket location |
| `common_labels` | Labels merged into all resources |
| `deployer_sa_email` | Content deployer SA (gets `roles/storage.legacyBucketReader`) |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | GCS bucket name |
| `backend_bucket_self_link` | Self link for URL map path matchers |
| `backend_bucket_name` | Backend bucket name |
| `domain` | Domain passthrough |
| `site_key` | Site key passthrough |

## What it creates

- `google_storage_bucket.site` — private, uniform IAM, versioned, CDN origin
- `google_compute_backend_bucket.site` — CDN-enabled backend, `CACHE_ALL_STATIC`
- `google_storage_bucket_object.error_404` — custom 404 page
- `google_storage_bucket_object.error_500` — custom 500 page
- `google_storage_bucket_iam_member.deployer` — grant content deployer SA read on the bucket