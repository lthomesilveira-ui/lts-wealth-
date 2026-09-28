-- Additive shadow integration only. No canonical financial table is mutated.
-- Apply via Supabase migration tooling. All RPCs use invoker privileges and are service-only.
create table if not exists public.lts_open_finance_observation (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.usuario(id),
  connection_id uuid not null references public.lts_open_finance_connection(id),
  sync_run_id uuid not null references public.lts_open_finance_sync_run(id),
  resource_type text not null,
  provider_record_id text not null,
  raw_hash text not null,
  raw_payload jsonb not null,
  normalized_payload jsonb not null,
  reconciliation jsonb not null,
  ingest_action text not null check (ingest_action in ('inserted','updated','unchanged','stale')),
  observed_at timestamptz not null default now(),
  unique(sync_run_id,resource_type,provider_record_id)
);
alter table public.lts_open_finance_observation enable row level security;
revoke all on public.lts_open_finance_observation from public, anon, authenticated;
grant select,insert on public.lts_open_finance_observation to service_role;
create index if not exists lts_open_finance_observation_owner_run_idx
  on public.lts_open_finance_observation(user_id,sync_run_id);

create or replace function public.lts_open_finance_pilot_owner_v1()
returns uuid language plpgsql stable security invoker set search_path = '' as $$
declare ids uuid[];
begin
  select array_agg(u.id) into ids from public.usuario u
  join public.lts_allowed_users a on lower(a.email)=lower(u.email)
  where a.active and a.role='owner';
  if coalesce(cardinality(ids),0)<>1 then raise exception 'PILOT_OWNER_AMBIGUOUS'; end if;
  return ids[1];
end $$;

