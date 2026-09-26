#!/usr/bin/env bash
# Shared helpers for up.sh / down.sh / test.sh. Sourced, not executed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1${2:+ ($2)}"; }

[ -f "$ROOT/deploy.env" ] && set -a && . "$ROOT/deploy.env" && set +a

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-europe-west1}"
ZONE="${ZONE:-europe-west1-b}"
ADMIN_EMAIL="${ADMIN_EMAIL:-$(gcloud config get-value account 2>/dev/null)}"
ALERT_EMAIL="${ALERT_EMAIL:-$ADMIN_EMAIL}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-15}"
[ -n "$PROJECT_ID" ] || die "no project: set PROJECT_ID in deploy.env or 'gcloud config set project'"
BILLING_ACCOUNT_ID="${BILLING_ACCOUNT_ID:-$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingAccountName)' 2>/dev/null | sed 's|billingAccounts/||')}"
[ -n "$BILLING_ACCOUNT_ID" ] || die "project has no billing account linked"

TF="terraform -chdir=$ROOT/terraform"
STATE_BUCKET="${PROJECT_ID}-tfstate"

export TF_VAR_project_id="$PROJECT_ID" TF_VAR_region="$REGION" TF_VAR_zone="$ZONE" \
       TF_VAR_billing_account_id="$BILLING_ACCOUNT_ID" TF_VAR_alert_email="$ALERT_EMAIL" \
       TF_VAR_admin_email="$ADMIN_EMAIL" TF_VAR_budget_amount="$BUDGET_AMOUNT"

tf_init() { $TF init -input=false -backend-config="bucket=$STATE_BUCKET" >/dev/null; }

wait_for() { # <description> <timeout-seconds> <command...>
  local desc="$1" timeout="$2"; shift 2
  local end=$(( $(date +%s) + timeout ))
  until "$@" >/dev/null 2>&1; do
    [ "$(date +%s)" -lt "$end" ] || die "timed out after ${timeout}s waiting for: $desc"
    sleep 5
  done
  ok "$desc"
}

# Run a command on a private VM through Identity-Aware Proxy (no external IP, no bastion).
vm_ssh() { # <vm-name> <command>
  gcloud compute ssh "$1" --zone "$ZONE" --project "$PROJECT_ID" --tunnel-through-iap --quiet \
    --command "$2" -- -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=20 2>/dev/null | tail -1
}
