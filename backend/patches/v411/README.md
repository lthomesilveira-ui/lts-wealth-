# V411 — owner confirmed RSU cash estimates

This patch applies a confirmed owner's conservative reserve to projected regular
RSUs and Cash RSUs. It keeps the source gross amounts, quantities, vesting dates,
settlement assumptions, available brokerage money, and realized history intact.
The reserve is a planning assumption, not a statement of the person's tax rate.

## Policy and valuation

The private `lts_owner_rsu_policy_v411` namespace is the sole activation source.
It is scoped by `usuario_id`, validated before use, and seeded separately with
document references and an audit. No personal policy, document, position, or
amount is embedded in this patch or its tests.

Each configured award's cash estimate is `round(gross * net_factor, 2)`. Aggregates
sum these component results. A Cash RSU that already has a 70% estimate is not
multiplied by 70% again. The existing automatic quote stage remains the source of
gross estimates; manual and automatic inputs follow the same owner policy.
A missing gross value is rejected before aggregation, so a partial `SUM` cannot
quietly hide an unknown component.

An owner without this namespace retains the exact existing monetary calculations
and labels. New policy-only net fields are unknown for that owner, and the new
RPC returns `enabled=false` before reading or validating their legacy schedule.
An existing empty or malformed namespace is an error rather than silent fallback
to the old gross estimate. A malformed namespace belonging to another owner
cannot affect the caller's view or RPC.

Available brokerage cash and already available share positions are preserved.
The source field for available shares does not establish whether sell-to-cover
has already occurred, so this patch applies no second reserve to that position.
The dated statement's gross fields remain gross. Unknown residual components are
not assigned an invented net value; a policy-enabled statement net total is
explicitly limited to known components.

## Grant cohorts and the separate corporate scenario

`lts_browser_rsu_policy_v411()` returns a source-backed gross/net schedule with
individual components, plus a separate conditional corporate transaction view.
An event date is not inferred from receipt of an image. An undated brokerage
reference cannot replace the dated available-position anchor.

For a scheduled award, acceleration eligibility requires a documentary grant ID
and grant date, a source-document reference, and a matching grant entry in the
owner's policy. Grant dates before 2026 are eligible for a conditional scenario;
2026 and later are excluded. Unmapped components remain unknown. Equal quantities
or shared vesting dates never establish a grant link.

The existing anticipation writer checks every member of a selected group. A group
containing an excluded or unknown grant cannot bypass the cutoff. The separate
scenario RPC validates the same rule, preserves source dates, and performs no
financial write. The corporate scenario itself remains conditional with no
confirmed event date and no cash-flow effect until separately documented.

Employment retention awards and payroll calculations are outside this migration.
The RPC can display the separately confirmed payroll policy, but does not create
salary forecasts or reinterpret historical net payments.

## Installation and cache consistency

The CLI-created migration is assembled from `preconditions.sql`,
`owner_rsu_cash_policy.sql`, `consumer_patch.sql`, and `postconditions.sql`.
Rebuild it with:

```bash
python3 backend/tools/rsu_policy_v411/build_migration.py
python3 backend/tools/rsu_policy_v411/build_migration.py --check
```

The migration rejects unknown view/function definitions. Fifteen existing
consumers are changed through exact predecessor/result fingerprints, preserving
their identity, owner, permissions, and configuration. The new private helpers
use `SECURITY INVOKER`, a fixed empty search path, and service-only execution.
The authenticated RPC retains the existing browser owner assertion. The effective
view remains a service-only, security-invoker view. The existing available-value
overlay and the older cash-ladder adapter remain unchanged.

After installing changed definitions, the migration advances the existing cache
epoch once and removes only derived product, cockpit, future-flow, and v229 cache
rows for owners with the policy namespace. This is required even if the policy
seed advanced the epoch before the DDL. An unchanged replay neither advances the
epoch nor clears those caches again. No cron, source/history row, payment, or
notification to a person is changed. The Data API receives only its internal
schema-reload notification.

## Verification

`backend/tools/rsu_policy_v411/test_sql.py` reconstructs the existing baseline
from already published repository SQL and adds two synthetic owners. It does
not copy live function snapshots or financial fixtures. The test runs the full
migration in a reverted transaction, applies it, replays it, verifies the output
contracts, and tests exact-definition drift rejection.

The native PostgreSQL17 workflow checks owner isolation, all legacy monetary
fields across fourteen readers, component rounding, missing values, manual and
automatic quotes, price writers, mixed/unknown grant guards, source-history
preservation, available-position preservation, ACLs, cache invalidation and
idempotence. Local PostgreSQL17.5/PGlite execution is additional evidence;
native CI and the production read-only proof remain separate gates.

Use a read-only post-install comparison of source/history fingerprints, installed
definitions, owner policy, effective components, grant-link counts, and the next
scheduled flow addition. Production row counts and source hashes belong in the
private execution record, not this repository.
