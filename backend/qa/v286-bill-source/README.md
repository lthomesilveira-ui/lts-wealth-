# Received-bill source validation

The received-bill reader previously cast regular-expression matches directly to
dates and timestamps, called `jsonb_array_length` without checking its input type,
and could ignore a malformed payment beside an otherwise sufficient payment.
The new private, invoker helper validates these inputs before they can establish
an issuer revision or settlement. Collection time does not establish an issuer
revision. Recognizing a payment type never replaces the exact account, adjacent
cycle, date, currency, unique-identity, fee and amount checks.

The patch retains the reader's signature, ownership, configuration and grants.
The helper is unavailable to `PUBLIC`, `anon` and `authenticated`; no financial
relation or user decision is written. `OTHER_PAYMENT`, observed in provider
payloads, is recognized alongside the existing values under the same guards.
The receipt timestamp and source update timestamp remain distinct.

CI uses PostgreSQL 17.6 in a disposable database. Its 41 field-validation cases
and 32 received-reader cases cover invalid calendars, malformed JSON, missing or
unqualified issuer timestamps, contradictory payment identities, repeated fees,
currency, account and owner mismatches, and payment dates outside the prior cycle.
The family resolver is a deliberately minimal fixture; production family
classification is verified separately with deployed-source comparisons.

Apply `bill_source_fields.sql` and `received_bill_reader.sql` in one guarded
transaction after checking the current reader fingerprint. The committed patch
requires the reviewed previous reader; migration history and a verified result
are required before considering it deployed. The production transaction and its
private audit receipt are separate from these synthetic CI tests.

This is source validation. It does not infer a new contractual due day, bind an
unknown BillID to an obligation, update old cycles, create a payment or integrate
the separate date-only temporal overlay. A full isolated PostgreSQL/Storage
restore and a signed browser session remain separate acceptance work.

Primary references:

- https://www.postgresql.org/docs/17/functions-info.html
- https://docs.pluggy.ai/pt/docs/products/credit-card-bills
