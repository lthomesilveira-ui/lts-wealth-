# Canonical app implementation note

Single frontend entrypoint: `canonical-app.html`.

This file intentionally contains no historical release iframe chain. It directly owns authentication/session presentation, the six product routes and read-only RPC consumption for `lts_browser_product_v1` and `lts_browser_dashboard_cockpit_v1`.

Deterministic visual QA may use `canonical-app.html?fixture=1`, which is explicitly badged and must never be interpreted as real financial data. Normal runtime contains no synthetic financial values.
