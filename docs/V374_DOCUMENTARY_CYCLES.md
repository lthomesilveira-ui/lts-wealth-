# V374: documentary cycle groups

A reviewed cycle can contain several original workbook entries and several distinct bank invoices. Every original signed amount remains authoritative. The documentary sum must match the original net; every member and every document is checked before the composition is shown. New unmatched rows or changed companion entries invalidate the binding.

Each item retains its own PDF, page, column, card, issuer category and printed day/month. Document dates are identified separately. An original invoice year is not guessed from a purchase day/month. Recovered composition is marked as available in the expense list, removing the contradictory missing-source note. Existing workbook sources and published readers take precedence.

These private tables affect no ledger, expense category, cash movement or forecast. Public RPCs use SECURITY INVOKER and delegate to owner-checked private readers. Internal helpers that accept prepared canonical rows have no authenticated execute permission. Tests use synthetic sources only and cover original membership, multiple PDF provenance, stale sources, access isolation, financial preservation, pagination and rendered mobile/desktop behavior.
