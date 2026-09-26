# Live test results

Captured by `scripts/test.sh` on 2026-09-26T22:16:05Z against project `claude-code-507112` (europe-west1).

```

── 1. Private by construction ──
  PASS  lz-hub-vm has no external IP  [ ]
  PASS  lz-prod-vm has no external IP  [ ]
  PASS  lz-dev-vm has no external IP  [ ]
  PASS  Shielded VM: secure boot + vTPM  [True	True ]
  PASS  policy lz-hub: no allow-rule from 0.0.0.0/0  [0 ]
  PASS  policy lz-hub: no legacy VPC rules to bypass it  [ ]
  PASS  policy lz-prod: no allow-rule from 0.0.0.0/0  [0 ]
  PASS  policy lz-prod: no legacy VPC rules to bypass it  [ ]
  PASS  policy lz-dev: no allow-rule from 0.0.0.0/0  [0 ]
  PASS  policy lz-dev: no legacy VPC rules to bypass it  [ ]

── 2. Network Connectivity Center: star topology ──
lz-prod	ACTIVE	edge
lz-hub	ACTIVE	center
lz-dev	ACTIVE	edge
  PASS  spoke lz-hub ACTIVE  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]
  PASS  spoke lz-prod ACTIVE  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]
  PASS  spoke lz-dev ACTIVE  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]
  PASS  hub spoke is in group 'center'  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]
  PASS  prod spoke is in group 'edge'  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]
  PASS  dev spoke is in group 'edge'  [lz-prod	ACTIVE	edge lz-hub	ACTIVE	center lz-dev	ACTIVE	edge ]

── 3. Connectivity Tests (Google's control-plane reachability analysis, no traffic sent) ──
  PASS  prod -> hub  REACHABLE  [REACHABLE ]
  PASS  dev  -> hub  REACHABLE  [REACHABLE ]
  PASS  hub  -> prod REACHABLE  [REACHABLE ]
  PASS  prod -> dev  UNREACHABLE  [UNREACHABLE ]
  PASS  dev  -> prod UNREACHABLE  [UNREACHABLE ]
    prod -> dev verdict trace:
      Final state: packet dropped due to packet with internal destination address sent to Internet Gateway.

── 3b. Routing tables: the isolation is the absence of a route ──
  PASS  lz-prod learned the hub CIDR (10.0.0.0/24) from NCC  [0.0.0.0/0 10.10.0.0/24 10.0.0.0/24 ]
  PASS  lz-prod has no route to the other edge spoke (10.20.0.0/24)  [0 ]
  PASS  lz-dev learned the hub CIDR (10.0.0.0/24) from NCC  [0.0.0.0/0 10.20.0.0/24 10.0.0.0/24 ]
  PASS  lz-dev has no route to the other edge spoke (10.10.0.0/24)  [0 ]

── 4. Live data plane (IAP SSH into private VMs, real packets) ──
  PASS  prod VM -> hub VM   :8080  [200 ]
  PASS  dev  VM -> hub VM   :8080  [200 ]
  PASS  hub  VM -> prod VM  :8080  [200 ]
  PASS  hub  VM -> dev  VM  :8080  [200 ]
  PASS  prod VM -> dev VM   :8080 blocked  [000 ]
  PASS  dev  VM -> prod VM  :8080 blocked  [000 ]

── 5. Private DNS: hub zone, peered into the spokes ──
  PASS  hub  resolves shared.corp.internal  [10.0.0.2 ]
  PASS  prod resolves shared.corp.internal (peering)  [10.0.0.2 ]
  PASS  dev  resolves shared.corp.internal (peering)  [10.0.0.2 ]
  PASS  prod resolves dev-app.corp.internal (name resolves, but is unreachable — DNS is not a route)  [10.20.0.2 ]
  PASS  prod -> shared.corp.internal by name  [200 ]

── 6. Egress only through Cloud NAT ──
  PASS  prod VM reaches the internet (NAT IP seen)  [34.79.187.133 ]
  PASS  the IP seen from outside is the NAT gateway's allocated IP  [34.79.187.133 ]

── 7. Denials are logged, alertable and counted ──
  waiting for firewall log entries
  PASS  prod -> hub:9999 denied by the hub policy and logged  [network:lz-hub/firewallPolicy:lz-hub	10.10.0.2	10.0.0.2 ]
  PASS  log-based metric exists  [lz_firewall_ingress_denied ]
  PASS  alert policy exists  [Landing zone: burst of denied ingress traffic ]

── 8. Flow logs reach BigQuery ──
  PASS  flow-log rows landed in BigQuery  [255 ]
```

**Result: 42 passed, 0 failed.**
