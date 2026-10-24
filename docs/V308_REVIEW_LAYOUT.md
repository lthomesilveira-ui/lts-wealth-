# V308 — Compact projection review

The Actions projection audit exposed every monthly button for every series at
once. On a phone this created a long page before the owner could locate a
specific missing forecast or unconfirmed payment.

V308 keeps the existing per-series counts, missing-month warnings and direct
period action visible. Monthly buttons and their historical reference amount
are in a native disclosure, closed initially. A year-scoped filter selects all
series, missing forecasts or payments needing evidence. Its counter always
shows the visible and total series; an empty result explicitly identifies the
filter rather than claiming that the backlog is empty. Expansion and filter
choices survive background renders and are cleared when the boot/session
generation changes. Years retain separate choices.

The small-screen schedule panel also retains its touch target sizes while
reducing vertical padding by two pixels on each edge below 400px.

This is an isolated successor to the V296 interface. All inherited assets are
byte-identical except the release wrapper/provenance; the new layout script
only rearranges existing DOM elements. It adds no API call, financial writer,
projection, payment or classification. The existing period buttons still open
the same exact Flow dates. Earlier published releases and the root remain
unchanged. Backend readers remain the current V307 definitions.

`lts_v308_release_contract.cjs` checks every declared asset, inherited hashes
and protected releases. `lts_v308_browser.cjs` uses the real ordered release
stack with explicitly synthetic API replies at desktop, 390px and 360px. It
exercises disclosure/filter persistence, two years, empty filters, exact Flow
navigation and physical navigation controls, plus the inherited receipt,
classification, invoice and six-screen regressions. These tests do not certify
an authenticated production browser session or a physical phone.
