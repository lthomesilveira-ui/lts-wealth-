The published dashboard requested the approved five-year horizon, beyond the
1800-day slice-cache limit. The long branch rebuilt the same raw engine output
on a browser request (27.2 seconds in the reproduced foreground trace).

This patch changes only that raw call to an exact-range, owner-scoped derived
snapshot. It uses the same engine, current date and end date. It leaves the
1800-day branch, long-branch D+30 calculation, original financial sources,
unknowns, rounding and invoice overlays unchanged. The existing claimed worker
prepares that raw range once before operational publication; no new job or
concurrent execution is created. A failed/superseded worker rolls it back.

Reuse requires the original flow source key, global financial epoch, reviewed
producer/view/trigger definitions, all LTS program definitions, owner/day/range,
and payload digest. Guard changes raise 40001; unrecognized reviewed definitions
bypass reuse. Read-only misses compute the same result without a cache write.
Private functions remain service-only. Installation and rollback enforce the
observed definitions, owner, ACL, configuration and security mode.

Native PG17 verifies raw and full-current-flow parity including precision,
unknown D+30, independent owners/ranges, read-only hit/miss, corrupt digest,
source/epoch/program changes, disabled triggers, ACL and guarded lifecycle.
Live whole-screen acceptance remains necessary; test fixtures do not certify it.
