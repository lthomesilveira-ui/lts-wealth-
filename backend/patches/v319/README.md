# Learn from corrections without letting derived natures outweigh them

After a user corrects an automatically assigned business nature, another derived
historical row can keep the old suggestion alive. An exact installment amount
can outrank the user's correction on a nearby amount from the same purchase;
equal merchant/amount scores can instead produce a false conflict.

The reader now chooses evidence strength, then original evidence over a derived
merchant nature, then the existing exactness priority. The existing proven
same-purchase cases (exact or within the existing five-cent tolerance, with the
required card, installment plan and purchase date) share one strength. Other
match strengths and every identity predicate remain unchanged. A weaker generic
preference cannot outweigh a stronger purchase match. Conflicting original
choices still require review.

Only historical decisions explicitly marked as verified merchant natures are
deprioritized. Other evidence is not relabeled as personal owner confirmation.
The public correction writer already records a new authenticated-user basis, so
a corrected row no longer carries the automatic marker. Suggestions continue
to require confirmation and do not infer a new person's or property's identity.

A complete function-definition lease preserves OID, owner, ACL, configuration
and all other catalog attributes. Source, financial, invoice, detail, decision,
catalog and rule hashes must remain exact across replacement. No data migration,
new endpoint, grant, timeout change or published UI change is introduced.

Native PostgreSQL 17 demonstrates both old failures and the corrected result,
checks stronger/weaker matches, conflicting original choices, unchanged behavior
without automatic evidence, hashes, attributes, replay, drift and roles. EXPLAIN
ANALYZE plans are retained for inspection rather than treated as a production
performance benchmark. Browser checks use the immutable V312 release at three
widths and synthetic native payloads only.
