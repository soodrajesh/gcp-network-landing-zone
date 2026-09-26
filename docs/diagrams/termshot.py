#!/usr/bin/env python3
"""Render a captured text file as a terminal-style PNG (headless Chrome).

    python3 docs/diagrams/termshot.py <title> <in.txt> <out.png>
"""
import html
import re
import sys

from playwright.sync_api import sync_playwright

title, src, dst = sys.argv[1:4]
txt = re.sub(r"\x1b\[[0-9;]*m", "", open(src, encoding="utf-8").read()).rstrip("\n")


def cls(line):
    if re.search(r"\bPASS\b", line): return "p"
    if re.search(r"\b(FAIL|ERROR)\b", line): return "f"
    if line.startswith("$ "): return "c"
    if line.startswith("──") or line.startswith("=="): return "h"
    return ""


body = "\n".join(f'<span class="{cls(l)}">{html.escape(l)}</span>' for l in txt.split("\n"))
page = f"""<html><body style="margin:0;background:#fff"><div style="display:inline-block;margin:0;padding:14px">
<div style="background:#1e1f24;border-radius:10px;box-shadow:0 4px 18px rgba(0,0,0,.25);overflow:hidden;min-width:1000px">
<div style="background:#2b2d33;padding:9px 14px;color:#bbb;font:12px -apple-system,Helvetica,sans-serif">
<span style="color:#ff5f56">●</span> <span style="color:#ffbd2e">●</span> <span style="color:#27c93f">●</span> &nbsp; {html.escape(title)}</div>
<pre style="margin:0;padding:14px 18px;color:#d6d6d6;font:13px/1.5 Menlo,Monaco,monospace">{body}</pre></div></div>
<style>.p{{color:#5fd068}}.f{{color:#ff6b6b;font-weight:700}}.c{{color:#7cc7ff}}.h{{color:#ffd166;font-weight:700}}</style></body></html>"""
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome")
    pg = b.new_page(viewport={"width": 1300, "height": 800}, device_scale_factor=2)
    pg.set_content(page)
    pg.locator("div").first.screenshot(path=dst)
    b.close()
print("wrote", dst)
