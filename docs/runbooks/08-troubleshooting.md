# 08 · Troubleshooting — problems actually hit while building this

| # | Symptom | Cause | Fix |
|---|---|---|---|
| L1 | Test "prod → hub PASS" but the output contained SSH key-generation text | First IAP SSH generates a key and prints to stdout; my regex matched the `200` line anywhere → **false pass** | `vm_ssh` now returns only the last line (`tail -1`); checks anchor `^200$` |
| L2 | `gcloud compute network-firewall-policies rules list` → *Invalid choice* | No such command | `network-firewall-policies describe <p> --global --format=json` returns `[ { rules: [...] } ]` |
| L3 | Test run hung for ever at "alert policy exists" | `gcloud alpha …` prompts to install the alpha component | Use GA `gcloud monitoring policies list` |
| L4 | BigQuery check returned 0 rows | Partitioned sink writes one table `compute_googleapis_com_vpc_flows`, not date-sharded `…_*` | Query the table directly |
| L5 | `terraform` showed NCC groups already exist | With `preset_topology = STAR` the hub creates `center` and `edge` itself | Reference them by path `${hub.id}/groups/edge`; do not manage them as resources |
| L6 | A test script stopped at the first failure | `lib.sh` sets `set -e`; test suite must continue and count | `test.sh` does `set +e` after sourcing |
| L7 | Alpha/beta command names differ from docs | gcloud surface moves | Prefer GA commands; verify with `--help` before putting them in a runbook |
