BEGIN;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE audit_before_v258(j jsonb,audit_before bigint,audit_after bigint) ON COMMIT DROP;
DO $before$ DECLARE j jsonb;a bigint;b bigint;BEGIN
 SELECT count(*) INTO a FROM public.lts_access_audit WHERE user_id=public.lts_open_finance_pilot_owner_v1();
 j:=public.lts_browser_flow_v1('2026-09-29',current_date);
 SELECT count(*) INTO b FROM public.lts_access_audit WHERE user_id=public.lts_open_finance_pilot_owner_v1();
 IF b-a<>1 THEN RAISE EXCEPTION 'V258_BASELINE_AUDIT_COUNT';END IF;
 INSERT INTO audit_before_v258 VALUES(j,a,b);
END $before$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v1(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid; v_email text:=lower(coalesce(auth.jwt()->>'email','')); s date; e date; part jsonb; base jsonb:=null;
  hd jsonb:='[]'::jsonb; he jsonb:='[]'::jsonb; fd jsonb:='[]'::jsonb; fe jsonb:='[]'::jsonb; chunks int:=0;
  q_from date;
  v_anchor date := date '2026-08-18';
  a_cons numeric; a_cons_rel numeric; a_itau numeric; a_itau_rel numeric; a_brad numeric; a_brad_rel numeric; a_c6 numeric; a_c6_rel numeric;
begin
  v_uid:=public.lts_browser_assert_user_v1();
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if (p_to-p_from)>12000 then raise exception 'range too large'; end if;
  q_from := case when p_from >= current_date then p_from when p_from > v_anchor then v_anchor else p_from end;
  s:=q_from;
  while s<=p_to loop
    e:=least(s+730,p_to); chunks:=chunks+1;
    part:=public.lts_daily_flow_full_query_v6(v_uid,s,e);
    if base is null then base:=part; end if;
    hd:=hd||coalesce(part#>'{historical,days}','[]'::jsonb);
    he:=he||coalesce(part#>'{historical,events}','[]'::jsonb);
    fd:=fd||coalesce(part#>'{current_future,days}','[]'::jsonb);
    fe:=fe||coalesce(part#>'{current_future,events}','[]'::jsonb);
    s:=e+1;
  end loop;

  select
    nullif(x#>>'{Consolidado,bank_balance}','')::numeric,
    nullif(x#>>'{Consolidado,relative_balance}','')::numeric,
    nullif(x#>>'{Itaú,balance}','')::numeric,
    nullif(x#>>'{Itaú,relative_balance}','')::numeric,
    nullif(x#>>'{Bradesco,balance}','')::numeric,
    nullif(x#>>'{Bradesco,relative_balance}','')::numeric,
    nullif(x#>>'{C6,balance}','')::numeric,
    nullif(x#>>'{C6,relative_balance}','')::numeric
  into a_cons,a_cons_rel,a_itau,a_itau_rel,a_brad,a_brad_rel,a_c6,a_c6_rel
  from jsonb_array_elements(hd) x where x->>'date'=v_anchor::text limit 1;

  if a_cons is not null then
    select coalesce(jsonb_agg(
      case when (x->>'date')::date > v_anchor then
        jsonb_set(jsonb_set(jsonb_set(jsonb_set(x,
          '{Consolidado,bank_balance}',to_jsonb(a_cons + coalesce(nullif(x#>>'{Consolidado,relative_balance}','')::numeric,0) - coalesce(a_cons_rel,0)),true),
          '{Itaú,balance}',to_jsonb(coalesce(a_itau,0) + coalesce(nullif(x#>>'{Itaú,relative_balance}','')::numeric,0) - coalesce(a_itau_rel,0)),true),
          '{Bradesco,balance}',to_jsonb(coalesce(a_brad,0) + coalesce(nullif(x#>>'{Bradesco,relative_balance}','')::numeric,0) - coalesce(a_brad_rel,0)),true),
          '{C6,balance}',to_jsonb(coalesce(a_c6,0) + coalesce(nullif(x#>>'{C6,relative_balance}','')::numeric,0) - coalesce(a_c6_rel,0)),true)
        || jsonb_build_object('absolute_balance_basis','carried certified 2026-08-18 close + observed facts only','absolute_balance_certified',false,'balance_context','post_anchor_carry_forward')
      else x end order by x->>'date'),'[]'::jsonb)
    into hd from jsonb_array_elements(hd) x;
  end if;

  select coalesce(jsonb_agg(x order by x->>'date'),'[]'::jsonb) into hd from jsonb_array_elements(hd) x where (x->>'date')::date between p_from and p_to;
  select coalesce(jsonb_agg(x order by x->>'event_date'),'[]'::jsonb) into he from jsonb_array_elements(he) x where (x->>'event_date')::date between p_from and p_to;
  select coalesce(jsonb_agg(x order by x->>'date'),'[]'::jsonb) into fd from jsonb_array_elements(fd) x where (x->>'date')::date between p_from and p_to;
  select coalesce(jsonb_agg(x order by x->>'event_date'),'[]'::jsonb) into fe from jsonb_array_elements(fe) x where (x->>'event_date')::date between p_from and p_to;

  base:=coalesce(base,'{}'::jsonb) || jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',q_from,'historical',jsonb_build_object('days',hd,'events',he),'current_future',jsonb_build_object('days',fd,'events',fe));
  begin
  insert into public.lts_access_audit(user_id,email,action,meta)
  values(v_uid,v_email,'browser_rpc_flow_read',jsonb_build_object('rpc_version',6,'from',p_from,'to',p_to,'calculation_context_from',q_from,'chunks',chunks,'historical_events',jsonb_array_length(he),'future_events',jsonb_array_length(fe),'future_fast_path',p_from>=current_date));
  exception when read_only_sql_transaction then
    raise log 'LTS_FLOW_READ_AUDIT_READONLY rpc_version=6 principal=% from=% to=% chunks=%',md5(v_uid::text),p_from,p_to,chunks;
  end;

  return jsonb_build_object('ok',true,'flow',base);
end
$function$
;
DO $after$ DECLARE j jsonb;a bigint;b bigint;BEGIN
 SELECT count(*) INTO a FROM public.lts_access_audit WHERE user_id=public.lts_open_finance_pilot_owner_v1();
 j:=public.lts_browser_flow_v1('2026-09-29',current_date);
 SELECT count(*) INTO b FROM public.lts_access_audit WHERE user_id=public.lts_open_finance_pilot_owner_v1();
 IF b-a<>1 OR j::text IS DISTINCT FROM (SELECT x.j::text FROM audit_before_v258 x) THEN RAISE EXCEPTION 'V258_AUDIT_OR_FINANCIAL_OUTPUT_CHANGED';END IF;
 PERFORM set_config('lts.v258_audit',jsonb_build_object('pass',true,'same_json_and_text',true,'digest',md5(j::text),'audit_row_each_writable_call',1)::text,true);
END $after$;
SELECT current_setting('lts.v258_audit')::jsonb receipt;ROLLBACK;
