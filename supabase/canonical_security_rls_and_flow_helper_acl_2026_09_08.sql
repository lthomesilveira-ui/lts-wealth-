-- LTS Wealth canonical RLS and SECURITY DEFINER hardening — 2026-09-08
-- Scope: defense in depth and API privileges only. No financial data or arithmetic changes.

do $$
declare
  v_missing text;
begin
  with expected(name) as (values
    ('lts_asset_market_valuation'),
    ('lts_card_history_recovery_staging'),
    ('lts_card_history_recovery_target'),
    ('lts_category_alias'),
    ('lts_dashboard_cockpit_cache'),
    ('lts_external_reference_fact'),
    ('lts_flow_future_read_cache_v2'),
    ('lts_homologation_stage_evidence'),
    ('lts_projection_audit_component'),
    ('lts_projection_audit_rule'),
    ('lts_semantic_amount_signature'),
    ('lts_taxonomy_ambiguity_guard'),
    ('lts_ui_artifacts')
  )
  select string_agg(e.name, ', ' order by e.name)
  into v_missing
  from expected e
  where to_regclass(format('public.%I', e.name)) is null;

  if v_missing is not null then
    raise exception 'security hardening aborted; missing tables: %', v_missing;
  end if;
end
$$;

alter table public.lts_asset_market_valuation enable row level security;
alter table public.lts_card_history_recovery_staging enable row level security;
alter table public.lts_card_history_recovery_target enable row level security;
alter table public.lts_category_alias enable row level security;
alter table public.lts_dashboard_cockpit_cache enable row level security;
alter table public.lts_external_reference_fact enable row level security;
alter table public.lts_flow_future_read_cache_v2 enable row level security;
alter table public.lts_homologation_stage_evidence enable row level security;
alter table public.lts_projection_audit_component enable row level security;
alter table public.lts_projection_audit_rule enable row level security;
alter table public.lts_semantic_amount_signature enable row level security;
alter table public.lts_taxonomy_ambiguity_guard enable row level security;
alter table public.lts_ui_artifacts enable row level security;

revoke all privileges on table
  public.lts_asset_market_valuation,
  public.lts_card_history_recovery_staging,
  public.lts_card_history_recovery_target,
  public.lts_category_alias,
  public.lts_dashboard_cockpit_cache,
  public.lts_external_reference_fact,
  public.lts_flow_future_read_cache_v2,
  public.lts_homologation_stage_evidence,
  public.lts_projection_audit_component,
  public.lts_projection_audit_rule,
  public.lts_semantic_amount_signature,
  public.lts_taxonomy_ambiguity_guard,
  public.lts_ui_artifacts
from public, anon, authenticated;

