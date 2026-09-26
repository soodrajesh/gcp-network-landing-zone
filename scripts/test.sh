#!/usr/bin/env bash
# Live proof against the running landing zone. Every check asserts something observed, not configured.
# Writes docs/test-results.md. Exit code = number of failed checks.
source "$(dirname "$0")/lib.sh"; set +e
need gcloud
PASS=0; FAIL=0; OUT="$ROOT/docs/test-results.md"; TMP="$ROOT/.test-tmp"; mkdir -p "$TMP"
{ echo "# Live test results"; echo; echo "Captured by \`scripts/test.sh\` on $(date -u +%FT%TZ) against project \`$PROJECT_ID\` ($REGION)."; echo; echo '```'; } > "$OUT"
say()   { echo "$*" | tee -a "$OUT"; }
check() { # <name> <expected-substring> <actual>
  if grep -qE -- "$2" <<<"$3"; then PASS=$((PASS+1)); say "  PASS  $1  [$(head -c 90 <<<"$3" | tr '\n' ' ')]"
  else FAIL=$((FAIL+1)); say "  FAIL  $1  (wanted /$2/, got: $(head -c 160 <<<"$3" | tr '\n' ' '))"; fi
}
section() { say ""; say "── $* ──"; }

IP()  { $TF output -json vms | python3 -c "import sys,json; print(json.load(sys.stdin)['$1']['ip'])"; }
HUB_IP=$(IP hub); PROD_IP=$(IP prod); DEV_IP=$(IP dev)
inst() { echo "projects/$PROJECT_ID/zones/$ZONE/instances/lz-$1-vm"; }

section "1. Private by construction"
for v in hub prod dev; do
  ext=$(gcloud compute instances describe "lz-$v-vm" --zone "$ZONE" --project "$PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs)')
  check "lz-$v-vm has no external IP" '^$' "$ext"
done
shield=$(gcloud compute instances describe lz-prod-vm --zone "$ZONE" --project "$PROJECT_ID" --format='value(shieldedInstanceConfig.enableSecureBoot,shieldedInstanceConfig.enableVtpm)')
check "Shielded VM: secure boot + vTPM" 'True.*True' "$shield"
for v in hub prod dev; do
  open=$(gcloud compute network-firewall-policies describe "lz-$v" --global --project "$PROJECT_ID" --format=json 2>/dev/null \
    | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin)[0]['rules'] if r['action']=='allow' and r['direction']=='INGRESS' and '0.0.0.0/0' in r['match'].get('srcIpRanges',[])))") || open=err
  check "policy lz-$v: no allow-rule from 0.0.0.0/0" '^0$' "$open"
  vpcrules=$(gcloud compute firewall-rules list --project "$PROJECT_ID" --filter="network~/lz-$v\$" --format='value(name)' 2>/dev/null) || true
  check "policy lz-$v: no legacy VPC rules to bypass it" '^$' "$vpcrules"
done

section "2. Network Connectivity Center: star topology"
spokes=$(gcloud network-connectivity spokes list --project "$PROJECT_ID" --format='value(name.basename(),state,group.basename())' 2>/dev/null)
say "$spokes" | sed 's/^/    /'
for s in hub prod dev; do check "spoke lz-$s ACTIVE" "lz-$s.*ACTIVE" "$spokes"; done
check "hub spoke is in group 'center'" 'lz-hub.*center' "$spokes"
check "prod spoke is in group 'edge'"  'lz-prod.*edge'  "$spokes"
check "dev spoke is in group 'edge'"   'lz-dev.*edge'   "$spokes"

section "3. Connectivity Tests (Google's control-plane reachability analysis, no traffic sent)"
ct() { # <name> <src> <dst>
  gcloud network-management connectivity-tests delete "lz-$1" --project "$PROJECT_ID" --quiet >/dev/null 2>&1 || true
  gcloud network-management connectivity-tests create "lz-$1" --project "$PROJECT_ID" --protocol TCP --destination-port 8080 \
    --source-instance "$(inst "$2")" --destination-instance "$(inst "$3")" >/dev/null 2>&1
  for _ in $(seq 1 30); do
    r=$(gcloud network-management connectivity-tests describe "lz-$1" --project "$PROJECT_ID" --format='value(reachabilityDetails.result)' 2>/dev/null)
    [ -n "$r" ] && break; sleep 4
  done
  echo "${r:-NO_RESULT}"
}
check "prod -> hub  REACHABLE"   '^REACHABLE$'   "$(ct prod-hub prod hub)"
check "dev  -> hub  REACHABLE"   '^REACHABLE$'   "$(ct dev-hub dev hub)"
check "hub  -> prod REACHABLE"   '^REACHABLE$'   "$(ct hub-prod hub prod)"
check "prod -> dev  UNREACHABLE" '^UNREACHABLE$' "$(ct prod-dev prod dev)"
check "dev  -> prod UNREACHABLE" '^UNREACHABLE$' "$(ct dev-prod dev prod)"
say "    prod -> dev verdict trace:"
gcloud network-management connectivity-tests describe lz-prod-dev --project "$PROJECT_ID" \
  --format='value(reachabilityDetails.traces[0].steps[-1].description)' 2>/dev/null | sed 's/^/      /' | tee -a "$OUT"

