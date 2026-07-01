# `ops` module — budgets + monitoring dashboard

Creates a monthly billing budget with email alerts (50% / 90% / 100% thresholds) and a Cloud Monitoring dashboard with three widgets:

1. **LB Request Count** — global HTTPS load balancer requests
2. **Cloud Function Errors** — contact form execution errors
3. **Firestore Writes** — document write operations

## Usage

```hcl
module "ops" {
  source = "../../modules/ops"

  project_id               = var.project_id
  alert_email              = var.alert_email
  billing_account_id       = var.billing_account_id
  monthly_budget_limit_usd = 5
  project_name             = var.project_name
  environment              = var.environment
  common_labels            = local.common_labels
}
```

## Variables

| Name | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | — |
| `alert_email` | Email for budget + monitoring alerts | — |
| `billing_account_id` | Billing account ID (leave empty to skip budget) | `""` |
| `monthly_budget_limit_usd` | Monthly budget cap in USD | `5` |
| `enable_budget` | Create billing budget + alert | `true` |
| `enable_dashboard` | Create monitoring dashboard | `true` |
| `project_name` | Project name for naming | `"gcp-edge"` |
| `environment` | Environment name | — |
| `common_labels` | Labels for all resources | `{}` |

## Outputs

| Name | Description |
|---|---|
| `notification_channel_id` | Email notification channel ID |
| `budget_id` | Billing budget ID (empty if disabled) |
| `dashboard_id` | Monitoring dashboard ID (empty if disabled) |