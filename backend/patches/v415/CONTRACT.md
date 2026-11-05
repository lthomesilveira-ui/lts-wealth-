# V415 durable product refresh

The browser never builds the full product on a cache miss. Existing complete financial payloads remain available while a private background task refreshes derived caches. No financial source writes, tax assumptions, classifications, authorization claims, or API timeouts change.

## Public RPCs

`lts_browser_product_refresh_status_v415()` is read-only and lightweight. `lts_browser_product_refresh_request_v415()` explicitly requests/retries maintenance and coalesces an existing pending/running request. Neither accepts an owner argument: both assert the actual signed-in user.

Both return `{"ok":true,"refresh":{...}}`. The product RPC also returns this `refresh` object at the top level, alongside its existing `cache` and `mvp` fields. A missing/incompatible cache returns `mvp:null`; no partial financial object or fabricated zero is returned. A pending complete snapshot is served only when the existing V307 completeness memo is valid for the same owner/date/epoch/source fingerprint, with the existing V269 presentation protections applied. If that proof is absent, `mvp:null` is returned even with `cached_available:true`; the full payload remains intact in storage while the UI waits.

| Field | Contract |
| --- | --- |
| state | `ready`, `pending`, `running`, or `failed` |
| required | Boolean; false only when complete current cache and queue completion agree |
| cached_available | Boolean; a compatible full payload is available, even if awaiting refresh |
| request_version, completed_version | Decimal **strings**, including `"0"` for a legacy ready cache |
| attempts | Integer, maximum three automatic attempts per request |
| requested_at, started_at, completed_at, next_attempt_at | Timestamp or null |
| error_code | Safe enum or null; never SQL/error text |
| cached_refreshed_at | Timestamp or null |
| server_today | Date in America/Sao_Paulo |

Safe errors: `refresh_failed`, `refresh_timed_out`, `refresh_busy`, `refresh_superseded`, `refresh_access_changed`, `refresh_contract_invalid`.

A consumer may fetch the full product after `state=ready`, `required=false`, and `BigInt(completed_version)>=BigInt(request_version)`. Repeated status polling never changes versions/attempts. Existing manual projection refresh retains reference/materialization/read-policy behavior and appends `refresh`; its existing `refreshed` flag does not imply that the product refresh has completed.

## Private worker

Namespace `lts_product_refresh_private_v415`; table `queue`; functions `enqueue(uuid,text,boolean)`, `status(uuid)`, `prepare(boolean)`, `run_claimed()`. Queue claims are committed before heavy work. The cron command has two explicit BEGIN/COMMIT phases; a private session claim token carries identity across those phases, without touching JWT or authorization context. Claim validation uses persisted token/version and the active allowlist plus real Auth user.

The pending-only worker runs every minute. The existing daily 03:05 UTC job keeps its schedule and identity, and uses the same worker. The existing 03:01 recurrence job keeps its business calls. Its invalidation preserves product payloads, supersedes the request version, and increments the existing epoch. When a worker/cache lock is busy, deletion of lower derived caches is deferred to the next claimed transaction; no long queue-row lock or contested cache-row wait is introduced.

Existing cache: operational v5. The same private transaction warms the existing C6 completeness memo before `ready`; a missing/outdated memo also makes lightweight status require maintenance, so browser opening does not trigger a cold completeness calculation. Missing/incompatible cache: full v2 **then** operational v5. The worker removes canonical markers inside its transaction to force a current operational result. It publishes only after full-contract validation, matching source epoch and V307 card/documentary fingerprint, and unchanged claim/request version. The fingerprint also covers the receipt and documentary fields that have no epoch trigger. Any mismatch/failure rolls back all derived cache changes and retains the prior complete product. New source invalidation supersedes work in flight. Automatic retries use 30-second then 120-second backoff, with a 12-minute crash lease and three attempts. Only background execution has a 600-second budget; browser/API budgets remain unchanged.

Public status never exposes owner IDs, source identifiers, SQL text, or private claim tokens. The private schema/table has no PUBLIC/anon/authenticated grants and has RLS enabled. Rollout does not enqueue, invalidate, or recalculate the currently fresh product.