section "3b. Routing tables: the isolation is the absence of a route"
for v in prod dev; do
  r=$(gcloud compute routes list --project "$PROJECT_ID" --filter="network~lz-$v\$" --format='value(destRange)')
  other=$([ "$v" = prod ] && echo 10.20.0.0/24 || echo 10.10.0.0/24)
  check "lz-$v learned the hub CIDR (10.0.0.0/24) from NCC" '10\.0\.0\.0/24' "$r"
  check "lz-$v has no route to the other edge spoke ($other)" '^0$' "$(grep -c "$other" <<<"$r" || true)"
done

section "4. Live data plane (IAP SSH into private VMs, real packets)"
http() { vm_ssh "lz-$1-vm" "curl -s -m 6 -o /dev/null -w '%{http_code}' http://$2:8080/ || true"; }
check "prod VM -> hub VM   :8080"  '^200$' "$(http prod "$HUB_IP")"
check "dev  VM -> hub VM   :8080"  '^200$' "$(http dev  "$HUB_IP")"
check "hub  VM -> prod VM  :8080"  '^200$' "$(http hub  "$PROD_IP")"
check "hub  VM -> dev  VM  :8080"  '^200$' "$(http hub  "$DEV_IP")"
check "prod VM -> dev VM   :8080 blocked" '^000$' "$(http prod "$DEV_IP")"
check "dev  VM -> prod VM  :8080 blocked" '^000$' "$(http dev  "$PROD_IP")"

section "5. Private DNS: hub zone, peered into the spokes"
dns() { vm_ssh "lz-$1-vm" "getent hosts $2 | awk '{print \$1}'"; }
check "hub  resolves shared.corp.internal"  "^$HUB_IP\$"  "$(dns hub  shared.corp.internal)"
check "prod resolves shared.corp.internal (peering)" "^$HUB_IP\$" "$(dns prod shared.corp.internal)"
check "dev  resolves shared.corp.internal (peering)" "^$HUB_IP\$" "$(dns dev  shared.corp.internal)"
check "prod resolves dev-app.corp.internal (name resolves, but is unreachable — DNS is not a route)" "^$DEV_IP\$" "$(dns prod dev-app.corp.internal)"
check "prod -> shared.corp.internal by name" '^200$' "$(vm_ssh lz-prod-vm "curl -s -m 6 -o /dev/null -w '%{http_code}' http://shared.corp.internal:8080/ || true")"

section "6. Egress only through Cloud NAT"
nat_ip=$(vm_ssh lz-prod-vm "curl -s -m 8 https://ifconfig.me || true")
check "prod VM reaches the internet (NAT IP seen)" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$nat_ip"
nats=$(gcloud compute routers get-status lz-prod --region "$REGION" --project "$PROJECT_ID" --format='value(result.natStatus[0].autoAllocatedNatIps[0])')
check "the IP seen from outside is the NAT gateway's allocated IP" "^${nat_ip:-none}\$" "$nats"

section "7. Denials are logged, alertable and counted"
vm_ssh lz-prod-vm "for i in 1 2 3 4 5; do curl -s -m 3 -o /dev/null http://$HUB_IP:9999/ || true; done; echo sent" >/dev/null
echo -n "  waiting for firewall log entries" | tee -a "$OUT"
denied=""
for _ in $(seq 1 24); do
  denied=$(gcloud logging read "logName:\"compute.googleapis.com%2Ffirewall\" AND jsonPayload.disposition=\"DENIED\" AND jsonPayload.connection.dest_port=9999" \
    --project "$PROJECT_ID" --freshness 15m --limit 1 --format='value(jsonPayload.rule_details.reference,jsonPayload.connection.src_ip,jsonPayload.connection.dest_ip)' 2>/dev/null)
  [ -n "$denied" ] && break; echo -n "." | tee -a "$OUT"; sleep 10
done; echo | tee -a "$OUT"
check "prod -> hub:9999 denied by the hub policy and logged" 'lz-hub' "$denied"
check "log-based metric exists"  'lz_firewall_ingress_denied' "$(gcloud logging metrics list --project "$PROJECT_ID" --format='value(name)')"
check "alert policy exists"      'denied ingress' "$(gcloud monitoring policies list --project "$PROJECT_ID" --format='value(displayName)' 2>/dev/null)"

section "8. Flow logs reach BigQuery"
flows=""
for _ in $(seq 1 30); do
  flows=$(bq --project_id "$PROJECT_ID" query --nouse_legacy_sql --format=csv \
    'SELECT COUNT(*) FROM `'"$PROJECT_ID"'.lz_flow_logs.compute_googleapis_com_vpc_flows`' 2>/dev/null | tail -1)
  [[ "$flows" =~ ^[1-9][0-9]*$ ]] && break; sleep 20
done
check "flow-log rows landed in BigQuery" '^[1-9][0-9]*$' "${flows:-0}"

say '```'; echo >> "$OUT"; echo "**Result: $PASS passed, $FAIL failed.**" >> "$OUT"
echo; [ "$FAIL" = 0 ] && ok "$PASS/$((PASS+FAIL)) checks passed" || warn "$FAIL failed, $PASS passed"
exit "$FAIL"
