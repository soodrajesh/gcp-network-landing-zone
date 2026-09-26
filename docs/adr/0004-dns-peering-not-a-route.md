# ADR 0004 — One private zone in the hub, DNS-peered into spokes

**Status:** accepted

`corp.internal.` lives once in the hub VPC. Prod and dev get *peering* zones pointing at the hub, so there is one place to manage records. Records for `prod-app` and `dev-app` are in the same zone, so **prod resolves `dev-app.corp.internal` to 10.20.0.2 — and still cannot reach it.** The test suite asserts exactly this: name resolution is not a network path, and a visible name is not a leak.

**Trade-off:** hub DNS is a shared dependency; DNS query logging is enabled on every VPC via a DNS policy so resolution can be audited.
