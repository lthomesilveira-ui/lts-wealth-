# V254 exact Flow reuse for existing Dashboard callers

Several frozen Dashboard components still call lts_browser_flow_v241 directly. Those calls bypass the enclosing V242 memo and repeat the same financial calculation. The patch keeps the original V241 calculator as a private engine and reuses its exact response for the authenticated owner, exact period, business date, source epoch and bank freshness. It changes no financial output or frontend file.

Live transactional full-JSON/repeat parity passed for the current Dashboard horizon, 2027 and the July boundary. Original calculation timings were 4448.4 / 3640.5 / 4399.4 ms; exact reused responses were 9.1 / 7.2 / 3.2 ms. These compare recomputation with valid exact reuse, not before/after cold calculation speed or phone acceptance. First calculations remain necessary after source changes.

Independent source epoch invalidation recomputed an exact private-engine result. Missing authentication cannot read an existing memo; invalid ranges and the caller's ACL are preserved. The cloned engine has no PUBLIC, anon, authenticated or service_role EXECUTE. Genuine stale-cache misses in a local read-only transaction preserve complete output without writes.

The existing private warm routine also prepares the exact current-date-to-next-year horizon used by Dashboard components. Its original return contract, service-only ACL, claim restoration and calendar schedule are preserved. No cron or automation is added. Exact source leases protect both replaced routines. All candidate DDL, derived caches and epoch fixtures rolled back before application.

Source gaps, cold whole-flow construction, owner browser sign-in/visual acceptance, financial source completeness and the wider backlog remain open. Frozen V245, historical sources, classifications, pending card events, balances and the bank consent connections are preserved.
