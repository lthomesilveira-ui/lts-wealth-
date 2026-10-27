# Respect a cancellation already confirmed by the owner

The monthly coverage audit could continue listing a missing forecast for an original occurrence that the owner had explicitly cancelled. The read-only audit now distinguishes `cancelled_by_owner` from a payment or a future event. It includes the exact date, source reference and existing decision rule, while preserving other missing months and every financial fact.

An exception requires an active source-specific suppression rule, an owner confirmation, an exact one-day scope and matching owner, source reference, original description, account, date and expense direction. The raw source row must be unique. Broad rules, inferred decisions, changed or ambiguous sources, and income rows cannot create this exception. It applies to a monthly coverage period only; it does not renew or cancel a series or an annual obligation.

The patch leases the inspected production function definition and preserves its identity, ACL, owner, security configuration and every attribute except its body. Replay reverses all replacements and verifies the original lease before doing nothing. No rule, raw record, payment, projection, expense, source document or classification is written.

Native PostgreSQL checks execute the actual leased audit body and prior V303/V306/V334 contracts with isolated synthetic dependencies. They verify the one cancelled period, unchanged other series and periods, thirteen rejected identities/scopes, source preservation and idempotent replay. Real source and consumer comparisons must precede production validation; synthetic tests do not establish private owner HTTP acceptance.
