# V300 — income review first-read acceptance

These are manual, private SQL probes, not migrations or public CI fixtures.
They extend the V298 first-read check to the complete income review queue.
No production reader, financial source, decision, privilege or published asset
is changed by this package. The frontend remains V296.

Run `lts_v300_income_cold_rollback.sql` twice, in separate transactions, then
`lts_v300_income_warm_rollback.sql`. Keep all three receipts private. Each probe
calls the real public RPC under `authenticated`, with its existing eight-second
statement limit and the complete historical date range. The first page is 25
rows; `row_count`, `matched_count` and pagination must not be confused with a
full download of every pending row when more than 25 exist.

Acceptance requires all of the following:

- Both cold probes and the normal probe succeed, with measured `elapsed_ms`
  greater than zero and at most 8,000; the unchanged role and limit are returned.
- The complete `payload` JSON and `queue_digest` agree across all three probes,
  including identities, descriptions, classifications, edit tokens and paging.
  If a source changes concurrently or the local date rolls over, investigate
  rather than ignoring the difference or relabeling it a pass.
- Each transaction ends with `ROLLBACK`. Afterwards, an administrative read of
  `lts_v229_read_cache` must find zero rows with the unique
  `source_fingerprint = 'v300-income-cold-rollback'` marker. Do not remove data
  or suppress a failed probe to obtain a passing receipt.

The cold setup invalidates all disposable memo keys/dates for the pilot owner
and increments the source epoch only inside a rolled-back transaction. It does
not clear source rows, structural read models or shared PostgreSQL buffers.
The test therefore measures disposable-memo-cold RPC execution, not a universal
SLA, cold physical storage, private HTTP authentication or a physical device.
It does not certify every page, search filter, date range or frontend consumer.

The private V300 trial passed twice cold and once normal with identical complete
queue JSON; the rollback marker was absent afterwards. Receipt values and
financial transaction details are deliberately not included in this repository.
No global/role timeout increase, financial classification or card-settlement
assumption was used to pass the test.
