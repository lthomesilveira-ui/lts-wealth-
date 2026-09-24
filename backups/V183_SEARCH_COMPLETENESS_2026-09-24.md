# V183 — historical search completeness

Authenticated inspection reproduced a silent first-page ceiling in Updates: a search returned 200 rows and no continuation. Existing source navigation/edit rules must remain intact.

The candidate-only adapter paginates the existing history-search RPC before returning its rows to the existing UI. It checks declared counts, page sizes, duplicate identities and current query generation. A changed query stops remaining reads. A failed page produces an explicit error, never a partial count labelled complete. Queries above 10,000 results require refinement. Other transaction readers and all writers pass through unchanged.

Seven synthetic tests cover complete pagination, empty results, pass-through, failed/changed/duplicate pages, query replacement, limits and protected-entry isolation. Published real-session validation remains required; no production-root or fixed-homologation promotion and no financial writes.
