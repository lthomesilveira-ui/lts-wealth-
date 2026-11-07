# Expense and pending-cash clarity

Additive immutable UI based on V421. Expense group details show original group/subgroup labels and compensated subtotals only after all detail pages reconcile to the existing total. Clicking a subgroup filters the existing rows without changing classification. The loan parent display alias preserves original scope keys.

A card projection supplement is labeled as additional budget, not another invoice. The existing source balances and cash movements remain unchanged.

Pending bank evidence is fetched only when the affected day's detail is opened. The read-only authenticated function selects all pending movements from the same owner, connection, account and provider snapshot as the observed bank position. Old snapshots, posted rows, other accounts and malformed inputs cannot form a certified bridge. The UI requires exact arithmetic against the observed balance and continues to say that bank confirmation is pending. No balancing event, settled payment or yield is invented.

The private definer function uses the existing authenticated-owner assertion, an empty search path and restricted execution grants. Native tests use invented identities, not real sessions. Browser fixtures are invented and do not certify a physical device or private-session acceptance. Publication, installation and verification remain separate steps.