create or replace function public.lts_open_finance_begin_itau_v1(p_user_id uuid,p_item_id text,p_item jsonb,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare c public.lts_open_finance_connection; r public.lts_open_finance_sync_run;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
  if p_item_id !~ '^[0-9a-fA-F-]{36}$' or p_item->>'id' is distinct from p_item_id
    or p_item->>'status' is distinct from 'UPDATED' or p_item->>'executionStatus' is distinct from 'SUCCESS' then raise exception 'INVALID_ITEM_BINDING'; end if;
  perform pg_advisory_xact_lock(hashtextextended('lts-open-finance-itau:'||p_user_id::text,0));
  if exists(select 1 from public.lts_open_finance_connection where user_id=p_user_id and provider='pluggy'
    and institution_code='341' and provider_connection_ref<>p_item_id and status not in ('disabled','revoked')) then
    raise exception 'PILOT_ALREADY_BOUND_TO_DIFFERENT_ITEM';
  end if;
  insert into public.lts_open_finance_connection(user_id,provider,provider_connection_ref,institution_code,institution_name,connection_mode,scopes,status,consent_expires_at,metadata)
  values(p_user_id,'pluggy',p_item_id,'341','Itaú','meupluggy_proxy',coalesce(p_item->'products','[]'::jsonb),'connected',
    nullif(p_item->>'consentExpiresAt','')::timestamptz,jsonb_build_object('pilot','itau_shadow_v1','item',p_item,'promotion_enabled',false))
  on conflict(user_id,provider,provider_connection_ref) do update set
    scopes=excluded.scopes,status='connected',consent_expires_at=excluded.consent_expires_at,
    metadata=lts_open_finance_connection.metadata||excluded.metadata,updated_at=now()
  returning * into c;
  -- Recover abandoned executions; no provider records or financial facts are removed.
  update public.lts_open_finance_sync_run set status='failed',finished_at=now(),error_code='STALE_RUN_RECOVERED',
    error_summary='Execution exceeded the lease; safe to retry.' where connection_id=c.id and status='running' and started_at<now()-interval '10 minutes';
  select * into r from public.lts_open_finance_sync_run where id=p_request_id;
  if found then
    if r.user_id<>p_user_id or r.connection_id<>c.id then raise exception 'RUN_OWNER_MISMATCH'; end if;
    return jsonb_build_object('connection_id',c.id,'run_id',r.id,'existing',true,'status',r.status);
  end if;
  if exists(select 1 from public.lts_open_finance_sync_run where connection_id=c.id and status='running') then raise exception 'SYNC_ALREADY_RUNNING'; end if;
  insert into public.lts_open_finance_sync_run(id,user_id,connection_id,trigger_type,status,metadata)
  values(p_request_id,p_user_id,c.id,'manual','running',jsonb_build_object('version','pluggy-itau-shadow-v1','item_updated_at',p_item->>'lastUpdatedAt','promotion_enabled',false));
  update public.lts_open_finance_connection set last_attempt_at=now() where id=c.id;
  return jsonb_build_object('connection_id',c.id,'run_id',p_request_id,'existing',false,'status','running');
end $$;

create or replace function public.lts_open_finance_stage_batch_v1(p_user_id uuid,p_connection_id uuid,p_run_id uuid,p_records jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare r public.lts_open_finance_sync_run; c public.lts_open_finance_connection;
  x jsonb; old public.lts_open_finance_staging; classification text; action text; stage_status text; n integer:=0;
begin
  select * into r from public.lts_open_finance_sync_run where id=p_run_id for update;
  if r.id is null or r.user_id<>p_user_id or r.connection_id<>p_connection_id or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  select * into c from public.lts_open_finance_connection where id=p_connection_id and user_id=p_user_id and provider='pluggy' and institution_code='341';
  if c.id is null then raise exception 'INVALID_CONNECTION'; end if;
  if jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)>100 then raise exception 'INVALID_BATCH'; end if;
  for x in select value from jsonb_array_elements(p_records) loop
    if x->>'provider_record_id' not like c.provider_connection_ref||':%' or x->>'raw_hash' !~ '^[0-9a-f]{64}$'
      or x->'normalized_payload'->>'item_id' is distinct from c.provider_connection_ref then raise exception 'INVALID_RECORD_SCOPE'; end if;
    if exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id') then
      if not exists(select 1 from public.lts_open_finance_observation where sync_run_id=p_run_id and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' and raw_hash=x->>'raw_hash') then raise exception 'RETRY_PAYLOAD_CHANGED'; end if;
      continue;
    end if;
    classification:=x->'reconciliation'->>'classification';
    if classification is null or classification not in ('exact','candidate','new','conflict') then raise exception 'INVALID_RECONCILIATION'; end if;
    stage_status:=case classification when 'exact' then 'matched_exact' when 'candidate' then 'matched_candidate' when 'conflict' then 'blocked' else 'normalized' end;
    select * into old from public.lts_open_finance_staging where user_id=p_user_id and provider='pluggy' and resource_type=x->>'resource_type' and provider_record_id=x->>'provider_record_id' for update;
    action:=case when old.id is null then 'inserted' when old.raw_hash=x->>'raw_hash' then 'unchanged'
      when old.provider_updated_at is not null and nullif(x->>'provider_updated_at','')::timestamptz<old.provider_updated_at then 'stale' else 'updated' end;
    if old.id is not null and old.connection_id<>p_connection_id then raise exception 'RECORD_CONNECTION_MISMATCH'; end if;
    insert into public.lts_open_finance_observation(user_id,connection_id,sync_run_id,resource_type,provider_record_id,raw_hash,raw_payload,normalized_payload,reconciliation,ingest_action)
    values(p_user_id,p_connection_id,p_run_id,x->>'resource_type',x->>'provider_record_id',x->>'raw_hash',x->'raw_payload',x->'normalized_payload',x->'reconciliation',action);
    if action<>'stale' then
      insert into public.lts_open_finance_staging(user_id,connection_id,sync_run_id,provider,resource_type,provider_record_id,provider_account_ref,
        institution_code,institution_name,occurred_at,posting_date,reference_month,signed_amount,currency,description_raw,description_normalized,
        normalized_payload,raw_payload,raw_hash,match_status,promotion_status,block_reason,source_event_type,provider_updated_at,matched_source_table,matched_source_ref)
      values(p_user_id,p_connection_id,p_run_id,'pluggy',x->>'resource_type',x->>'provider_record_id',x->>'provider_account_ref',
        '341','Itaú',nullif(x->>'occurred_at','')::timestamptz,nullif(x->>'posting_date','')::date,nullif(x->>'reference_month','')::date,
        nullif(x->>'signed_amount','')::numeric,x->>'currency',x->>'description_raw',lower(x->>'description_raw'),
        (x->'normalized_payload')||jsonb_build_object('reconciliation',x->'reconciliation'),x->'raw_payload',x->>'raw_hash',stage_status,'blocked',
        'shadow_only_no_promotion','snapshot',nullif(x->>'provider_updated_at','')::timestamptz,
        case when classification='exact' then x->'reconciliation'->'candidates'->0->>'table' end,
        case when classification='exact' then x->'reconciliation'->'candidates'->0->>'ref' end)
      on conflict(user_id,provider,resource_type,provider_record_id) do update set
        sync_run_id=excluded.sync_run_id,provider_account_ref=excluded.provider_account_ref,occurred_at=excluded.occurred_at,
        posting_date=excluded.posting_date,reference_month=excluded.reference_month,signed_amount=excluded.signed_amount,currency=excluded.currency,
        description_raw=excluded.description_raw,description_normalized=excluded.description_normalized,normalized_payload=excluded.normalized_payload,
        raw_payload=excluded.raw_payload,raw_hash=excluded.raw_hash,match_status=excluded.match_status,promotion_status='blocked',block_reason=excluded.block_reason,
        matched_source_table=excluded.matched_source_table,matched_source_ref=excluded.matched_source_ref,match_confidence=null,
        provider_updated_at=excluded.provider_updated_at,last_seen_at=now(),updated_at=now();
    end if;
    n:=n+1;
  end loop;
  return jsonb_build_object('observations_inserted',n,'promotion_enabled',false);
end $$;

create or replace function public.lts_open_finance_sources_v1(p_user_id uuid,p_from date,p_to date)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare result jsonb; source_as_of date;
begin
  if p_user_id is distinct from public.lts_open_finance_pilot_owner_v1() then raise exception 'PILOT_OWNER_MISMATCH'; end if;
  if p_from is null or p_to is null or p_to<p_from or p_to-p_from>31 then raise exception 'SOURCE_WINDOW_MAX_32_DAYS'; end if;
  source_as_of:=nullif(public.lts_current_evidence_position_v1(p_user_id)->>'as_of','')::date;
  with sources as (
    select jsonb_build_object('kind',k,'table','accounts','ref',a.id,'identity',a.legacy_id,'institution',a.institution,'name',a.account_name,
      'account_type',a.account_type,'currency',a.currency,'amount',nullif(a.metadata->>'balance','')::numeric,'date',a.metadata->>'balance_as_of',
      'provider_id',a.metadata->>'pluggy_account_id','scope','documented_account_position') j
    from public.accounts a cross join unnest(array['account','balance']) k where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','transaction','table','lts_historical_effective_cash_v5','ref',h.source||':'||h.source_ref,
      'institution',h.account,'date',h.event_date,'amount',h.signed_amount,'description',h.description,'currency','BRL','scope',h.confidence)
    from public.lts_historical_effective_cash_v5(p_user_id,p_from,least(p_to,coalesce(source_as_of,p_to))) h
    union all
    select jsonb_build_object('kind','transaction','table','lts_corrected_cashflow_operational_v1','ref',h.source||':'||h.source_ref,
      'institution',h.account,'date',h.event_date,'amount',h.signed_amount,'description',h.description,'currency','BRL','scope','operational_not_statement_certified')
    from public.lts_corrected_cashflow_operational_v1(p_user_id,greatest(p_from,coalesce(source_as_of,p_from-1)+1),p_to) h
    where p_to>coalesce(source_as_of,p_to)
    union all
    select jsonb_build_object('kind','credit_card','table','lts_card_instruments','ref',a.id,'institution',a.issuer,'name',a.product_name,
      'last4',a.last4,'currency','BRL','amount',null,'date',null,'scope','instrument_identity_only')
    from public.lts_card_instruments a where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','invoice','table','card_invoices','ref',a.id,'institution','Itaú','name',a.card_name,
      'last4',coalesce(a.metadata->>'last4',a.metadata->>'card_final'),'currency','BRL','date',a.due_date,'amount',a.amount,'scope',a.source)
    from public.card_invoices a where a.user_id=p_user_id and (a.card_name ilike '%ita%' or a.metadata->>'bank' in ('Itaú','Itau')) and a.due_date between p_from and p_to
    union all
    select jsonb_build_object('kind','card_transaction','table','lts_card_purchase_detail','ref',a.source_id||':'||a.row_id::text,
      'institution',a.bank,'name',a.card_name,'last4',a.card_final,'currency','BRL','date',a.purchase_date,
      'amount',-a.installment_amount,'description',a.description_raw,'scope',a.source)
    from public.lts_card_purchase_detail a where a.user_id=p_user_id and a.purchase_date between p_from and p_to
    union all
    select jsonb_build_object('kind','investment','table','asset_positions','ref',a.id,'institution',coalesce(a.metadata->>'institution',case when a.asset_name ilike '%ita%' then 'Itaú' end),
      'name',a.asset_name,'currency','BRL','date',a.as_of_date,'amount',a.value_brl,'code',a.metadata->>'investment_code',
      'provider_id',a.metadata->>'pluggy_investment_id','scope',a.asset_type)
    from public.asset_positions a where a.user_id=p_user_id
    union all
    select jsonb_build_object('kind','loan','table','lts_debt_position','ref',a.id,'institution',a.institution,'contract_ref',a.contract_ref,
      'currency','BRL','date',a.as_of_date,'amount',a.debt_balance,'scope',a.status)
    from public.lts_debt_position a where a.user_id=p_user_id
  ) select coalesce(jsonb_agg(j),'[]'::jsonb) into result from sources;
  return jsonb_build_object('rows',result,'from',p_from,'to',p_to,'source_as_of',source_as_of,'complete_for_consulted_sources',true,
    'limitations',jsonb_build_array('Matches are relative to existing LTS readers, not universal historical certification.',
    'Account labels do not establish immutable identity.','Position dates and value bases must agree before exact comparison.'));
