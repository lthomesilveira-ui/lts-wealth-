# V180 Homologation Publication Receipt — 2026-09-22

## Scope

This privacy-safe receipt records publication of the V180 candidate to the fixed homologation entry. It does not promote the public root and it does not represent user acceptance.

## Immutable references

- Candidate: `wip35-v180-candidate.html`.
- Tested product head: `9d1c926dca02b70b69a7add6a7afc0dfec5c6671`.
- Product merge: `810935171f77215e172c7617753695cce967a2c8` (PR #30).
- Fixed-entry exposure merge: `319789d06956c00171864dbe3e61bb60d961908f` (PR #31).
- Protected index SHA-256: `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`.

## Gates

- Candidate V180 workflow `35746263140`: SUCCESS.
- Exposure V180 workflow `35747307190`: SUCCESS.
- Protected V171–V177 pull-request regression matrix: SUCCESS.
- Pages deployment `35747832616`: SUCCESS.
- Published V180 served-byte and signed-out runtime workflow `35747837646`: SUCCESS.

The published workflow compared the served manifest, candidate, runtime overlays, review actions and protected root with the committed bytes. It also confirmed that a signed-out browser received the authentication surface without private detail.

## Authenticated published-browser evidence

Using the authorized signed-in notebook browser session, the fixed entry selected V180. The following sequence passed against the served site:

1. Fixed-entry arrival at the Dashboard.
2. Full browser reload.
3. Dashboard → Fluxo de caixa.
4. Verification of the current-day row against the Dashboard's complete components and total.
5. Fluxo de caixa → Dashboard.

After the reload and again after returning from Fluxo, the current-day cash reader reported `ready`, server status `complete`, matching business dates, all required finite components and a consistent sum. The RPC returned HTTP 200, all concurrent readers returned HTTP 200 and the reported incomplete-cash message was absent. The V180 expense-label and brokerage-reconciliation presentation contracts were also present.

## Limits and preserved work

- No production/root promotion was made.
- No physical-phone session was available; automated responsive/mobile regressions passed.
- User acceptance remains pending.
- Issues #23/#24, the April 2026 share-sale source gap, unsupported beneficiary/property identities, historical invoice-composition gaps and all earlier unclosed backlog items remain open.
- Private financial evidence and exact values are intentionally excluded from this public receipt.
