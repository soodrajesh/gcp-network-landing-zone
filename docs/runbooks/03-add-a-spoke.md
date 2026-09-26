# 03 · Add a spoke (e.g. `staging`)

**When:** a new environment needs its own isolated VPC that can reach shared services.

1. Pick a non-overlapping CIDR (`10.30.0.0/24`) and add it to `var.cidrs`.
2. In `terraform/main.tf` add a module and a spoke entry:
```hcl
module "staging" {
  source          = "./modules/vpc"
  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  name            = "staging"
  cidr            = var.cidrs["staging"]
  allowed_sources = [var.cidrs["hub"]]      # only the hub, never a sibling edge
}
# locals.spokes:  staging = { net = module.staging.network, group = "edge" }
```
3. Add `staging` to the hub module's `allowed_sources` (so shared services answer it), and to the DNS peering `for_each`.
4. `./scripts/up.sh --plan`, review, `./scripts/up.sh`.
5. Extend `scripts/test.sh`: staging→hub REACHABLE, staging→prod/dev UNREACHABLE.

**Rule:** a spoke in `edge` can never talk to another `edge`. If two environments must talk, they are the same trust zone — or publish the service from the hub with Private Service Connect.