end $$;

create or replace function public.lts_open_finance_finish_itau_v1(p_user_id uuid,p_run_id uuid,p_status text,p_metadata jsonb,p_error_code text default null)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare r public.lts_open_finance_sync_run; stats jsonb;
begin
  select * into r from public.lts_open_finance_sync_run where id=p_run_id and user_id=p_user_id for update;
  if r.id is null or r.status<>'running' then raise exception 'INVALID_RUNNING_SYNC'; end if;
  if p_status is null or p_status not in ('success','partial','failed') then raise exception 'INVALID_SYNC_STATUS'; end if;
  if p_error_code is not null and p_error_code !~ '^[A-Z0-9_]{1,80}$' then raise exception 'INVALID_ERROR_CODE'; end if;
  select jsonb_build_object('total',count(*),'exact',count(*) filter(where reconciliation->>'classification'='exact'),
    'candidate',count(*) filter(where reconciliation->>'classification'='candidate'),'new',count(*) filter(where reconciliation->>'classification'='new'),
    'conflict',count(*) filter(where reconciliation->>'classification'='conflict'),
    'inserted',count(*) filter(where ingest_action='inserted'),'updated',count(*) filter(where ingest_action='updated'),
    'unchanged',count(*) filter(where ingest_action='unchanged'),'stale',count(*) filter(where ingest_action='stale')) into stats
  from public.lts_open_finance_observation where sync_run_id=p_run_id and user_id=p_user_id;
  if p_status='success' and ((stats->>'total')::int=0 or coalesce((p_metadata->>'expected_count')::int,-1)<>(stats->>'total')::int
    or exists(select 1 from jsonb_array_elements(coalesce(p_metadata->'coverage','[]')) x where x->>'status'='unavailable')) then raise exception 'INCOMPLETE_SUCCESS_NOT_ALLOWED'; end if;
  update public.lts_open_finance_sync_run set status=p_status,finished_at=now(),raw_count=(stats->>'total')::int,normalized_count=(stats->>'total')::int,
    exact_match_count=(stats->>'exact')::int,candidate_match_count=(stats->>'candidate')::int,blocked_count=(stats->>'conflict')::int,promoted_count=0,
    error_code=p_error_code,error_summary=case when p_error_code is not null then 'Shadow sync incomplete; see safe error code.' end,
    metadata=metadata||p_metadata||jsonb_build_object('counts',stats,'promotion_enabled',false) where id=p_run_id;
  update public.lts_open_finance_connection set last_success_at=case when p_status='success' then now() else last_success_at end,
    last_error_code=p_error_code,last_error_summary=case when p_error_code is not null then 'Shadow sync incomplete.' end,updated_at=now() where id=r.connection_id;
  return jsonb_build_object('run_id',p_run_id,'status',p_status,'counts',stats,'promotion_enabled',false);
