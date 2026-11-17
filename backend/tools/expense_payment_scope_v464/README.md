# Expense payment scopes V464

Add separate card and account views over the same canonical expense rows. Channel selection uses exactly the existing expense-summary predicate: a card source table or a card coverage mode. Invoice settlement does not become another expense. Preserve signed refunds, original categories, source identities, owner/date validation and pagination.

Presentation cells now carry `payment: card | account`; total amounts remain unchanged. The detail reader accepts that explicit filter and rejects unknown channel values. Historical card totals without an individual breakdown retain their existing category and remain in card spending. The old cached presentation has a new cache namespace so it cannot silently lose the channel dimension.

Use a concrete gift/contribution group and preserve original person-named categories instead of replacing them with a vague family label. No source classifications or financial rows are rewritten. The private review profile gains the five exact reader definitions; all prior entries remain unchanged.

Native PostgreSQL 17 tests exercise the actual scope, presentation, detail and report bodies with synthetic canonical rows and isolated dependency fixtures. These establish reader correctness; published UI and real-session acceptance remain separate requirements.
