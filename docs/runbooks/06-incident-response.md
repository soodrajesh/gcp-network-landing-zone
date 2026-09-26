# 06 · Incident response — denied-ingress alert

1. **Which VPC / who?** Run [04 §4](04-diagnose-connectivity.md): group by `src_ip` and `rule_details.reference`.
2. **Classify the source.**
   - Source in `10.10/10.20`: a workload is trying to cross the edge boundary — a bug or lateral movement. Identify the VM (`gcloud compute instances list --filter='networkInterfaces[0].networkIP=<ip>'`), preserve it (snapshot, do not delete), review its OS Login audit logs.
   - Source is public: shouldn't happen (no external IPs); check for an accidental external IP or forwarding rule: `gcloud compute addresses list`, `gcloud compute forwarding-rules list`.
3. **Contain:** add a higher-priority `deny` rule for the source to the affected policy (priority < 100), or detach the VM's service account.
4. **Recover / prove:** re-run `./scripts/test.sh`; all isolation checks must still pass.
5. **Post-incident:** add the scenario to `scripts/test.sh` and note the root cause in the PR.