end $$;

create or replace function public.lts_open_finance_report_itau_v1(p_user_id uuid,p_run_id uuid default null,p_offset integer default 0)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
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
end $$;

revoke all on function public.lts_open_finance_pilot_owner_v1() from public,anon,authenticated;
revoke all on function public.lts_open_finance_begin_itau_v1(uuid,text,jsonb,uuid) from public,anon,authenticated;
revoke all on function public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.lts_open_finance_sources_v1(uuid,date,date) from public,anon,authenticated;
revoke all on function public.lts_open_finance_finish_itau_v1(uuid,uuid,text,jsonb,text) from public,anon,authenticated;
revoke all on function public.lts_open_finance_report_itau_v1(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.lts_open_finance_pilot_owner_v1(),public.lts_open_finance_begin_itau_v1(uuid,text,jsonb,uuid),
  public.lts_open_finance_stage_batch_v1(uuid,uuid,uuid,jsonb),public.lts_open_finance_sources_v1(uuid,date,date),
  public.lts_open_finance_finish_itau_v1(uuid,uuid,text,jsonb,text),public.lts_open_finance_report_itau_v1(uuid,uuid,integer) to service_role;

-- An administrator can request a one-shot run through the already installed pg_net.
-- The random token is never returned, and only its hash is retained in the job table.
-- The function gateway still requires a valid platform JWT; the public anon JWT alone
-- does not authorize a job. A short-lived, single-use token is also mandatory.
create table if not exists public.lts_open_finance_job (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.usuario(id),
  action text not null check(action in ('status','discover','sync')), token_hash text not null unique,
  created_at timestamptz not null default now(), expires_at timestamptz not null,
  consumed_at timestamptz, http_request_id bigint
);
alter table public.lts_open_finance_job enable row level security;
revoke all on public.lts_open_finance_job from public,anon,authenticated;
grant select,insert,update on public.lts_open_finance_job to service_role;

create or replace function public.lts_open_finance_enqueue_itau_v1(p_endpoint text,p_anon_jwt text,p_action text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare uid uuid; nonce text; jid uuid; req bigint;
begin
  if p_endpoint !~ '^https://[a-z]{20}\.supabase\.co/functions/v1/lts-open-finance-itau$' then raise exception 'INVALID_ENDPOINT'; end if;
  if p_action is null or p_action not in ('status','discover','sync') then raise exception 'INVALID_ACTION'; end if;
  if p_anon_jwt is null or length(p_anon_jwt)<100 then raise exception 'PLATFORM_JWT_REQUIRED'; end if;
  uid:=public.lts_open_finance_pilot_owner_v1();
  nonce:=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.lts_open_finance_job(user_id,action,token_hash,expires_at)
    values(uid,p_action,encode(extensions.digest(nonce,'sha256'),'hex'),now()+interval '2 minutes') returning id into jid;
  select net.http_post(url:=p_endpoint,body:=jsonb_build_object('action',p_action),
    headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||p_anon_jwt,'apikey',p_anon_jwt,'x-lts-of-job',nonce),
    timeout_milliseconds:=180000) into req;
  update public.lts_open_finance_job set http_request_id=req where id=jid;
  return jsonb_build_object('job_id',jid,'http_request_id',req,'action',p_action,'token_returned',false);
end $$;

create or replace function public.lts_open_finance_consume_job_v1(p_token text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare j public.lts_open_finance_job;
begin
  if p_token !~ '^[0-9a-f]{64}$' then return null; end if;
  update public.lts_open_finance_job set consumed_at=now() where token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
    and consumed_at is null and expires_at>now() returning * into j;
  if j.id is null then return null; end if;
  return jsonb_build_object('user_id',j.user_id,'action',j.action,'job_id',j.id);
end $$;
revoke all on function public.lts_open_finance_enqueue_itau_v1(text,text,text),public.lts_open_finance_consume_job_v1(text) from public,anon,authenticated;
grant execute on function public.lts_open_finance_enqueue_itau_v1(text,text,text),public.lts_open_finance_consume_job_v1(text) to service_role;
