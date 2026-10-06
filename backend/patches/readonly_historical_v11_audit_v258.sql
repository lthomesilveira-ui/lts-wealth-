-- Historical v242 cache misses also call the legacy v11 audit.
-- Preserve normal table audit and report only the specific readonly failure in server logs.
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_browser_flow_v11(date,date)'::regprocedure))<>'41acefeb3d39f3de1a5e5db9355e2046'
 THEN RAISE EXCEPTION 'V258_READONLY_V11_SOURCE_LEASE_CHANGED';END IF;
END $lease$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v11(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare uid uuid; v_email text:=lower(coalesce(auth.jwt()->>'email','')); oldj jsonb; histflow jsonb; cf jsonb; flow jsonb;
begin
  uid:=public.lts_browser_assert_user_v1();
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  if (p_to-p_from)>12000 then raise exception 'range too large'; end if;
  if p_to<current_date then
    oldj:=public.lts_browser_flow_v3(p_from,p_to);
    flow:=public.lts_flow_historical_exact_transfer_overlay_v1(uid,p_from,p_to,oldj->'flow');
    flow:=flow||jsonb_build_object('version','daily-flow-browser-v11-historical-truth');
  elsif p_from>=current_date then
    cf:=public.lts_flow_future_read_slice_v9(uid,p_from,p_to);
    flow:=jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',current_date,
      'historical',jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb),'current_future',cf,
      'version','daily-flow-browser-v11-future-v20-award-milestones');
  else
    oldj:=public.lts_browser_flow_v3(p_from,current_date-1);
    histflow:=public.lts_flow_historical_exact_transfer_overlay_v1(uid,p_from,current_date-1,oldj->'flow');
    cf:=public.lts_flow_future_read_slice_v9(uid,current_date,p_to);
    flow:=jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',p_from,
      'historical',histflow->'historical','current_future',cf,
      'version','daily-flow-browser-v11-mixed-truth-award-milestones',
      'historical_own_transfer_contract',histflow->'historical_own_transfer_contract');
  end if;
  flow:=public.lts_flow_documentary_close_overlay_v1(uid,flow);
  flow:=public.lts_flow_classification_source_overlay_v1(uid,flow);
  if p_from<current_date then flow:=public.lts_flow_historical_balance_truth_overlay_v1(uid,flow); end if;
  flow:=flow||jsonb_build_object('bank_evidence_as_of',(select jsonb_agg(jsonb_build_object(
    'bank',institution,'date',metadata->>'balance_as_of','documentary_balance',metadata->'balance') order by institution)
    from public.accounts where user_id=uid and is_active));
  begin
  insert into public.lts_access_audit(user_id,email,action,meta) values(uid,v_email,'browser_rpc_flow_read',
    jsonb_build_object('rpc_version',17,'from',p_from,'to',p_to,'historical_truth',p_from<current_date,'award_milestones',p_to>=current_date));
  exception when read_only_sql_transaction then
    raise log 'LTS_FLOW_READ_AUDIT_READONLY rpc_version=17 principal=% from=% to=%',md5(uid::text),p_from,p_to;
  end;
  return jsonb_build_object('ok',true,'flow',flow);
end
$function$
;
