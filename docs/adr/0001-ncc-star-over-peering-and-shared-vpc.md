# ADR 0001 — Network Connectivity Center (star) instead of VPC peering or Shared VPC

**Status:** accepted

## Context
Prod and dev must each reach shared services in a hub, and must **never** reach each other. Options:

| Option | Why not / why |
|---|---|
| **VPC peering hub↔spokes** | Peering is non-transitive, so isolation is "free", but every spoke needs a peering pair, custom-route exchange is per-pair, there is a 25-peering-per-network limit, and there is no central place to see topology. |
| **Shared VPC** | One network, isolation only by firewall and subnet — a single misconfigured rule connects prod and dev. Also needs an organisation with host/service projects. |
| **NCC mesh** | Every spoke reaches every spoke — the opposite of what we need. |
| **NCC star** ✔ | One hub object, spokes attach to *groups*. `center` reaches everyone; `edge` spokes reach only `center`. New spoke = one resource. Isolation is a routing fact, visible in each VPC's route table. |

## Decision
Use an NCC hub with `preset_topology = STAR`. Hub VPC → `center` group; prod, dev → `edge` group. Firewall policies **also** only admit the hub CIDR, so removing the routing control alone still would not connect the edges.

## Consequences
- Adding `staging` = one `module "vpc"` block + one spoke in the `edge` group.
- CIDRs must not overlap (NCC rejects overlaps); we allocate a /24 per VPC from `10.0.0.0/8`.
- NCC star groups (`center`, `edge`) are created by the hub itself, so Terraform references them by path rather than managing them.
- Cross-spoke traffic that *is* wanted later (e.g. a shared database) should be published via Private Service Connect from the hub, not by merging groups.
