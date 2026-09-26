# Hub-and-spoke landing zone: three VPCs joined by Network Connectivity Center in STAR topology.
#   hub  = center group: reachable by everyone, hosts shared services
#   prod, dev = edge group: each can reach the hub, but NOT each other
# Isolation is enforced twice: no route exists between edge spokes (NCC), and each spoke's firewall
# policy only admits the hub CIDR (defense in depth).

data "google_project" "this" {
  project_id = var.project_id
  depends_on = [google_project_service.apis]
}

module "hub" {
  source          = "./modules/vpc"
  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  name            = "hub"
  cidr            = var.cidrs["hub"]
  allowed_sources = [var.cidrs["prod"], var.cidrs["dev"]]
  depends_on      = [google_project_service.apis]
}

module "prod" {
  source          = "./modules/vpc"
  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  name            = "prod"
  cidr            = var.cidrs["prod"]
  allowed_sources = [var.cidrs["hub"]]
  depends_on      = [google_project_service.apis]
}

module "dev" {
  source          = "./modules/vpc"
  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  name            = "dev"
  cidr            = var.cidrs["dev"]
  allowed_sources = [var.cidrs["hub"]]
  depends_on      = [google_project_service.apis]
}

# ── Network Connectivity Center ───────────────────────────────────────────────────────────────────
resource "google_network_connectivity_hub" "this" {
  project         = var.project_id
  name            = "lz-hub"
  description     = "Landing zone hub (star topology)"
  preset_topology = "STAR"
  depends_on      = [google_project_service.apis]
}

locals {
  ncc_groups = {
    center = "${google_network_connectivity_hub.this.id}/groups/center"
    edge   = "${google_network_connectivity_hub.this.id}/groups/edge"
  }
  spokes = {
    hub  = { net = module.hub.network, group = "center" }
    prod = { net = module.prod.network, group = "edge" }
    dev  = { net = module.dev.network, group = "edge" }
  }
}

resource "google_network_connectivity_spoke" "vpc" {
  for_each = local.spokes
  project  = var.project_id
  name     = "lz-${each.key}"
  location = "global"
  hub      = google_network_connectivity_hub.this.id
  group    = local.ncc_groups[each.value.group]

  linked_vpc_network {
    uri = each.value.net.self_link
  }
}

# ── Private DNS: one zone in the hub, peered into the spokes ──────────────────────────────────────
resource "google_dns_managed_zone" "hub" {
  project    = var.project_id
  name       = "corp-internal"
  dns_name   = "corp.internal."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = module.hub.network.id
    }
  }
  depends_on = [google_project_service.apis]
}

resource "google_dns_managed_zone" "peer" {
  for_each   = toset(["prod", "dev"])
  project    = var.project_id
  name       = "corp-internal-peer-${each.key}"
  dns_name   = "corp.internal."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = local.spokes[each.key].net.id
    }
  }
  peering_config {
    target_network {
      network_url = module.hub.network.id
    }
  }
}

resource "google_dns_record_set" "a" {
  for_each     = { shared = module.hub.vm_ip, prod-app = module.prod.vm_ip, dev-app = module.dev.vm_ip }
  project      = var.project_id
  managed_zone = google_dns_managed_zone.hub.name
  name         = "${each.key}.corp.internal."
  type         = "A"
  ttl          = 60
  rrdatas      = [each.value]
}

resource "google_dns_policy" "logging" {
  for_each       = local.spokes
  project        = var.project_id
  name           = "lz-${each.key}-dns-logging"
  enable_logging = true
  networks {
    network_url = each.value.net.id
  }
}

# ── operator access: IAP tunnel + OS Login (no bastion, no keys) ──────────────────────────────────
resource "google_project_iam_member" "operator" {
  for_each = toset(["roles/iap.tunnelResourceAccessor", "roles/compute.osAdminLogin", "roles/compute.viewer", "roles/networkmanagement.admin"])
  project  = var.project_id
  role     = each.value
  member   = "user:${var.admin_email}"
}
