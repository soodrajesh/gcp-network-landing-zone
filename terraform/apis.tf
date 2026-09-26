locals {
  apis = [
    "billingbudgets.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networkmanagement.googleapis.com",
    "oslogin.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
