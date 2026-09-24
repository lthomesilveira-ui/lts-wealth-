-- Run only through an authorized administrator. Every synthetic row is rolled back.
begin;
set local role service_role;
do $$
declare uid uuid:=public.lts_open_finance_pilot_owner_v1();
  item text:='11111111-1111-4111-8111-111111111111'; c uuid; r uuid; r2 uuid; r3 uuid; result jsonb; x jsonb; denied boolean;
begin
  if has_table_privilege('anon','public.lts_open_finance_observation','SELECT') or has_table_privilege('authenticated','public.lts_open_finance_staging','SELECT') then raise exception 'TEST_FAIL_DIRECT_ACCESS'; end if;
  if has_function_privilege('anon','public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb)','EXECUTE')
    or has_function_privilege('authenticated','public.lts_open_finance_enqueue_itau_v1(text,text,text)','EXECUTE') then raise exception 'TEST_FAIL_RPC_ACCESS'; end if;
  r:=gen_random_uuid();
  result:=public.lts_open_finance_begin_itau_v1(uid,item,jsonb_build_object('id',item,'status','UPDATED','executionStatus','SUCCESS'),r);
  c:=(result->>'connection_id')::uuid;
  denied:=false;
  begin
    perform public.lts_open_finance_begin_itau_v1(uid,item,jsonb_build_object('id',item,'status','UPDATED','executionStatus','SUCCESS'),gen_random_uuid());
  exception when others then denied:=sqlerrm='SYNC_ALREADY_RUNNING'; end;
  if not denied then raise exception 'TEST_FAIL_CONCURRENT_SYNC'; end if;
  if not (public.lts_open_finance_begin_itau_v1(uid,item,jsonb_build_object('id',item,'status','UPDATED','executionStatus','SUCCESS'),r)->>'existing')::boolean then raise exception 'TEST_FAIL_REQUEST_IDEMPOTENCY'; end if;
  x:=jsonb_build_object('resource_type','investment','provider_record_id',item||':synthetic','raw_hash',repeat('a',64),
    'currency','BRL','signed_amount',90,'raw_payload',jsonb_build_object('id','synthetic','balance',90),
    'normalized_payload',jsonb_build_object('item_id',item,'net_valuation',90,'gross_valuation',100,'withdrawal_available',0,'liquidity',null),
    'provider_updated_at','2026-09-24T12:00:00Z','reconciliation',jsonb_build_object('classification','new','reason','synthetic','candidates','[]'::jsonb));
  perform public.lts_open_finance_stage_batch_v1(uid,c,r,jsonb_build_array(x));
  perform public.lts_open_finance_stage_batch_v1(uid,c,r,jsonb_build_array(x));
  if (select count(*) from public.lts_open_finance_staging where connection_id=c)<>1 or
     (select count(*) from public.lts_open_finance_observation where sync_run_id=r)<>1 then raise exception 'TEST_FAIL_BATCH_IDEMPOTENCY'; end if;
  denied:=false;
  begin perform public.lts_open_finance_stage_batch_v1(gen_random_uuid(),c,r,jsonb_build_array(x)); exception when others then denied:=sqlerrm='INVALID_RUNNING_SYNC'; end;
  if not denied then raise exception 'TEST_FAIL_WRONG_OWNER'; end if;
  denied:=false;
  begin perform public.lts_open_finance_stage_batch_v1(uid,c,r,jsonb_build_array(x||jsonb_build_object('raw_hash',repeat('b',64)))); exception when others then denied:=sqlerrm='RETRY_PAYLOAD_CHANGED'; end;
  if not denied then raise exception 'TEST_FAIL_CHANGED_RETRY'; end if;
  denied:=false;
  begin perform public.lts_open_finance_finish_itau_v1(uid,r,'success','{"expected_count":2}'::jsonb); exception when others then denied:=sqlerrm='INCOMPLETE_SUCCESS_NOT_ALLOWED'; end;
  if not denied then raise exception 'TEST_FAIL_INCOMPLETE_SUCCESS'; end if;
  result:=public.lts_open_finance_finish_itau_v1(uid,r,'success','{"expected_count":1,"coverage":[]}'::jsonb);
  if (result->'counts'->>'inserted')::int<>1 then raise exception 'TEST_FAIL_INSERT_COUNT'; end if;
  r2:=gen_random_uuid();
  perform public.lts_open_finance_begin_itau_v1(uid,item,jsonb_build_object('id',item,'status','UPDATED','executionStatus','SUCCESS'),r2);
  perform public.lts_open_finance_stage_batch_v1(uid,c,r2,jsonb_build_array(x));
  result:=public.lts_open_finance_finish_itau_v1(uid,r2,'success','{"expected_count":1,"coverage":[]}'::jsonb);
  if (result->'counts'->>'unchanged')::int<>1 or (select count(*) from public.lts_open_finance_staging where connection_id=c)<>1 then raise exception 'TEST_FAIL_SYNC_IDEMPOTENCY'; end if;
  r3:=gen_random_uuid();
  perform public.lts_open_finance_begin_itau_v1(uid,item,jsonb_build_object('id',item,'status','UPDATED','executionStatus','SUCCESS'),r3);
  perform public.lts_open_finance_stage_batch_v1(uid,c,r3,jsonb_build_array(x||jsonb_build_object('raw_hash',repeat('c',64),'signed_amount',80,'raw_payload','{"id":"synthetic","balance":80}'::jsonb,'normalized_payload',jsonb_build_object('item_id',item,'net_valuation',80))));
  perform public.lts_open_finance_finish_itau_v1(uid,r3,'success','{"expected_count":1,"coverage":[]}'::jsonb);
  if (select count(*) from public.lts_open_finance_observation where connection_id=c)<>3
    or (select raw_payload->>'balance' from public.lts_open_finance_observation where sync_run_id=r)<>'90'
    or (select signed_amount from public.lts_open_finance_staging where connection_id=c)<>80 then raise exception 'TEST_FAIL_CORRECTION_HISTORY'; end if;
  if exists(select 1 from public.lts_open_finance_staging where connection_id=c and (promotion_status<>'blocked' or promotion_source_ref is not null)) then raise exception 'TEST_FAIL_PROMOTION'; end if;
  result:=public.lts_open_finance_report_itau_v1(uid,r3);
  if jsonb_array_length(result->'records')<>1 or result::text like '%raw_payload%' then raise exception 'TEST_FAIL_REPORT'; end if;
  insert into public.lts_open_finance_job(user_id,action,token_hash,expires_at)
    values(uid,'status',encode(extensions.digest(repeat('a',64),'sha256'),'hex'),now()+interval '1 minute');
  if public.lts_open_finance_consume_job_v1(repeat('a',64))->>'user_id' is distinct from uid::text then raise exception 'TEST_FAIL_JOB_AUTH'; end if;
  if public.lts_open_finance_consume_job_v1(repeat('a',64)) is not null then raise exception 'TEST_FAIL_JOB_REPLAY'; end if;
end $$;
select jsonb_build_object('status','PASS','assertion_groups',15,'financial_promotion',false,'synthetic_data','rolled back') as evidence;
rollback;
