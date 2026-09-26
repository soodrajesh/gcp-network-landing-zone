# 05 · Observability queries

**Top talkers (BigQuery, from flow logs)** — verified against the live dataset:
```bash
bq query --nouse_legacy_sql '
SELECT jsonPayload.connection.src_ip AS src, jsonPayload.connection.dest_ip AS dst,
       jsonPayload.connection.dest_port AS port,
       SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS bytes, COUNT(*) AS flows
FROM `'$PROJECT'.lz_flow_logs.compute_googleapis_com_vpc_flows`
WHERE DATE(timestamp) = CURRENT_DATE() GROUP BY 1,2,3 ORDER BY bytes DESC LIMIT 10'
```
*Captured:* rows such as `10.10.0.2 → 172.217.113.4:443` (prod egress through NAT) and `35.235.240.x → 10.20.0.2:22` (IAP tunnel into dev).

**Denied ingress (Logging):** see [04 §4](04-diagnose-connectivity.md).

**DNS queries:**
```bash
gcloud logging read 'logName:"dns.googleapis.com%2Fdns_queries"' --freshness 30m --limit 5
```

**NAT problems** (only errors are logged, e.g. port exhaustion):
```bash
gcloud logging read 'resource.type="nat_gateway"' --freshness 1d --limit 5
```
**The alert:** policy *"Landing zone: burst of denied ingress traffic"* — > 50 denied packets in 5 min → email.
