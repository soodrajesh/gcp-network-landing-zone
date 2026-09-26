# Runbooks

Each runbook: **When** · **Commands** · **Output** · **If it goes wrong**.

> **Output status.** Blocks headed *Captured* are real output from the live deployment (2026-09-26). Nothing here is invented: a block not marked *Captured* is a specification.

Set once per shell:
```bash
export PROJECT=$(gcloud config get-value project) REGION=europe-west1 ZONE=europe-west1-b
```

| # | Runbook | Use it when |
|---|---|---|
| 01 | [Build & teardown](01-build-and-teardown.md) | Standing the zone up / down |
| 02 | [Reach a private VM](02-access.md) | You need a shell on a VM with no public IP |
| 03 | [Add a spoke](03-add-a-spoke.md) | A new environment (staging, sandbox…) needs a VPC |
| 04 | [Diagnose connectivity](04-diagnose-connectivity.md) | "A can't reach B" (or the reverse: "A *can* reach B") |
| 05 | [Observability queries](05-observability.md) | Top talkers, denies, DNS, NAT |
| 06 | [Incident response](06-incident-response.md) | The denied-ingress alert fires |
| 07 | [Cost](07-cost.md) | Bill questions |
| 08 | [Troubleshooting](08-troubleshooting.md) | Problems already hit during development |
