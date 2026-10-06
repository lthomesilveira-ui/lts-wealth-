# V252 private legacy pending-card mutator
The unused legacy pending-card reconciler has SECURITY DEFINER/PUBLIC execution
and no user assertion. It also infers reversal from staging absence and maps
positive card refunds to income. No database or cron caller was found; code
search and the frozen V245 runtime/adapter found no caller.

Revoke external execution from PUBLIC, anon, authenticated and service_role.
Keep its body and financial rows unchanged and never invoke it. The exact source
lease and no-caller guards prevent applying this patch over an unexpected change.
An operator rollback probe verifies external permissions, exact body/financial
rows and restoration of every function definition and ACL. Only a private
receipt persists. This addresses exposure, not the unresolved financial lifecycle
of the sixteen legacy pending events.

Source: Supabase security advisor's exposed SECURITY DEFINER function finding;
remediation https://supabase.com/docs/guides/database/database-linter
No frontend, auth policy, banking action or source deletion is introduced.

