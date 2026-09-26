# ADR 0002 — IAP TCP forwarding + OS Login instead of a bastion or public IPs

**Status:** accepted

VMs have **no external IP** and the only inbound SSH path is `35.235.240.0/20` (Identity-Aware Proxy). Access is granted by IAM (`roles/iap.tunnelResourceAccessor` + `roles/compute.osAdminLogin`) and OS Login maps the Google identity to a POSIX user; project-wide SSH keys are blocked. There is no bastion to patch, no key to leak, and every session is attributable in Cloud Audit Logs.

**Trade-off:** a Google identity with those two roles is now the boundary — protect it with MFA and least-privilege groups. `gcloud compute ssh --tunnel-through-iap` is also how `scripts/test.sh` runs real packets from inside each VPC.
