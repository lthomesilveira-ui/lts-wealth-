# Coordinate bank collection with expensive reads

A collection could begin while the shared admission queue was still executing a
guarded report. The database correctly rejected a response when its source
revision changed. Retrying that report during the same collection could fail
again. Waiting for the initial cash read alone did not cover other screen owners.

V341 holds admission for expensive reads before requesting collection. It lets
the already admitted report finish, starts the existing bank collection once,
and releases admission after completion, a failed collection, a request error,
the existing collection timeout, or session cancellation. The holder is scoped
to its operation, releases once, and has a 90-second upper bound. A canceled older
refresh cannot release a newer session's holder. Expiring before the admitted
read finishes cancels collection rather than starting it over that read.

Cash and connection status remain independent; financial writers keep their
existing immediate, uncached behavior. Read execution limits, the 60-second
admission limit, request priorities, deduplication, cache invalidation, source
revision guards, financial sources and database functions are unchanged. A
long-running collection can still outlast a queued report's existing limit; no
deadline is expanded and existing errors/retry controls remain available.

The runtime change is limited to the transport and the collection owner. The
static contract reconstructs each changed file from the immutable V339 source
with exact scheduling edits. All other runtime assets, core, formulas, financial
readers, classifications, writers, month model and late-component recovery remain
byte-identical. The app wrapper only changes its release label and cache suffix.

The deterministic contract executes both actual runtimes with synthetic sources:
it reproduces V339's overlap and simulated revision rejection, proves V341 waits
for the admitted read, holds later expensive reads while allowing cash/status,
and covers release paths, cancellation, stale owners, independent nested holders,
queued aborts, unchanged queue expiry and finite holder expiry. The existing
admission contract also checks all nine expensive reader kinds, mutation
passthrough, timeout recovery and authentication-free telemetry.

Browser checks render the actual release at desktop and mobile widths, preserve
monthly/bank displays, canonical actions, financial totals, Flow and its 365-day
export, and retain recovery after a late prerequisite and real frame replacement.
Fixtures do not certify production sign-in, a physical phone, all cold starts,
cross-session admission or complete documentary evidence. Another session or a
provider job can still update a source during a read; the database guards remain
necessary and authoritative.
