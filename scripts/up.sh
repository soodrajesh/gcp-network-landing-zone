#!/usr/bin/env bash
# Build the whole landing zone end to end, then prove it works:
#   state bucket -> 3 VPCs + NCC star hub + firewall policies + NAT + private DNS + flow logs -> live tests.
# Idempotent. `--plan` shows the Terraform plan and stops. `--skip-tests` skips the final test suite.
source "$(dirname "$0")/lib.sh"
PLAN_ONLY=0; SKIP_TESTS=0
for a in "$@"; do case "$a" in --plan) PLAN_ONLY=1;; --skip-tests) SKIP_TESTS=1;; esac; done
need gcloud; need terraform; need curl

log "Project $PROJECT_ID · $REGION · billing $BILLING_ACCOUNT_ID · admin $ADMIN_EMAIL"

log "1/4 Terraform state bucket"
"$ROOT/scripts/bootstrap.sh" "$PROJECT_ID" "$REGION" >/dev/null && ok "gs://$STATE_BUCKET"
tf_init

if [ "$PLAN_ONLY" = 1 ]; then log "Plan only"; $TF plan -input=false; exit 0; fi

log "2/4 Infrastructure (3 VPCs, NCC star hub, NAT, firewall policies, DNS, flow logs, alerting)"
$TF apply -input=false -auto-approve
ok "applied"

log "3/4 Waiting for the three private VMs to serve their workload"
for vm in hub prod dev; do
  wait_for "lz-$vm-vm startup finished" 300 bash -c \
    "gcloud compute instances get-serial-port-output lz-$vm-vm --zone $ZONE --project $PROJECT_ID 2>/dev/null | grep -q 'demo-http.service\|Started Landing zone demo workload'"
done

if [ "$SKIP_TESTS" = 1 ]; then log "Skipping tests"; else
  log "4/4 Live test suite"
  "$ROOT/scripts/test.sh"
fi
log "DONE — tear down with ./scripts/down.sh"
