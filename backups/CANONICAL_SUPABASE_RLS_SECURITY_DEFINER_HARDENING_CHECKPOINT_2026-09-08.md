# LTS Wealth — Supabase RLS and SECURITY DEFINER Hardening Checkpoint

Immutable evidence recorded: 2026-09-08 01:56 BRT (America/Sao_Paulo).

## Purpose

This checkpoint records the bounded database-security package applied after Dashboard Fidelity Pass 6. It preserves browser behavior and financial semantics while removing client reachability to internal arbitrary-user helpers. It does not claim physical-device homologation or change the public product target.

## Applied migration

- Supabase project: `tadhkamnwtsbdozwkyut`.
- Version: `20260908045049`.
- Name: `canonical_security_rls_and_flow_helper_acl_2026_09_08`.
- Repository source: `supabase/canonical_security_rls_and_flow_helper_acl_2026_09_08.sql`.
- Scope: RLS and privileges only; no financial fact, arithmetic, classification, projection or user-facing value changed.

## Threat model resolved

The initial table-grant audit alone was insufficient. Although `anon` and `authenticated` had no direct DML privilege on the 13 tables, postgres default privileges had made 16 SECURITY DEFINER functions executable by `anon`:

- four browser Flow wrappers v7-v10, each guarded by `lts_browser_assert_user_v1`;
- twelve internal daily-flow/cache helpers accepting an explicit `user_id`, with no browser ownership guard.

The twelve helpers could execute as their postgres owner for an arbitrary supplied user and therefore represented a real cross-user privilege boundary failure. The canonical app does not call them directly; it calls guarded browser RPCs such as `lts_browser_flow_v8`.

## Changes

- Enabled RLS on the 13 audited internal tables.
- Revoked all table privileges from `PUBLIC`, `anon` and `authenticated`; no direct client policies were added, so access is deny-by-default.
- Revoked client EXECUTE from four daily-flow engines, four future-cache refresh helpers and four future-slice helpers.
- Restricted `lts_browser_flow_v7`, `v8`, `v9` and `v10` to `authenticated`; each derives the current user through the browser allowlist guard.
- Revoked postgres-owned future defaults that would otherwise auto-grant client access to functions, tables and sequences in `public`.
- Preserved owner/internal call chains and `service_role` privileges.
- Reloaded the PostgREST schema after the transaction committed.

## Exact postflight

- Audited tables found: 13; RLS enabled: 13; without direct client DML: 13.
- Restricted helpers found: 12; closed to `PUBLIC`, `anon` and `authenticated`: 12.
- Browser Flow wrappers authenticated-only: 4/4.
- Anonymous-executable SECURITY DEFINER functions in `public`: 0.
- Authenticated-executable SECURITY DEFINER functions without direct `lts_browser_assert_user_v1`, `auth.uid()` or `auth.jwt()` guard under the catalog audit rule: 0.
- Client default privileges remaining for postgres-owned public functions/tables/sequences: 0.
- `service_role` default privilege entries remain present.

## Authenticated contract regression

The database test selected an existing allowed authenticated identity without emitting its identifier, installed equivalent JWT claims locally in one transaction, switched to the `authenticated` role and verified:

- `lts_browser_flow_v8(current_date, current_date + 7)` returned `ok=true`;
- `lts_browser_dashboard_cockpit_v1()` returned an object;
- `lts_browser_product_v1()` returned an object.

The transaction then reset the role and rolled back. No test mutation or financial fact was retained.

## Security Advisor after migration

- `rls_disabled_in_public`: 0 for the 13 target tables.
- `anon_security_definer_function_executable`: 0 globally in `public`.
- 13 `rls_enabled_no_policy` INFO notices are expected for the new internal deny-by-default tables.
- 65 `authenticated_security_definer_function_executable` warnings remain because the Advisor flags intended browser RPC reachability; the catalog postcondition found all 65 directly guarded under the audited rule.
- One `auth_leaked_password_protection` warning remains. This is a separate Supabase Auth configuration change and was not altered by the database migration.

## Preserved release boundary

- Canonical product target remains `9ae0ee37ab3332415523eeee287cdbf75102e1c4`.
- Homologation exposure remains `4d3c7bc912a672ae7353c7028d8b05d047961dd5` underneath documentation/security evidence commits.
- Protected `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- `promotion_status:not_promoted` remains binding.
- No authenticated physical-iPhone E2E is claimed by this checkpoint.

## Next autonomous sequence

1. Keep the security postconditions in the durable release receipt and review every new SECURITY DEFINER RPC against the same guard rule.
2. Close refresh/session route restoration and the unified definition-of-done receipt.
3. Continue evidence-led Dashboard, Despesas and Atualizações refinement.
4. Review leaked-password protection in a controlled Auth window.
5. Keep real authenticated write/search/document/backup-restore and physical-iPhone claims open until actually executed.
