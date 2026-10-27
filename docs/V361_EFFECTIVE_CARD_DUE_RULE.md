# Effective card due dates

An owner-confirmed cycle rule already moves received-composition forecasts, but legacy forecasts beyond that coverage retained the original day. The same rule now applies to unresolved Visa Aeternum forecasts on the matching bank from its effective month. The rule is a separate private owner configuration; no owner payload is committed here.

The existing 31-day scan runs before date filtering so a one-day query includes a forecast moved into that day and excludes its original day. Original dates, values, source references and classifications are preserved. Official invoice cash dates, confirmed facts, prior owner displacements, earlier months, unrelated sources and other owners remain intact. Latest effective rules win. No new expense or payment is created.

The migration leases the current function body, keeps its signature and ACL/security attributes, and is an exact no-op on replay. Native PostgreSQL CI checks synthetic dependencies, full/day query parity, source preservation and replay. Private rollout must additionally compare actual source/cash/expense snapshots and all visible consumers.
