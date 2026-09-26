output "vms" {
  value = { for k, m in { hub = module.hub, prod = module.prod, dev = module.dev } : k => { name = m.vm_name, ip = m.vm_ip, cidr = m.cidr } }
}
output "ncc_hub" { value = google_network_connectivity_hub.this.name }
output "zone" { value = var.zone }
