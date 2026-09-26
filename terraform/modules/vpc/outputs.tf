output "network" { value = google_compute_network.this }
output "vm_name" { value = google_compute_instance.vm.name }
output "vm_ip" { value = google_compute_instance.vm.network_interface[0].network_ip }
output "cidr" { value = var.cidr }
