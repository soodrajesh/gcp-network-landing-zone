#!/usr/bin/env bash
# Delete everything this repo created, end to end.
#   ./scripts/down.sh            destroy the landing zone (keeps the tiny shared Terraform state bucket)
#   ./scripts/down.sh --purge    also delete this repo's Terraform state (and the bucket if now empty)
source "$(dirname "$0")/lib.sh"
need gcloud; need terraform
PURGE=0; [ "${1:-}" = "--purge" ] && PURGE=1

log "Project $PROJECT_ID — destroying everything managed by this repo"
tf_init

log "1/3 Removing Connectivity Tests created by test.sh (they live outside Terraform)"
for t in $(gcloud network-management connectivity-tests list --project "$PROJECT_ID" --format='value(name)' --filter='name~lz-' 2>/dev/null); do
  gcloud network-management connectivity-tests delete "$t" --project "$PROJECT_ID" --quiet >/dev/null 2>&1 || true
done
ok "connectivity tests removed"

log "2/3 Terraform destroy"
$TF destroy -input=false -auto-approve
ok "landing zone destroyed"
rm -rf "$ROOT/.test-tmp"

if [ "$PURGE" = 1 ]; then
  log "3/3 Purging this repo's Terraform state"
  gcloud storage rm -r "gs://$STATE_BUCKET/landing-zone/" --quiet >/dev/null 2>&1 || true
  if [ -z "$(gcloud storage ls "gs://$STATE_BUCKET/" 2>/dev/null)" ]; then
    gcloud storage rm -r "gs://$STATE_BUCKET" --quiet >/dev/null 2>&1 || true; ok "state prefix and (now empty) bucket removed"
  else ok "state prefix removed; bucket kept because other stacks still use it"; fi
else log "3/3 Kept state bucket gs://$STATE_BUCKET (a few KB; --purge removes it)"; fi

log "Anything billable left?"
echo "  VMs:            $(gcloud compute instances list --project "$PROJECT_ID" --format='value(name)' --filter='name~^lz-' 2>/dev/null | wc -l | tr -d ' ')"
echo "  Cloud Routers:  $(gcloud compute routers list --project "$PROJECT_ID" --format='value(name)' --filter='name~^lz-' 2>/dev/null | wc -l | tr -d ' ')"
echo "  VPC networks:   $(gcloud compute networks list --project "$PROJECT_ID" --format='value(name)' --filter='name~^lz-' 2>/dev/null | wc -l | tr -d ' ')"
echo "  NCC hubs:       $(gcloud network-connectivity hubs list --project "$PROJECT_ID" --format='value(name)' 2>/dev/null | wc -l | tr -d ' ')"
log "DONE"
