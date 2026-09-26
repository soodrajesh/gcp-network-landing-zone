# 02 · Reach a private VM

**When:** you need a shell (or a one-off command) on a VM that has no public IP.

```bash
gcloud compute ssh lz-prod-vm --zone $ZONE --tunnel-through-iap
gcloud compute ssh lz-prod-vm --zone $ZONE --tunnel-through-iap --command 'curl -s http://10.0.0.2:8080/'
```
Requires `roles/iap.tunnelResourceAccessor` and `roles/compute.osAdminLogin` (Terraform grants both to `admin_email`). The first run generates `~/.ssh/google_compute_engine` and registers it with OS Login.

## If it goes wrong
| Symptom | Cause / fix |
|---|---|
| `failed to connect to backend` / `4003` | Firewall policy lacks `35.235.240.0/20 → tcp:22` (rule `allow-iap-ssh`, priority 100) |
| `Permission denied (publickey)` | Missing `osAdminLogin`/`osLogin` role, or `enable-oslogin` metadata removed |
| Prompts to create keys in scripts | Run once interactively, or pass `--quiet` (as `vm_ssh` in `scripts/lib.sh` does) |
