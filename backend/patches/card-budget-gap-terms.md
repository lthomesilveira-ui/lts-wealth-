# Card-budget term aware recurring-gap audit

This additive backend migration changes audit expectations only. It does not
change a card calculator, financial source, owner policy, UI, or published release.

The existing browser audit v5 routes to recurring audit v6. That audit assumes
monthly card spending continues through its horizon. The migration makes an
ended, validated historical-spending budget stop generating unsupported expected
months, while preserving exact documentary invoice/installment/source months.
It never fills the interval between two documented obligations.

## Safety behavior

- The generic helper reads the validated policy and canonical card schedule.
- No end date, missing schedule, incomplete schedule, mismatched identity,
  malformed/nonfinite source date or amount preserves the prior review behavior.
- Same-owner, same-series original obligations remain expected independently of
  the operational flow. Raw account spelling does not discard an obligation.
- Existing obligations, payments, cancellations, due transitions, whole-series
  closures, invalid-decision warnings and unrelated series retain their existing
  processing. No amount is generated or changed.
- Months outside expectations are omitted from the period details rather than
  labeled as a paid event or a confirmed due-date transition.
- An all-exempt card retains its no-gap horizon identity, preventing the Actions
  consumer from reviving the predecessor's legacy planning fallback.
- The helper is SECURITY INVOKER in an existing private schema, with no PUBLIC,
  anon or authenticated EXECUTE grant. The public RPC and its authorization are
  unchanged.

## Migration and rollback

The migration was created with the Supabase CLI. It transforms only exact neutral
fragments of the current audit function, guarded by complete before/after hashes.
It does not publish the existing function's private classification aliases.
Exact replay is a no-op; newer helper/audit edits fail the guard. Rollback has the
same drift protection and restores the prior audit before dropping the new helper.

Both files must be reviewed and applied through the normal authorized migration
workflow. This package is prepared code, not evidence of production installation.

## Tests

Requires Node and `@electric-sql/pglite` version 0.5.16. With the dependency
available to the repository, run:

```
node tests/card-budget-gap.test.mjs
ACTIONS_MODEL_FILE=path/to/lts-v333-actions-model.js node tests/card-gap-actions-consumer.cjs
```

The bundled tests use synthetic inputs only and check the helper and Actions
consumer contract. Separate local integration tests exercised the complete exact
predecessor, its transformed body, protected migration replay and exact rollback.
Those definitions and source-backed snapshots are intentionally not distributed.

The added canonical schedule read is evaluated once per audit invocation when an
eligible ended card budget exists. No new cache is introduced. End-to-end RPC
latency and authenticated rendered acceptance must be measured separately before
claiming a production fix; focused database fixtures do not establish either.
