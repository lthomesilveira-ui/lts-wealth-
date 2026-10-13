# V266 validation scope

Private database checks performed on 13 October 2026:

- Nine checks passed for unresolved-invoice rollover, exact received composition, newer documentary precedence, closed-cycle preservation, wrong-currency rejection, wrong-cycle rejection, negative-probe rollback, original financial/source preservation, recurring-obligation evidence and lock access.
- The product probe passed four checks: all 730 daily rows across 2026–2027, 365 days of 2027 with required liquidity columns and daily arithmetic, current Flow/cash parity, and equal consecutive wealth facts.
- The only differing wealth metadata was `current_liquidity.computed_at`; the product probe excludes exactly that field.
- All 147 tested authenticated LTS routines rejected calls without subject/email claims with SQLSTATE 42501. This is a database-role test, not a signed HTTP session or physical-phone test.
- Expense identities remain unique; original source financial events and bank proof are unchanged.
- Daily backup integrity passed 13 checks. Full V248 PostgreSQL/Storage recovery remains unproved.
- Source invalidation/cold probes completed for Expenses, Wealth and the 2026–2027 Flow. Cold timings are not an end-to-end mobile latency guarantee.

Test mutations and caches were rolled back. No test decision, payment or financial adjustment was committed. The exact private receipt remains outside the public repository. Administrative leaked-password configuration, source gaps, physical-device acceptance and the complete historical/recovery backlog remain open.
