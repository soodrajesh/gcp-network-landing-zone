# Threat model (STRIDE, network scope)

| Threat | Control | Proven by |
|---|---|---|
| **S**poofing an admin to reach a VM | SSH only via IAP; OS Login binds sessions to Google identities; no project SSH keys | test §1 (no external IP), §4 (IAP path works) |
| **T**ampering: dev workload reaches prod | No NCC route between edge spokes **and** spoke firewall admits only the hub CIDR | test §3, §3b, §4 (`000` from dev→prod) |
| **R**epudiation: a probe leaves no trace | Explicit logged deny; DNS query logs; flow logs to BigQuery; IAP audit logs | test §7, §8 |
| **I**nformation disclosure via the internet | No external IPs; NAT is egress-only; Shielded VMs | test §1, §6 |
| **D**enial of service by noisy denies | Alert at >50 denied packets/5 min; budget alerts | alert policy exists (test §7) |
| **E**levation: VM SA abuse | VM service accounts hold **no** roles; scope limited to log writing | `terraform/modules/vpc` |
| Firewall bypass via a legacy rule | Test fails if any classic VPC rule exists on `lz-*` networks | test §1 |
| Someone adds an overlapping / wrong spoke | NCC rejects overlapping CIDRs; new spokes must be placed in a group explicitly | Terraform review |

**Out of scope (documented gaps):** on-prem connectivity (Cloud VPN/Interconnect), centralised egress inspection (Cloud NGFW Enterprise / NVA), VPC Service Controls, organisation-level policy (needs org admin), multi-region.
