#!/usr/bin/env python3
"""Generates docs/img/architecture.svg (PNG via docs/diagrams/render.py).

    python3 docs/diagrams/architecture.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from archlib import Diagram  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "img", "architecture.svg")

W, H = 1700, 1560
d = Diagram(W, H, "Hub-and-Spoke Network Landing Zone on Google Cloud",
            "Network Connectivity Center (star) · network firewall policies · private DNS peering · Cloud NAT · IAP · flow logs · Terraform")

d.group(190, 100, 1480, 700, "Google Cloud project  ·  region europe-west1  ·  three custom-mode VPCs", "#1a73e8", dash=False, fill="#f8faff", label_w=560)

# operator (outside the project) -> IAP
d.node("op", 70, 250, "Operator", "user", "actor", "gcloud ssh\n--tunnel-through-iap")
d.node("iap", 70, 430, "Identity-Aware\nProxy", "key", "security", "OS Login · IAM\nno bastion, no keys")
d.edge("op", "iap", "v", num=1, half_a=28, half_b=28)

# NCC hub
d.node("ncc", 930, 190, "", "globe", "network")
d.text(970, 150, "Network Connectivity Center hub", 12.5, "#202124", "600")
d.text(970, 166, "preset topology STAR · center + edge groups", 11, "#5f6368")

def vpc(cx, name, cidr, grp, label_w):
    d.group(cx - 220, 290, 440, 420, f"VPC lz-{name}  ·  {cidr}  ·  {grp}", "#8e44ad", dash=True, fill="#faf5fd", label_w=label_w)

vpc(430, "prod", "10.10.0.0/24", "edge", 330)
vpc(930, "hub", "10.0.0.0/24", "center", 340)
vpc(1430, "dev", "10.20.0.0/24", "edge", 320)

for cx, n, sub in ((430, "prod", "app workload"), (930, "hub", "shared services"), (1430, "dev", "app workload")):
    d.node(f"vm_{n}", cx - 100, 410, f"lz-{n}-vm", "pod", "compute", f"e2-micro · {sub}\nno external IP · Shielded")
    d.node(f"fw_{n}", cx + 100, 410, "Firewall policy", "wall", "security", "IAP ssh · approved\nCIDRs · deny + log")
    d.node(f"nat_{n}", cx + 100, 585, "Cloud NAT", "nat", "network", "egress only\nno inbound")
d.node("dns_hub", 830, 585, "Private zone", "dns", "network", "corp.internal\nshared · prod-app · dev-app")
d.node("dnsp_prod", 330, 585, "DNS peering", "dns", "network", "corp.internal → hub")
d.node("dnsp_dev", 1330, 585, "DNS peering", "dns", "network", "corp.internal → hub")

# 1: IAP into private VMs
d.path([(100, 430), (240, 430), (240, 410), (302, 410)], num=None)

# 2: NCC spoke attachments
d.path([(430, 290), (430, 190), (890, 190)], num=2, label="spoke · edge", lab_at=(560, 190), color="#8e44ad")
d.path([(930, 290), (930, 222)], num=2, color="#8e44ad")
d.text(945, 262, "spoke · center", 11.5, "#8e44ad", "600")
d.path([(1430, 290), (1430, 190), (970, 190)], num=2, label="spoke · edge", lab_at=(1300, 190), color="#8e44ad")

# 3: allowed spoke <-> hub
d.path([(560, 430), (600, 430), (600, 470), (760, 470), (760, 430), (802, 430)], num=3, color="#1e8e3e")
d.path([(1060, 430), (1100, 430), (1100, 470), (1260, 470), (1260, 430), (1302, 430)], num=3, color="#1e8e3e")
d.text(680, 492, "learned routes via hub", 11, "#1e8e3e", "600", "middle")
d.text(1180, 492, "learned routes via hub", 11, "#1e8e3e", "600", "middle")

# 4: prod <-> dev blocked
d.path([(430, 710), (430, 775), (1430, 775), (1430, 710)], num="✗", color="#d93025", dash=True)
d.text(930, 758, "prod ⇄ dev: no route between edge spokes (NCC) AND spoke firewalls admit only the hub CIDR", 12, "#d93025", "700", "middle")

# outside

# ── operations band ──────────────────────────────────────────────────────────────────────────────
d.band(190, 850, 1480, 210, "OBSERVABILITY  ·  every layer leaves evidence", "#1e8e3e", "#f6fcf8")
d.node("fl", 290, 960, "VPC Flow Logs", "chart", "ops", "5 s, 50 % sample\nall metadata")
d.node("bq", 520, 960, "BigQuery", "db", "data", "lz_flow_logs\npartitioned, 7-day TTL")
d.node("lg", 770, 960, "Cloud Logging", "policy", "ops", "firewall · DNS · NAT")
d.node("lm", 1000, 960, "Log-based metric", "filter", "ops", "denied ingress\nby VPC")
d.node("al", 1230, 960, "Alert policy", "bolt", "ops", "> 50 denies / 5 min\n→ email")
d.node("bu", 1470, 960, "Budget", "money", "ops", "€ alerts at 50 / 100 %")
d.edge("fl", "bq", "h", num=7, label="log sink")
d.edge("lg", "lm", "h")
d.edge("lm", "al", "h")

d.band(190, 1080, 1480, 130, "GOVERNANCE  ·  preventive controls", "#d93025", "#fff8f7")
d.text(220, 1124, "No external IPs anywhere · Shielded VMs (secure boot, vTPM, integrity) · OS Login, project SSH keys blocked · SSH only via IAP", 12.5, "#3c4043")
d.text(220, 1148, "Firewall policy per VPC: allow-list first, then an explicit logged deny-all (the implicit deny is silent) · non-overlapping CIDRs required by NCC", 12.5, "#3c4043")
d.text(220, 1172, "Least privilege: VM service accounts hold no roles · operator gets IAP tunnel + OS Login only · state in a versioned, private bucket", 12.5, "#3c4043")

d.legend(34, 1250, "Numbered flows", [
    ("1", "Operator authenticates to IAP with their Google identity and is tunnelled to a private VM. Nothing is exposed to the internet"),
    ("2", "Each VPC is a spoke on the NCC hub. Hub = center group; prod and dev = edge group (edges reach the center, never each other)"),
    ("3", "Allowed path: prod↔hub and dev↔hub via routes NCC exports; proven by Connectivity Tests and live curl"),
    ("✗", "Blocked path: no route between edge spokes; Connectivity Test says UNREACHABLE and live curl times out"),
    ("7", "Flow logs are sunk to BigQuery; firewall denials feed a log-based metric and an alert policy"),
], w=1630)
d.key(34, 1470)

if __name__ == "__main__":
    d.save(OUT)
    print("wrote", os.path.abspath(OUT))
