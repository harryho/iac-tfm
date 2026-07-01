locals {
  basename = "${var.project_name}-${var.environment}-ops"
  labels   = merge(var.common_labels, { component = "ops" })
}

data "google_project" "current" {
  project_id = var.project_id
}

# --------------------------------------------------------------------------
# Email notification channel for alerts
# --------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  count        = var.enable_budget ? 1 : 0
  project      = var.project_id
  display_name = "${local.basename}-email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# --------------------------------------------------------------------------
# Monthly billing budget — 50% / 90% / 100% thresholds, email alert
# --------------------------------------------------------------------------
resource "google_billing_budget" "monthly" {
  count           = var.enable_budget && var.billing_account_id != "" ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "${local.basename}-monthly"

  budget_filter {
    projects               = ["projects/${data.google_project.current.number}"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_limit_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email[0].id]
    disable_default_iam_recipients   = true
  }
}

# --------------------------------------------------------------------------
# Cloud Monitoring dashboard — LB requests, CF errors, Firestore writes
# --------------------------------------------------------------------------
resource "google_monitoring_dashboard" "ops" {
  count   = var.enable_dashboard ? 1 : 0
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${local.basename}-dashboard"
    mosaicLayout = {
      columns = 3
      tiles = [
        {
          height = 3
          width  = 3
          xPos   = 0
          yPos   = 0
          widget = {
            title = "LB Request Count (global)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_load_balancer\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          height = 3
          width  = 3
          xPos   = 0
          yPos   = 3
          widget = {
            title = "Cloud Function Errors (5m)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" resource.type=\"cloud_function\" metric.label.status=\"error\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          height = 3
          width  = 3
          xPos   = 0
          yPos   = 6
          widget = {
            title = "Firestore Document Writes"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"firestore.googleapis.com/document/write_count\" resource.type=\"datastore_request\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
    labels = local.labels
  })
}