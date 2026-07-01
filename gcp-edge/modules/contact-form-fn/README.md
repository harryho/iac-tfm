# `contact-form-fn` module

Creates a per-site Cloud Function 2nd gen (Node.js, SendGrid + Turnstile) wired into the LB via a serverless NEG and backend service. Submissions are persisted to Firestore.

## Inputs

| Name | Description | Default |
|---|---|---|
| `site_key` | Short identifier (must match `static_site` module key) | — |
| `site_domain` | FQDN of the site (used for CORS origin check) | — |
| `project_id` | GCP project ID | — |
| `region` | GCP region for the function and NEG | `us-central1` |
| `source_bucket` | GCS bucket for function source uploads | — |
| `recipient_email` | Email that receives form submissions | — |
| `sender_email` | From address (must be on the SendGrid domain) | — |
| `sendgrid_secret_id` | Secret Manager ID for SendGrid key (empty = skip email) | `""` |
| `turnstile_secret_id` | Secret Manager ID for Turnstile secret (empty = skip captcha) | `""` |
| `firestore_collection` | Firestore collection name | `contact_submissions` |
| `max_instance_count` | Max concurrent instances | `3` |
| `common_labels` | Labels applied to all resources | `{}` |

## Outputs

| Name | Description |
|---|---|
| `function_name` | Cloud Function name |
| `function_uri` | Direct HTTPS URI (bypasses LB) |
| `service_account_email` | Runtime SA |
| `backend_service_self_link` | For LB URL map path rules |
| `neg_self_link` | Serverless NEG self link |
| `log_name` | Cloud Logging log name pattern |

## What it creates

- `google_service_account.function` — least-privilege runtime SA
- `google_project_iam_member.function_firestore` — `roles/datastore.user`
- `google_secret_manager_secret_iam_member.sendgrid` — only if SendGrid is configured
- `google_secret_manager_secret_iam_member.turnstile` — only if Turnstile is configured
- `google_cloud_run_service_iam_member.public_invoker` — `allUsers` (form is anonymous)
- `google_cloudfunctions2_function.this` — Node 20 runtime, 256Mi, 60s timeout
- `google_compute_region_network_endpoint_group.serverless` — SERVERLESS NEG
- `google_compute_backend_service.serverless` — `EXTERNAL_MANAGED` backend
- `google_monitoring_alert_policy.errors` — fires when `execution_count > 0` with `status=error`