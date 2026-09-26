# 01 · Build & teardown

**When:** standing the landing zone up, or removing every trace of it.

## Build
```bash
gcloud config set project <project>      # billing linked; everything else is auto-detected
./scripts/up.sh                          # ≈ 4 min apply + ≈ 8 min tests
./scripts/up.sh --plan                   # Terraform plan only
./scripts/up.sh --skip-tests
```
Steps: state bucket → `terraform apply` (71 resources: 3 VPCs, NCC hub + 3 spokes, 3 firewall policies, 3 NAT gateways, DNS zones, 3 VMs, log sink, metric, alert, budget) → wait for VM startup → `scripts/test.sh` (writes [`docs/test-results.md`](../test-results.md)).

*Captured:* the apply finished `Apply complete! Resources: 71 added, 0 changed, 0 destroyed.` on the first run; the NCC spokes were the slowest resources (52 s / 93 s / 115 s).

## Teardown
```bash
./scripts/down.sh            # destroy everything this repo created
./scripts/down.sh --purge    # also delete this repo's state (and the bucket if it is then empty)
```
It first deletes the Connectivity Tests created by the suite (they live outside Terraform), then `terraform destroy`, then prints a "billable things left" summary (VMs, routers, VPCs, NCC hubs should all be `0`).

*Captured:* `Destroy complete! Resources: 71 destroyed.` then the leftover summary printed `VMs 0 · Cloud Routers 0 · VPC networks 0 · NCC hubs 0`.

## Cost while it runs
3 × e2-micro + 3 NAT gateways + flow logs ≈ **€0.5–1 per day**; see [07](07-cost.md).
