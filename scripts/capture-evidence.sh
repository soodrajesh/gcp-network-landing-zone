#!/usr/bin/env bash
# Re-captures the evidence in docs/evidence/*.txt from the LIVE landing zone (run after up.sh).
# Render to PNG: python3 docs/diagrams/termshot.py "<title>" docs/evidence/<f>.txt docs/img/<f>.png
source "$(dirname "$0")/lib.sh"; set +e
E="$ROOT/docs/evidence"; mkdir -p "$E"
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }

{ run "gcloud network-connectivity hubs describe lz-hub --project $PROJECT_ID --format='yaml(name,presetTopology,state)'"
  run "gcloud network-connectivity spokes list --project $PROJECT_ID --format='table(name.basename():label=SPOKE,group.basename():label=GROUP,state,linkedVpcNetwork.uri.basename():label=VPC)'"
  for v in prod dev; do run "gcloud compute routes list --project $PROJECT_ID --filter='network~lz-$v\$' --format='table(name:label=ROUTE,destRange:label=DEST,priority)'"; done
} > "$E/ncc-and-routes.txt"

{ for pair in "prod hub" "prod dev" "dev prod"; do set -- $pair
    run "gcloud network-management connectivity-tests describe lz-$1-$2 --project $PROJECT_ID --format='value(name.basename(),reachabilityDetails.result)'"
  done
  echo "\$ (prod-dev trace, final step)"; gcloud network-management connectivity-tests describe lz-prod-dev --project "$PROJECT_ID" \
    --format='value(reachabilityDetails.traces[0].steps[-1].description)'
} > "$E/connectivity-tests.txt"

HUB=$($TF output -json vms | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['hub']['ip'],d['prod']['ip'],d['dev']['ip'])")
set -- $HUB; H=$1; P=$2; D=$3
cu() { vm_ssh "lz-$1-vm" "curl -s -m 6 -w ' -> HTTP %{http_code}' http://$2:8080/ | tr '\\n' ' '"; echo; }
{ echo "\$ # from lz-prod-vm (10.10.0.2), over IAP SSH"
  echo "\$ curl hub :8080";  cu prod $H
  echo "\$ curl dev  :8080"; vm_ssh lz-prod-vm "curl -s -m 6 -o /dev/null -w 'HTTP %{http_code}' http://$D:8080/ ; echo ' (000 = no route / timeout)'"
  echo "\$ getent hosts shared.corp.internal dev-app.corp.internal"; vm_ssh lz-prod-vm "getent hosts shared.corp.internal dev-app.corp.internal | tr -s ' ' | tr '\\n' ';'"; echo
  echo "\$ # from lz-dev-vm"; echo "\$ curl prod :8080"; vm_ssh lz-dev-vm "curl -s -m 6 -o /dev/null -w 'HTTP %{http_code}' http://$P:8080/ ; echo ' (000 = no route / timeout)'"
} > "$E/data-plane.txt"

{ run "gcloud logging read 'logName:\"compute.googleapis.com%2Ffirewall\" AND jsonPayload.disposition=\"DENIED\"' --project $PROJECT_ID --freshness 1d --limit 3 --format='table(timestamp,jsonPayload.connection.src_ip:label=SRC,jsonPayload.connection.dest_ip:label=DST,jsonPayload.connection.dest_port:label=PORT,jsonPayload.rule_details.reference:label=RULE)'"
} > "$E/firewall-denials.txt"
ok "evidence written to docs/evidence/"
