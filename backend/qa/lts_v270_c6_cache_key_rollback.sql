BEGIN;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='5s';
CREATE TEMP TABLE lts_flow_future_read_cache_v2(user_id uuid,as_of date,from_date date,to_date date,engine_version text,payload jsonb,refreshed_at timestamptz);
CREATE TEMP TABLE fixture_invoices(card_name text,reference_month date,due_date date,status text,amount numeric,source text);
CREATE TEMP TABLE fixture_calls(n int); INSERT INTO fixture_calls VALUES(0);
CREATE FUNCTION pg_temp.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql AS $$SELECT CASE WHEN $1='C6 fixture' THEN 'c6' ELSE 'other' END$$;
CREATE FUNCTION pg_temp.lts_card_invoice_amounts_v230(uuid) RETURNS SETOF pg_temp.fixture_invoices LANGUAGE sql AS $$SELECT * FROM pg_temp.fixture_invoices$$;
INSERT INTO fixture_invoices VALUES
('C6 fixture',date_trunc('month',current_date+5)::date,current_date+5,'projected',130,'bank_document_composition'),
('C6 fixture',date_trunc('month',current_date+35)::date,current_date+35,'projected',70,'derived_current_installments'),
('Itau fixture',date_trunc('month',current_date+5)::date,current_date+5,'open',50,'bank'),
('Bradesco fixture',date_trunc('month',current_date+5)::date,current_date+5,'projected',40,'bank_document_composition');
CREATE TEMP TABLE lts_reconciliation_evidence(id int,user_id uuid,evidence_type text);
CREATE TEMP TABLE evento_usuario(id int,usuario_id uuid);
CREATE TEMP TABLE deslocamento(id int,usuario_id uuid);
CREATE TEMP TABLE lts_projection_replacement_rule(id int,user_id uuid);
CREATE FUNCTION pg_temp.lts_dashboard_source_key_v240(uuid) RETURNS text LANGUAGE sql AS $$SELECT 'canonical-fixture-stable'::text$$;
CREATE OR REPLACE FUNCTION pg_temp.fixture_old_key(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'reader_revision','correlated-cash-and-calendar-coverage-v247',
 'canonical',pg_temp.lts_dashboard_source_key_v240(p_user_id),
 'other_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type NOT LIKE 'historical_workbook_cash%'),
 'user_events',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.evento_usuario e WHERE e.usuario_id=p_user_id),
 'displacements',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.deslocamento e WHERE e.usuario_id=p_user_id),
 'replacement_rules',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.lts_projection_replacement_rule e WHERE e.user_id=p_user_id)
)::text)
$function$
;
CREATE OR REPLACE FUNCTION pg_temp.lts_flow_read_key_engine_v243(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'reader_revision','correlated-cash-and-calendar-coverage-v269-c6',
 'c6_invoice_composition',(SELECT md5(coalesce(jsonb_agg(to_jsonb(i) ORDER BY to_jsonb(i)::text)::text,'[]'))
  FROM pg_temp.lts_card_invoice_amounts_v230(p_user_id) i WHERE pg_temp.lts_card_family_v226(i.card_name,i.card_name)='c6'),
 'canonical',pg_temp.lts_dashboard_source_key_v240(p_user_id),
 'other_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type NOT LIKE 'historical_workbook_cash%'),
 'user_events',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.evento_usuario e WHERE e.usuario_id=p_user_id),
 'displacements',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.deslocamento e WHERE e.usuario_id=p_user_id),
 'replacement_rules',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM pg_temp.lts_projection_replacement_rule e WHERE e.user_id=p_user_id)
)::text)
$function$
;
CREATE FUNCTION pg_temp.lts_flow_read_source_key_v247(uuid) RETURNS text LANGUAGE sql AS $$SELECT pg_temp.lts_flow_read_key_engine_v243($1)$$;
CREATE FUNCTION pg_temp.lts_daily_flow_fix86_v20(uuid,date,date) RETURNS jsonb LANGUAGE sql AS $$
WITH e AS (SELECT card_name,reference_month,due_date,CASE WHEN card_name='C6 fixture' THEN 'C6' WHEN card_name='Itau fixture' THEN 'Itaú' ELSE 'Bradesco' END bank,
-amount signed_amount FROM pg_temp.fixture_invoices),
ds AS (SELECT dt::date dt,coalesce(sum(e.signed_amount) FILTER(WHERE bank='Itaú'),0) ci,coalesce(sum(e.signed_amount) FILTER(WHERE bank='Bradesco'),0) cb,coalesce(sum(e.signed_amount) FILTER(WHERE bank='C6'),0) cc,
coalesce(sum(e.signed_amount) FILTER(WHERE bank='Itaú' AND e.due_date=dt),0) ni,coalesce(sum(e.signed_amount) FILTER(WHERE bank='Bradesco' AND e.due_date=dt),0) nb,coalesce(sum(e.signed_amount) FILTER(WHERE bank='C6' AND e.due_date=dt),0) nc
FROM generate_series($2,$3,'1 day'::interval)dt LEFT JOIN e ON e.due_date<=dt GROUP BY dt)
SELECT jsonb_build_object('source_fingerprint',pg_temp.lts_flow_read_source_key_v247($1),'events',(SELECT jsonb_agg(jsonb_build_object('source','card_invoice','source_ref',card_name||'|'||to_char(reference_month,'YYYY-MM'),'account',bank,'event_date',due_date,'signed_amount',signed_amount)) FROM e),
'days',(SELECT jsonb_agg(jsonb_build_object('date',dt,'Itaú',jsonb_build_object('balance',1000+ci,'net',ni),'Bradesco',jsonb_build_object('balance',2000+cb,'net',nb),'C6',jsonb_build_object('balance',cc,'net',nc),'Consolidado',jsonb_build_object('bank_balance',3000+ci+cb+cc,'economic_net',ni+nb+nc),'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',0,'exits',-(ni+nb+nc))))||jsonb_build_object('fix86_columns',jsonb_build_object('saldo_anterior',3000+ci+cb+cc-ni-nb-nc,'saldo_final',3000+ci+cb+cc,'entradas',0,'saidas',-(ni+nb+nc),'liq_d0_1',3100+ci+cb+cc,'liq_d30',3100+ci+cb+cc,'saldo_apos_d0_1',3100+ci+cb+cc,'saldo_apos_rsu',3200+ci+cb+cc,'saldo_apos_fgts',3300+ci+cb+cc,'disponivel_total',3200+ci+cb+cc,'posicao_antes_rsus',3100+ci+cb+cc,'posicao_curto_prazo',3200+ci+cb+cc,'posicao_economica_total',3300+ci+cb+cc,'rsus_vested',100,'fgts',100)) ORDER BY dt) FROM ds));
$$;
CREATE FUNCTION pg_temp.lts_flow_future_read_cache_refresh_v9(uuid,integer) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 UPDATE pg_temp.fixture_calls SET n=n+1;
 INSERT INTO pg_temp.lts_flow_future_read_cache_v2 VALUES($1,current_date,current_date,current_date+$2,'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181',pg_temp.lts_daily_flow_fix86_v20($1,current_date,current_date+$2),clock_timestamp());
