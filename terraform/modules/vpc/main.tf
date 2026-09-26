# One VPC = custom-mode network, one regional subnet, Cloud NAT, a network firewall policy, and one
# private VM (no external IP) that serves a tiny HTTP page so reachability can be *tested*, not assumed.

resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = "lz-${var.name}"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = "lz-${var.name}-${var.region}"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "lz-${var.name}"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "lz-${var.name}"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── firewall: a network firewall policy, evaluated before any VPC rule ────────────────────────────
resource "google_compute_network_firewall_policy" "this" {
  project = var.project_id
  name    = "lz-${var.name}"
}

resource "google_compute_network_firewall_policy_association" "this" {
  project           = var.project_id
  name              = "lz-${var.name}"
  attachment_target = google_compute_network.this.id
  firewall_policy   = google_compute_network_firewall_policy.this.name
}

resource "google_compute_network_firewall_policy_rule" "iap_ssh" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  priority        = 100
  rule_name       = "allow-iap-ssh"
  description     = "SSH only through Identity-Aware Proxy (no public IPs, no bastion)"
  direction       = "INGRESS"
  action          = "allow"
  match {
    src_ip_ranges = ["35.235.240.0/20"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "workload" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  priority        = 200
  rule_name       = "allow-workload-from-approved-cidrs"
  description     = "Workload port + ICMP, only from the CIDRs this VPC is meant to serve"
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = false
  match {
    src_ip_ranges = var.allowed_sources
    layer4_configs {
      ip_protocol = "tcp"
      ports       = [var.workload_port]
    }
    layer4_configs {
      ip_protocol = "icmp"
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "deny_rest" {
  project         = var.project_id
  firewall_policy = google_compute_network_firewall_policy.this.name
  priority        = 65000
  rule_name       = "deny-and-log-everything-else"
  description     = "The implicit deny is not logged; this one is, so denials are visible and alertable"
  direction       = "INGRESS"
  action          = "deny"
  enable_logging  = true
  match {
    src_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

# ── the private VM ────────────────────────────────────────────────────────────────────────────────
resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "lz-${var.name}-vm"
  display_name = "Landing zone ${var.name} VM (no roles)"
}

resource "google_compute_instance" "vm" {
  project      = var.project_id
  name         = "lz-${var.name}-vm"
  zone         = var.zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.this.id
    # deliberately no access_config: the VM has no external IP
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["logging-write"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    startup-script         = <<-EOT
      #!/bin/bash
      set -eu
      mkdir -p /srv/demo
      printf 'lz-${var.name}-vm (%s)\n' "$(hostname -I | awk '{print $1}')" > /srv/demo/index.html
      cat >/etc/systemd/system/demo-http.service <<'UNIT'
      [Unit]
      Description=Landing zone demo workload
      After=network.target
      [Service]
      WorkingDirectory=/srv/demo
      ExecStart=/usr/bin/python3 -m http.server ${var.workload_port}
      Restart=always
      [Install]
      WantedBy=multi-user.target
      UNIT
      systemctl daemon-reload
      systemctl enable --now demo-http.service
    EOT
  }

  labels = { env = var.name, project = "landing-zone" }

  depends_on = [google_compute_router_nat.this]
}
