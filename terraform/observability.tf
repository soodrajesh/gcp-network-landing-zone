# Flow logs -> BigQuery (analysis), firewall denials -> log-based metric -> alert, budget.

resource "google_bigquery_dataset" "flows" {
  project                     = var.project_id
  dataset_id                  = "lz_flow_logs"
  location                    = "EU"
  delete_contents_on_destroy  = true
  default_table_expiration_ms = 7 * 24 * 3600 * 1000
  depends_on                  = [google_project_service.apis]
}

resource "google_logging_project_sink" "flows" {
  project                = var.project_id
  name                   = "lz-vpc-flows-to-bq"
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.flows.dataset_id}"
  filter                 = "logName:\"compute.googleapis.com%2Fvpc_flows\""
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "sink" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.flows.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.flows.writer_identity
}

resource "google_logging_metric" "fw_denied" {
  project     = var.project_id
  name        = "lz_firewall_ingress_denied"
  description = "Ingress packets dropped by a landing-zone firewall policy"
  filter      = "logName:\"compute.googleapis.com%2Ffirewall\" AND jsonPayload.disposition=\"DENIED\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "vpc"
      value_type  = "STRING"
      description = "VPC name"
    }
  }
  label_extractors = {
    vpc = "EXTRACT(jsonPayload.vpc.vpc_name)"
  }
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Landing zone alerts"
  type         = "email"
  labels       = { email_address = var.alert_email }
  depends_on   = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "fw_denied" {
  project      = var.project_id
  display_name = "Landing zone: burst of denied ingress traffic"
  combiner     = "OR"
  conditions {
    display_name = "> 50 denied packets in 5 min"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.fw_denied.name}\" AND resource.type=\"gce_subnetwork\""
      comparison      = "COMPARISON_GT"
      threshold_value = 50
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "A firewall policy is dropping unusual volume. Runbook: docs/runbooks/06-incident-response.md"
    mime_type = "text/markdown"
  }
}

resource "google_billing_budget" "this" {
  billing_account = var.billing_account_id
  display_name    = "landing-zone"
  amount {
    specified_amount {
      currency_code = "EUR"
      units         = tostring(var.budget_amount)
    }
  }
  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }
  threshold_rules { threshold_percent = 0.5 }
  threshold_rules { threshold_percent = 1.0 }
  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = true
  }
  depends_on = [google_project_service.apis]
}