END$$;
CREATE OR REPLACE FUNCTION pg_temp.lts_flow_invoice_amount_overlay_v226(p_flow jsonb, p_invoices jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare changes jsonb; new_events jsonb; new_days jsonb;
begin
 with invoices as (
  select i->>'card_name' card_name,(i->>'reference_month')::date AS month,(i->>'due_date')::date due_date,(i->>'amount')::numeric amount
  from jsonb_array_elements(coalesce(p_invoices,'[]'::jsonb)) i
 ), updates as (
  select e->>'source_ref' ref,e->>'account' account,(e->>'event_date')::date AS day,
   (e->>'signed_amount')::numeric old_amount,-i.amount new_amount
  from jsonb_array_elements(coalesce(p_flow->'events','[]'::jsonb))e
  join invoices i on e->>'source_ref'=i.card_name||'|'||to_char(i.month,'YYYY-MM')
    and (e->>'event_date')::date=i.due_date
  where e->>'source'='card_invoice' and (e->>'event_date')::date>=current_date
   and e->>'account' in ('Itaú','Bradesco','C6') and (e->>'signed_amount')::numeric<>-i.amount
 )select jsonb_agg(to_jsonb(u)) into changes from updates u;
 if changes is null then return p_flow;end if;
 if exists(select 1 from jsonb_array_elements(changes)c group by c->>'ref' having count(*)>1)then
  raise exception 'Ambiguous invoice composition';end if;
 select jsonb_agg(e||case when c is null then '{}'::jsonb else jsonb_build_object('signed_amount',(c->>'new_amount')::numeric)end order by n)
 into new_events from jsonb_array_elements(p_flow->'events')with ordinality src(e,n)
 left join lateral(select x from jsonb_array_elements(changes)x where x->>'ref'=e->>'source_ref' and e->>'source'='card_invoice')a(c)on true;
 with deltas as materialized (
  select (c->>'day')::date AS day,c->>'account' bank,(c->>'new_amount')::numeric-(c->>'old_amount')::numeric net,
   greatest((c->>'new_amount')::numeric,0)-greatest((c->>'old_amount')::numeric,0) entries,
   greatest(-(c->>'new_amount')::numeric,0)-greatest(-(c->>'old_amount')::numeric,0) exits
  from jsonb_array_elements(changes)c
 ), adjusted as (
  select d,n,(d->>'date')::date AS day,
   coalesce(sum(net)filter(where bank='Itaú'),0) ci,coalesce(sum(net)filter(where bank='Bradesco'),0) cb,coalesce(sum(net)filter(where bank='C6'),0) cc,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='Itaú'),0) ni,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='Bradesco'),0) nb,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='C6'),0) nc,
   coalesce(sum(entries)filter(where x.day=(d->>'date')::date),0) en,
   coalesce(sum(exits)filter(where x.day=(d->>'date')::date),0) ex
  from jsonb_array_elements(p_flow->'days')with ordinality src(d,n)
  left join deltas x on x.day<=(d->>'date')::date group by d,n
 ), composed as (
  select n,d||jsonb_build_object(
   'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+ci,'net',(d#>>'{Itaú,net}')::numeric+ni),
   'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+cb,'net',(d#>>'{Bradesco,net}')::numeric+nb),
   'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+cc,'net',(d#>>'{C6,net}')::numeric+nc),
   'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',(d#>>'{Consolidado,bank_balance}')::numeric+ci+cb+cc,'economic_net',(d#>>'{Consolidado,economic_net}')::numeric+ni+nb+nc),
   'summary',(d->'summary')||jsonb_build_object('Consolidado',(d#>'{summary,Consolidado}')||jsonb_build_object('entries',(d#>>'{summary,Consolidado,entries}')::numeric+en,'exits',(d#>>'{summary,Consolidado,exits}')::numeric+ex)),
   'fix86_columns',(d->'fix86_columns')||(select jsonb_object_agg(k,to_jsonb(v::numeric+case
     when k='entradas' then en when k='saidas' then ex when k='saldo_anterior' then ci+cb+cc-ni-nb-nc else ci+cb+cc end))
    from jsonb_each_text(d->'fix86_columns')z(k,v)where k in ('entradas','saidas','saldo_anterior','saldo_final','liq_d0_1','liq_d30','saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts','disponivel_total','posicao_antes_rsus','posicao_curto_prazo','posicao_economica_total'))
  )value from adjusted
 )select jsonb_agg(value order by n)into new_days from composed;
 return p_flow||jsonb_build_object('days',new_days,'events',new_events);
end $function$
;
CREATE OR REPLACE FUNCTION pg_temp.lts_flow_future_read_slice_v9(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer; source_key text; horizon_end date;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1800 then raise exception 'future range exceeds supported horizon'; end if;
  source_key:=pg_temp.lts_flow_read_source_key_v247(p_user_id);
  select * into c from pg_temp.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    if current_setting('transaction_read_only')::boolean then
      -- Same engine, horizon and fingerprint as refresh_v9. No source writes.
      horizon_end:=current_date+least(1800,greatest(60,requested_horizon,
        coalesce((select to_date-current_date from pg_temp.lts_flow_future_read_cache_v2
          where user_id=p_user_id and as_of=current_date),0)));
      select p_user_id user_id,current_date as_of,current_date from_date,horizon_end to_date,
        'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'::text engine_version,
        pg_temp.lts_daily_flow_fix86_v20(p_user_id,current_date,horizon_end)
          ||jsonb_build_object('source_fingerprint',source_key) payload,now() refreshed_at into c;
    else
      perform pg_temp.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
      select * into c from pg_temp.lts_flow_future_read_cache_v2
       where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
         and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
       order by refreshed_at desc limit 1;
    end if;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=pg_temp.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from pg_temp.lts_card_invoice_amounts_v230(p_user_id)i where (i.status='open' OR (i.status='projected' AND i.source='derived_installments_v234')) and i.due_date>=current_date));
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',to_jsonb(
      coalesce(nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric,0)+coalesce((
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30),0)),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$
;

DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001'; original_key text; k text; j jsonb; warm jsonb; later jsonb; raw jsonb; v numeric; d jsonb; n int;
BEGIN
 original_key:=pg_temp.fixture_old_key(u);
 UPDATE pg_temp.fixture_invoices SET amount=CASE WHEN source='bank_document_composition' THEN 30 ELSE 20 END WHERE card_name='C6 fixture';
 raw:=pg_temp.lts_daily_flow_fix86_v20(u,current_date,current_date+101)||jsonb_build_object('source_fingerprint',original_key);
 INSERT INTO pg_temp.lts_flow_future_read_cache_v2 VALUES(u,current_date,current_date,current_date+101,'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181',raw,clock_timestamp());
 UPDATE pg_temp.fixture_invoices SET amount=CASE WHEN source='bank_document_composition' THEN 130 ELSE 70 END,due_date=CASE WHEN source='bank_document_composition' THEN current_date+7 ELSE current_date+38 END WHERE card_name='C6 fixture';
 IF pg_temp.fixture_old_key(u) IS DISTINCT FROM original_key THEN RAISE EXCEPTION 'Old key unexpectedly covered composition changes';END IF;
 k:=pg_temp.lts_flow_read_source_key_v247(u);IF k IS NOT DISTINCT FROM original_key THEN RAISE EXCEPTION 'New key did not reject stale cache';END IF;
 j:=pg_temp.lts_flow_future_read_slice_v9(u,current_date,current_date+70);SELECT f.n INTO n FROM pg_temp.fixture_calls f;
 IF n IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Stale cache was not regenerated exactly once';END IF;
 warm:=pg_temp.lts_flow_future_read_slice_v9(u,current_date,current_date+70);
 IF (warm-'cold_refresh_horizon_days') IS DISTINCT FROM (j-'cold_refresh_horizon_days') OR (SELECT f.n FROM pg_temp.fixture_calls f) IS DISTINCT FROM n THEN RAISE EXCEPTION 'Warm cache mismatch';END IF;
 SELECT (e->>'signed_amount')::numeric INTO v FROM jsonb_array_elements(j->'events')e WHERE e->>'account'='C6' AND (e->>'event_date')::date=current_date+7;
 IF v IS DISTINCT FROM -130::numeric THEN RAISE EXCEPTION 'New amount/date not generated';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'events')e WHERE e->>'account'='C6' AND (e->>'event_date')::date IN(current_date+5,current_date+35)) THEN RAISE EXCEPTION 'Old C6 dates retained';END IF;
 SELECT (x#>>'{fix86_columns,liq_d30}')::numeric INTO v FROM jsonb_array_elements(j->'days')x WHERE (x->>'date')::date=current_date;
 IF v IS DISTINCT FROM 2880::numeric THEN RAISE EXCEPTION 'D30 did not incorporate regenerated date/value';END IF;
 IF (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(raw->'events')e WHERE e->>'account'<>'C6') IS DISTINCT FROM (SELECT jsonb_agg(e ORDER BY e::text) FROM jsonb_array_elements(j->'events')e WHERE e->>'account'<>'C6') THEN RAISE EXCEPTION 'Other bank events changed';END IF;
 UPDATE pg_temp.fixture_invoices SET amount=140,due_date=current_date+9 WHERE card_name='C6 fixture' AND source='bank_document_composition';
 IF pg_temp.lts_flow_read_source_key_v247(u) IS NOT DISTINCT FROM k THEN RAISE EXCEPTION 'Later composition change did not alter key';END IF;
 later:=pg_temp.lts_flow_future_read_slice_v9(u,current_date,current_date+70);
 IF (SELECT f.n FROM pg_temp.fixture_calls f) IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'Changed composition did not regenerate';END IF;
 SELECT x INTO d FROM jsonb_array_elements(later->'days')x WHERE (x->>'date')::date=current_date+38;
 IF (d#>>'{C6,balance}')::numeric IS DISTINCT FROM -210::numeric OR (d#>>'{Consolidado,bank_balance}')::numeric IS DISTINCT FROM 2700::numeric THEN RAISE EXCEPTION 'Regenerated cumulative balance mismatch';END IF;
 k:=pg_temp.lts_flow_read_source_key_v247(u);
 UPDATE pg_temp.fixture_invoices SET due_date=due_date+1 WHERE card_name='C6 fixture' AND source='bank_document_composition';
 IF pg_temp.lts_flow_read_source_key_v247(u) IS NOT DISTINCT FROM k THEN RAISE EXCEPTION 'Date-only change omitted';END IF;
 k:=pg_temp.lts_flow_read_source_key_v247(u);UPDATE pg_temp.fixture_invoices SET amount=999 WHERE card_name='Bradesco fixture';
 IF pg_temp.lts_flow_read_source_key_v247(u) IS DISTINCT FROM k THEN RAISE EXCEPTION 'C6 key extension broadened to unrelated bank';END IF;
END $test$;
SELECT 'PASS: stale key reproduced; canonical C6 composition invalidates cache; cold/warm parity; changed value/date regenerate events, cumulative balances and D30; other banks preserved' result;
ROLLBACK;
