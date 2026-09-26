# 04 · Diagnose connectivity

**When:** "A can't reach B", or "A can reach B and shouldn't".

## 1. Ask Google (no packets sent)
```bash
gcloud network-management connectivity-tests create t1 --protocol TCP --destination-port 8080 \
  --source-instance projects/$PROJECT/zones/$ZONE/instances/lz-prod-vm \
  --destination-instance projects/$PROJECT/zones/$ZONE/instances/lz-dev-vm
gcloud network-management connectivity-tests describe t1 \
  --format='value(reachabilityDetails.result)'
gcloud network-management connectivity-tests describe t1 \
  --format='value(reachabilityDetails.traces[0].steps[-1].description)'
gcloud network-management connectivity-tests delete t1 --quiet
```
*Captured* (prod → dev): `UNREACHABLE`, final step: *"packet dropped due to packet with internal destination address sent to Internet Gateway."* — i.e. **no route** to 10.20.0.0/24, so the packet fell through to the default internet route and was dropped. The trace tells you which layer (route vs. firewall) is responsible.

## 2. Look at the routes
```bash
gcloud compute routes list --filter='network~lz-prod$' --format='table(name,destRange,priority)'
```
*Captured* (prod): `10.10.0.0/24` (own subnet), `10.0.0.0/24` (`ncc-subnet-route-…`, learned from the hub), `0.0.0.0/0` via internet gateway. **No `10.20.0.0/24`** — that absence *is* the isolation.

## 3. Send a real packet
```bash
gcloud compute ssh lz-prod-vm --zone $ZONE --tunnel-through-iap --command 'curl -s -m 6 -o /dev/null -w "%{http_code}\n" http://10.20.0.2:8080/'
```
`000` = timeout. `200` = reachable.

## 4. Is it the firewall?
```bash
gcloud logging read 'logName:"compute.googleapis.com%2Ffirewall" AND jsonPayload.disposition="DENIED"' --freshness 30m --limit 5 \
  --format='table(timestamp,jsonPayload.connection.src_ip,jsonPayload.connection.dest_ip,jsonPayload.connection.dest_port,jsonPayload.rule_details.reference)'
```
A row = a firewall policy dropped it (the `reference` names the policy). No row + `000` = routing problem.
