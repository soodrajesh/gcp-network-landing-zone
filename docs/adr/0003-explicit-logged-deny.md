# ADR 0003 — Explicit, logged deny-all in every firewall policy

**Status:** accepted

GCP's implicit "deny ingress" rule is **not logged**, so a blocked probe leaves no trace. Each VPC's network firewall policy therefore ends with priority-65000 `deny all` with logging enabled. Denials become `compute.googleapis.com/firewall` log entries, feed the `lz_firewall_ingress_denied` log-based metric, and trigger an alert above 50 denied packets per 5 minutes.

**Trade-off:** firewall logging has a per-GB cost. Only the deny rule logs (allow rules do not), so volume tracks *attacks and misconfigurations*, not normal traffic; VPC Flow Logs (5 s, 50 % sampling) cover the allowed traffic.

The policy is a **network firewall policy** (attached to the VPC, evaluated before classic VPC rules) rather than classic rules, so the tests can also assert that no legacy rule exists that could bypass it.
