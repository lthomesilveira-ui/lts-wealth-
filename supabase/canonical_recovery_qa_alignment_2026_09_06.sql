-- LTS Wealth canonical recovery QA alignment — 2026-09-06
-- Scope: QA expectation only. No financial, product, cache or mutation logic changes.
-- The liquidity refresh transactional QA still expected the pre-03/09 cockpit version.
-- Current audited cockpit contract is dashboard-cockpit-v2-documentary-fgts-no-projection.

do $$
declare
  v_oid oid;
  v_def text;
begin
  select p.oid into v_oid
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='lts_liquidity_refresh_v2_transactional_qa_v1'
    and pg_get_function_identity_arguments(p.oid)='p_user_id uuid';

  if v_oid is null then
    raise exception 'lts_liquidity_refresh_v2_transactional_qa_v1(uuid) not found';
  end if;

  v_def:=pg_get_functiondef(v_oid);

  if position('dashboard-cockpit-v1-claude-layout-audited' in v_def)=0 then
    raise exception 'expected stale cockpit QA contract not found';
  end if;

  execute replace(
    v_def,
    'dashboard-cockpit-v1-claude-layout-audited',
    'dashboard-cockpit-v2-documentary-fgts-no-projection'
  );
end
$$;
