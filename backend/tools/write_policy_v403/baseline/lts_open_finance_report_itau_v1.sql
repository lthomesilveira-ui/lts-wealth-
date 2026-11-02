CREATE OR REPLACE FUNCTION public.lts_open_finance_report_itau_v1(p_user_id uuid, p_run_id uuid DEFAULT NULL::uuid, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare r public.lts_open_finance_sync_run;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
  if p_offset<0 then raise exception 'INVALID_OFFSET'; end if;
  select s.* into r from public.lts_open_finance_sync_run s join public.lts_open_finance_connection c on c.id=s.connection_id
    where s.user_id=p_user_id and c.provider='pluggy' and c.institution_code='341' and (p_run_id is null or s.id=p_run_id)
    order by s.started_at desc limit 1;
  if r.id is null then return jsonb_build_object('status','not_synced','promotion_enabled',false); end if;
  return jsonb_build_object('run',to_jsonb(r),'total',(select count(*) from public.lts_open_finance_observation where sync_run_id=r.id),
    'offset',p_offset,'page_size',200,'promotion_enabled',false,'records',coalesce((select jsonb_agg(j) from (
      select jsonb_build_object('resource_type',o.resource_type,'provider_record_id',o.provider_record_id,'raw_hash',o.raw_hash,
        'normalized',o.normalized_payload,'reconciliation',o.reconciliation,'ingest_action',o.ingest_action) j
      from public.lts_open_finance_observation o where o.sync_run_id=r.id and o.user_id=p_user_id order by o.resource_type,o.provider_record_id limit 200 offset p_offset) q),'[]'::jsonb));
end $function$
