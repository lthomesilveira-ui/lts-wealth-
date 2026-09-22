# LTS Wealth — V181 homologation publication

Business date: 22/09/2026. Fixed homologation entry: `homologacao.html`; selected candidate: `wip35-v181-candidate.html`. This receipt records agent-run verification, not the user's acceptance.

## Source and exposure

- Product PRs #33–#36 culminated in `9cce166287f2d6213c1ee48547df3f1db642145e`; the V181 candidate loads the v181c runtime.
- Fixed-entry exposure PR #37 merged as `7a885d5a35204cc40e6661aa19369e89b3a65b01`. The served manifest selected `wip35-v181` and the candidate head above. The Pages manifest response reported `Last-Modified: Tue, 22 Sep 2026 19:43:59 GMT`; prior to publication the fixed entry had still served V180.
- PR #37 passed its nine pull-request workflows, including V181 run `35774614697`, V180 run `35774614718`, and inherited V171–V177 gates. No push-associated Pages or signed-out smoke run was returned for the exposure merge; do not claim those jobs passed.
- Protected root `index.html` SHA-256 remains `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`. No production/root promotion occurred.

## Published authenticated browser

- The authorized browser opened the fixed entry, redirected to the V181 candidate, and displayed the V181 release label. The Dashboard loaded complete, dated current-day cash after login and again after a full reload. No incomplete-cash message appeared.
- The Flow's current-day total matched the Dashboard. On the user-reported due date, the daily row and expanded movement showed exactly one documentary Bradesco invoice and no legacy projection in cash.
- Dashboard → Flow → Dashboard returned the complete current-day position. The direct V181 candidate had also passed this path before exposure.
- In the direct candidate, all seven eligible documentary card cycles were reconciled to one Flow obligation per cycle with zero difference; the non-actionable inventory panel was absent. The authenticated review queue had 137 unresolved identities, no preset choice and disabled save buttons until a decision. No real classification was written.
- The category views were alternative partitions of one selected-period total; the monthly table displayed inputs, expenses and result. A long apartment detail reached the final row by actual scrolling. The two aggregate-only invoice coverage rows explicitly said purchase-level statements are needed.

## Open limits

- User acceptance and physical-phone testing remain open. Responsive/automated checks are not a physical-phone test.
- Ambiguous identities, historical invoices without purchase composition and the missing original source for the April 2026 share sale remain open. No values, people or purchase details were fabricated.
- A fresh signed-out published smoke run was not evidenced by a post-merge workflow. The authenticated fixed-entry path above is the required closure evidence for the reported cash failure.
- Continue all prior backlog items and issues #23/#24 according to their own evidence. No release declaration closes them by implication.