-- Internal financial engines accept an explicit user id and are called only by
-- owner-executed browser wrappers. They are not browser API endpoints.
revoke execute on function public.lts_daily_flow_fix86_v15(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_fix86_v16(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_fix86_v17(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_daily_flow_fix86_v18(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v4(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v5(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v6(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_cache_refresh_v7(uuid,integer) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v4(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v5(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v6(uuid,date,date) from public, anon, authenticated;
revoke execute on function public.lts_flow_future_read_slice_v7(uuid,date,date) from public, anon, authenticated;

-- These four browser wrappers derive the user from auth.uid() through
-- lts_browser_assert_user_v1; keep only the signed-in API role.
revoke execute on function public.lts_browser_flow_v7(date,date) from public, anon, authenticated;
revoke execute on function public.lts_browser_flow_v8(date,date) from public, anon, authenticated;
revoke execute on function public.lts_browser_flow_v9(date,date) from public, anon, authenticated;
revoke execute on function public.lts_browser_flow_v10(date,date) from public, anon, authenticated;
grant execute on function public.lts_browser_flow_v7(date,date) to authenticated;
grant execute on function public.lts_browser_flow_v8(date,date) to authenticated;
grant execute on function public.lts_browser_flow_v9(date,date) to authenticated;
grant execute on function public.lts_browser_flow_v10(date,date) to authenticated;

-- Secure-by-default for objects created by later postgres-owned migrations.
-- Browser RPCs and intentionally exposed relations must grant access explicitly.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon, authenticated;

do $$
declare
  v_bad integer;
begin
  with expected(name) as (values
    ('lts_asset_market_valuation'),
    ('lts_card_history_recovery_staging'),
    ('lts_card_history_recovery_target'),
    ('lts_category_alias'),
    ('lts_dashboard_cockpit_cache'),
    ('lts_external_reference_fact'),
    ('lts_flow_future_read_cache_v2'),
    ('lts_homologation_stage_evidence'),
    ('lts_projection_audit_component'),
    ('lts_projection_audit_rule'),
    ('lts_semantic_amount_signature'),
    ('lts_taxonomy_ambiguity_guard'),
    ('lts_ui_artifacts')
  )
  select count(*) into v_bad
  from expected e
  join pg_namespace n on n.nspname = 'public'
  join pg_class c on c.relnamespace = n.oid and c.relname = e.name
  where not c.relrowsecurity
     or has_table_privilege('public', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE')
     or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE');

  if v_bad <> 0 then
    raise exception 'security hardening aborted; table postcondition failures: %', v_bad;
  end if;

  with restricted(signature) as (values
    ('public.lts_daily_flow_fix86_v15(uuid,date,date)'),
    ('public.lts_daily_flow_fix86_v16(uuid,date,date)'),
    ('public.lts_daily_flow_fix86_v17(uuid,date,date)'),
    ('public.lts_daily_flow_fix86_v18(uuid,date,date)'),
    ('public.lts_flow_future_read_cache_refresh_v4(uuid,integer)'),
    ('public.lts_flow_future_read_cache_refresh_v5(uuid,integer)'),
    ('public.lts_flow_future_read_cache_refresh_v6(uuid,integer)'),
    ('public.lts_flow_future_read_cache_refresh_v7(uuid,integer)'),
    ('public.lts_flow_future_read_slice_v4(uuid,date,date)'),
    ('public.lts_flow_future_read_slice_v5(uuid,date,date)'),
    ('public.lts_flow_future_read_slice_v6(uuid,date,date)'),
    ('public.lts_flow_future_read_slice_v7(uuid,date,date)')
  )
  select count(*) into v_bad
  from restricted r
  where to_regprocedure(r.signature) is null
     or has_function_privilege('public', to_regprocedure(r.signature), 'EXECUTE')
     or has_function_privilege('anon', to_regprocedure(r.signature), 'EXECUTE')
     or has_function_privilege('authenticated', to_regprocedure(r.signature), 'EXECUTE');

  if v_bad <> 0 then
    raise exception 'security hardening aborted; internal function ACL failures: %', v_bad;
  end if;

  with browser(signature) as (values
    ('public.lts_browser_flow_v7(date,date)'),
    ('public.lts_browser_flow_v8(date,date)'),
    ('public.lts_browser_flow_v9(date,date)'),
    ('public.lts_browser_flow_v10(date,date)')
  )
  select count(*) into v_bad
  from browser b
  where to_regprocedure(b.signature) is null
     or has_function_privilege('public', to_regprocedure(b.signature), 'EXECUTE')
     or has_function_privilege('anon', to_regprocedure(b.signature), 'EXECUTE')
     or not has_function_privilege('authenticated', to_regprocedure(b.signature), 'EXECUTE');

  if v_bad <> 0 then
    raise exception 'security hardening aborted; browser function ACL failures: %', v_bad;
  end if;

  select count(*) into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  if v_bad <> 0 then
    raise exception 'security hardening aborted; anonymous SECURITY DEFINER functions remain: %', v_bad;
  end if;

  select count(*) into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
    and lower(pg_get_functiondef(p.oid)) not like '%lts_browser_assert_user_v1(%'
    and lower(pg_get_functiondef(p.oid)) not like '%auth.uid()%'
    and lower(pg_get_functiondef(p.oid)) not like '%auth.jwt()%';

  if v_bad <> 0 then
    raise exception 'security hardening aborted; unguarded authenticated SECURITY DEFINER functions remain: %', v_bad;
  end if;
end
$$;

notify pgrst, 'reload schema';
