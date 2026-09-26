# 07 · Cost

| Item | Rough cost while running |
|---|---|
| 3 × e2-micro + 10 GB pd-standard | ≈ €0.30 / day |
| 3 × Cloud NAT gateway (hourly + tiny data) | ≈ €0.10–0.15 / day |
| NCC VPC spokes | no hourly charge (inter-region data only; all resources are single-region) |
| Flow logs, DNS logs, BigQuery (7-day TTL) | cents at demo volume; **flow logs scale with traffic** — lower `flow_sampling` in production |
| Private DNS, firewall policies, IAP | free at this scale |

A Terraform-managed budget (€15 default) emails at 50 % and 100 %. `down.sh` removes all of it; idle cost after teardown is €0.
