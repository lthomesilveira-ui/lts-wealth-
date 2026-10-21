-- Install atomically; no bank sources or financial events are created/rewritten by this migration.
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='55s';
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v10(uuid,date,date)'::regprocedure))<>'9bf9eb971855f054d7d979e8a1836df8'
 OR md5(pg_get_functiondef('public.lts_flow_read_source_key_v247(uuid)'::regprocedure))<>'ae4a61b7a22b05ffed15342a44a94dda'
 OR md5(pg_get_functiondef('public.lts_flow_bank_freshness_key_v246(uuid)'::regprocedure))<>'00ec76ab132890f3b726f5dd4115de21'
 THEN RAISE EXCEPTION 'V293 projection source lease changed';END IF;
END $lease$;
CREATE TEMP TABLE schedule_baseline_v293(user_id uuid PRIMARY KEY,future jsonb,expenses jsonb,history jsonb) ON COMMIT DROP;
DO $baseline$ DECLARE u uuid;BEGIN
 FOR u IN SELECT DISTINCT user_id FROM public.audit_log WHERE action='confirm_scheduled_transfer_destination'
 AND details->>'version'='owner-schedule-destination-v292' LOOP
 INSERT INTO schedule_baseline_v293 SELECT u,public.lts_daily_flow_fix86_v20(u,current_date,current_date+60),
 (SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)e),
 (SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') FROM public.lts_flow_past_operational_v2(u,current_date-60,current_date-1)e);
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM schedule_baseline_v293) THEN RAISE EXCEPTION 'No confirmed-schedule baseline';END IF;
END $baseline$;
-- V293: source-backed, owner-confirmed bank schedules remain projections.
CREATE OR REPLACE FUNCTION public.lts_bank_schedule_evidence_valid_v293(
 p_user_id uuid,p_source jsonb,p_confirmation jsonb,p_origin jsonb,p_destination jsonb,p_balance jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
SELECT coalesce(
 p_source->>'user_id'=p_user_id::text AND p_confirmation->>'user_id'=p_user_id::text
 AND p_origin->>'user_id'=p_user_id::text AND p_destination->>'user_id'=p_user_id::text
 AND p_balance->>'user_id'=p_user_id::text
 AND p_source->>'resource_type'='transaction' AND p_source->>'currency'='BRL'
 AND p_source->>'provider_deleted_at' IS NULL
 AND p_source#>>'{normalized_payload,status}'='PENDING'
 AND p_source#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND CASE WHEN jsonb_typeof(p_source->'signed_amount')='number' THEN (p_source->>'signed_amount')::numeric<0 ELSE false END
 AND p_source->>'raw_hash' ~ '^[0-9a-f]{64}$'
 AND p_confirmation->>'action'='confirm_scheduled_transfer_destination'
 AND p_confirmation->>'entity_type'='open_finance_schedule'
 AND p_confirmation->>'entity_id'=p_source->>'id'
 AND p_confirmation#>>'{details,version}'='owner-schedule-destination-v292'
 AND p_confirmation#>>'{details,basis}'='owner_confirmed_registered_destination'
 AND p_confirmation#>>'{details,scope}'='destination_confirmation_only'
 AND p_confirmation#>>'{details,source_status}'='PENDING'
 AND p_confirmation#>>'{details,source_id}'=p_source->>'id'
 AND p_confirmation#>>'{details,source_raw_hash}'=p_source->>'raw_hash'
 AND p_confirmation#>>'{details,date}'=p_source->>'posting_date'
 AND p_confirmation#>'{details,signed_amount}'=p_source->'signed_amount'
 AND p_confirmation#>>'{details,financial_effect}'='none'
 AND p_confirmation#>>'{details,does_not_mark_paid}'='true'
 AND p_confirmation#>>'{details,destination_account_id}'=p_destination->>'id'
 AND p_confirmation#>>'{details,destination_bank}'=p_destination->>'institution'
 AND p_confirmation#>>'{details,origin_bank}'=p_origin->>'institution'
 AND p_origin->>'id'<>p_destination->>'id'
 AND p_origin->>'is_active'='true' AND p_destination->>'is_active'='true'
 AND p_origin->>'account_type'='checking' AND p_destination->>'account_type'='checking'
 AND p_origin->>'currency'='BRL' AND p_destination->>'currency'='BRL'
 AND p_origin->>'institution'=CASE p_source->>'institution_code' WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND p_source#>>'{raw_payload,paymentData,receiver,routingNumber}'=CASE p_destination->>'institution' WHEN 'Itaú' THEN '341' WHEN 'Bradesco' THEN '237' WHEN 'C6' THEN '336' END
 AND p_balance->>'resource_type'='balance' AND p_balance->>'provider_deleted_at' IS NULL
 AND p_balance->>'provider_account_ref'=p_source->>'provider_account_ref'
 AND p_balance->>'institution_code'=p_source->>'institution_code'
 AND p_balance#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_source#>>'{raw_payload,paymentData,payer,documentNumber,type}'='CPF'
 AND p_source#>>'{raw_payload,paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')~'^[0-9]{11}$'
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')=regexp_replace(p_source#>>'{raw_payload,paymentData,payer,documentNumber,value}','[^0-9]','','g')
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')=regexp_replace(p_source#>>'{raw_payload,paymentData,receiver,documentNumber,value}','[^0-9]','','g')
,false)
$f$;
REVOKE ALL ON FUNCTION public.lts_bank_schedule_evidence_valid_v293(uuid,jsonb,jsonb,jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bank_schedule_evidence_valid_v293(uuid,jsonb,jsonb,jsonb,jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_confirmed_bank_transfer_schedules_v293(p_user_id uuid)
RETURNS TABLE(source_id uuid,scheduled_date date,from_bank text,to_bank text,signed_amount numeric,source_raw_hash text,confirmed_at timestamptz)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH matched AS MATERIALIZED(
 SELECT s.id source_id,s.posting_date scheduled_date,o.institution from_bank,d.institution to_bank,
 s.signed_amount,s.raw_hash source_raw_hash,a.created_at confirmed_at,d.id destination_id
 FROM public.lts_open_finance_staging s
 JOIN public.audit_log a ON a.user_id=s.user_id AND a.action='confirm_scheduled_transfer_destination'
 AND a.entity_type='open_finance_schedule' AND a.entity_id=s.id::text
 JOIN public.accounts o ON o.user_id=s.user_id AND o.is_active AND o.account_type='checking' AND o.currency='BRL'
 AND o.institution=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 JOIN public.accounts d ON d.user_id=s.user_id AND d.id::text=a.details->>'destination_account_id'
 AND d.is_active AND d.account_type='checking' AND d.currency='BRL'
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='PENDING'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND s.signed_amount<0
 AND (SELECT count(*) FROM public.accounts x WHERE x.user_id=p_user_id AND x.is_active
 AND x.account_type='checking' AND x.currency='BRL' AND x.institution=o.institution)=1
 AND (SELECT count(*) FROM public.accounts x WHERE x.user_id=p_user_id AND x.is_active
 AND x.account_type='checking' AND x.currency='BRL' AND x.institution=d.institution)=1
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id
 AND b.resource_type='balance' AND b.provider_account_ref=s.provider_account_ref AND b.provider_deleted_at IS NULL
 AND public.lts_bank_schedule_evidence_valid_v293(p_user_id,to_jsonb(s),to_jsonb(a),to_jsonb(o),to_jsonb(d),to_jsonb(b)))
)
SELECT source_id,scheduled_date,min(from_bank),min(to_bank),signed_amount,source_raw_hash,min(confirmed_at)
FROM matched GROUP BY source_id,scheduled_date,signed_amount,source_raw_hash HAVING count(DISTINCT destination_id)=1
$f$;
REVOKE ALL ON FUNCTION public.lts_confirmed_bank_transfer_schedules_v293(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_confirmed_bank_transfer_schedules_v293(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_projected_transfer_legs_v293(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(event_date date,account text,description text,signed_amount numeric,source_ref text,confidence text)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH existing AS MATERIALIZED(SELECT * FROM public.lts_internal_transfer_legs_fix86_v1(p_user_id,p_from,p_to)),
scheduled AS MATERIALIZED(
 SELECT s.*,count(*) OVER(PARTITION BY scheduled_date,from_bank,to_bank,signed_amount) same_identity
 FROM public.lts_confirmed_bank_transfer_schedules_v293(p_user_id)s
 WHERE s.scheduled_date>=current_date AND s.scheduled_date BETWEEN p_from AND p_to
), eligible AS(
 SELECT * FROM scheduled s WHERE same_identity=1 AND NOT EXISTS(SELECT 1 FROM existing e
 WHERE e.event_date=s.scheduled_date AND ((e.account=s.from_bank AND e.signed_amount=s.signed_amount)
 OR(e.account=s.to_bank AND e.signed_amount=-s.signed_amount)))
)
SELECT * FROM existing
UNION ALL
SELECT s.scheduled_date,x.account,'Transferência entre contas · '||s.from_bank||' → '||s.to_bank,
x.amount,'bank_schedule:'||s.source_id::text||':'||x.leg,'bank_scheduled_owner_confirmed_v293'
FROM eligible s CROSS JOIN LATERAL(VALUES(s.from_bank,s.signed_amount,'out'),(s.to_bank,-s.signed_amount,'in'))x(account,amount,leg)
$f$;
REVOKE ALL ON FUNCTION public.lts_flow_projected_transfer_legs_v293(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_projected_transfer_legs_v293(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_scheduled_transfer_revision_v293(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY source_id)::text,'[]'))
FROM public.lts_confirmed_bank_transfer_schedules_v293(p_user_id)s
$f$;
REVOKE ALL ON FUNCTION public.lts_scheduled_transfer_revision_v293(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_scheduled_transfer_revision_v293(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_future_bank_identity_v293(p_user_id uuid,p_staging_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH s AS MATERIALIZED(SELECT * FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND id=p_staging_id),
confirmed AS MATERIALIZED(SELECT * FROM public.lts_confirmed_bank_transfer_schedules_v293(p_user_id) WHERE source_id=p_staging_id),
legs AS MATERIALIZED(SELECT * FROM public.lts_flow_projected_transfer_legs_v293(p_user_id,
 (SELECT posting_date FROM s),(SELECT posting_date FROM s))
 WHERE source_ref IN('bank_schedule:'||p_staging_id::text||':out','bank_schedule:'||p_staging_id::text||':in'))
SELECT coalesce(public.lts_future_bank_identity_v290(p_user_id,p_staging_id),'{}')||coalesce((
 SELECT jsonb_build_object('kind','own_transfer','own_identity_proven',true,
 'destination_confirmed',true,'destination_bank',c.to_bank,'origin_bank',c.from_bank,
 'destination_confirmed_at',c.confirmed_at,'represented_in_flow',(SELECT count(*)=2 AND sum(signed_amount)=0 FROM legs),
 'projection_ref','bank_schedule:'||c.source_id::text,
 'projection_description','Transferência entre contas · '||c.from_bank||' → '||c.to_bank,
 'basis','bank_schedule_and_owner_confirmed_registered_destination',
 'realization_confirmed',false) FROM confirmed c),'{}')
$f$;
REVOKE ALL ON FUNCTION public.lts_future_bank_identity_v293(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_future_bank_identity_v293(uuid,uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.lts_browser_future_bank_v293(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>730 THEN RAISE EXCEPTION 'Período inválido.'; END IF;
 RETURN jsonb_build_object('version','future-bank-v293','from',p_from,'to',p_to,'consulted_at',clock_timestamp(),
 'rows',(SELECT coalesce(jsonb_agg(jsonb_build_object('source_id',s.id,'date',s.posting_date,
 'bank',CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END,
 'description',s.description_raw,'amount',s.signed_amount,'status',CASE WHEN s.posting_date<current_date THEN 'overdue_unconfirmed' ELSE 'scheduled' END,
 'received_at',s.last_seen_at,'source_updated_at',s.normalized_payload->>'provider_updated_at',
 'included_in_realized',false,'included_in_flow_totals',(public.lts_future_bank_identity_v293(u,s.id)->>'represented_in_flow')::boolean,
 'identity',public.lts_future_bank_identity_v293(u,s.id),'link_status',CASE WHEN public.lts_future_bank_identity_v293(u,s.id)->>'represented_in_flow'='true' THEN 'already_represented'
 WHEN public.lts_future_bank_identity_v293(u,s.id)->>'own_identity_proven'='true' THEN 'own_transfer_destination_review' ELSE 'review_required' END)
 ORDER BY s.posting_date,s.id),'[]') FROM public.lts_open_finance_staging s
 WHERE s.user_id=u AND s.provider_deleted_at IS NULL AND s.currency='BRL'
 AND s.resource_type='transaction' AND s.institution_code IN('341','237','336')
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND s.normalized_payload->>'status'='PENDING'
 AND s.posting_date BETWEEN p_from AND p_to),
 'card_future_received',(SELECT count(*) FROM public.lts_open_finance_staging s WHERE s.user_id=u
 AND s.provider_deleted_at IS NULL AND s.resource_type='card_transaction' AND s.currency='BRL'
 AND s.normalized_payload->>'status'='PENDING' AND s.posting_date>current_date AND s.posting_date BETWEEN p_from AND p_to),
 'cash_effect','none_until_obligation_linked','source_limitation','An absent schedule means it was not received; bank availability is not inferred');
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_future_bank_v293(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_future_bank_v293(date,date) TO authenticated,service_role;
DO $patch$
DECLARE d text; old text; bank_body text; r record; prior_oid oid; prior_owner oid; prior_acl aclitem[]; prior_config text[]; prior_security boolean; prior_volatility "char";
BEGIN
 FOR r IN SELECT sig FROM(VALUES('public.lts_daily_flow_fix86_v10(uuid,date,date)'),('public.lts_flow_read_source_key_v247(uuid)'),('public.lts_flow_bank_freshness_key_v246(uuid)'))v(sig) LOOP
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile
 INTO prior_oid,d,prior_owner,prior_acl,prior_config,prior_security,prior_volatility FROM pg_proc WHERE oid=r.sig::regprocedure;
 IF r.sig='public.lts_daily_flow_fix86_v10(uuid,date,date)' THEN
  IF (length(d)-length(replace(d,'public.lts_internal_transfer_legs_fix86_v1(','')))/length('public.lts_internal_transfer_legs_fix86_v1(')<>2
  THEN RAISE EXCEPTION 'Future engine transfer anchors changed';END IF;
  d:=replace(d,'public.lts_internal_transfer_legs_fix86_v1(','public.lts_flow_projected_transfer_legs_v293(');
  old:=$a$'internal_transfer',internal_transfer) order by event_date,source,description)$a$;
  IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Future event metadata anchor changed';END IF;
  d:=replace(d,old,$b$'internal_transfer',internal_transfer)||CASE WHEN confidence='bank_scheduled_owner_confirmed_v293'
   THEN jsonb_build_object('is_projection',true,'status','scheduled','realization_confirmed',false,
    'bank_schedule_source_id',split_part(source_ref,':',2)) ELSE '{}'::jsonb END order by event_date,source,description)$b$);
 ELSIF r.sig='public.lts_flow_read_source_key_v247(uuid)' THEN
  d:=replace(d,$a$'flow-key-v243:'||source_epoch||':'||freshness_key$a$,
   $b$'flow-key-v293:'||source_epoch||':'||freshness_key||':'||public.lts_scheduled_transfer_revision_v293(p_user_id)$b$);
  d:=replace(d,$a$key_value:=public.lts_flow_read_key_engine_v243(p_user_id);$a$,
   $b$key_value:=md5(public.lts_flow_read_key_engine_v243(p_user_id)||':schedules-v293:'||public.lts_scheduled_transfer_revision_v293(p_user_id));$b$);
 ELSE
  bank_body:=substring(d from position('AS $function$' in d)+length('AS $function$'));
  bank_body:=substring(bank_body from 1 for position('$function$' in bank_body)-1);
  old:=bank_body;
  bank_body:=regexp_replace(bank_body,';[[:space:]]*$','');
  d:=replace(d,old,E'\nSELECT md5(coalesce(('||bank_body||$b$),'')||':schedules-v293:'||public.lts_scheduled_transfer_revision_v293(p_user_id));
$b$);
 END IF;
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=prior_oid AND(proowner<>prior_owner OR proacl IS DISTINCT FROM prior_acl
 OR proconfig IS DISTINCT FROM prior_config OR prosecdef<>prior_security OR provolatile<>prior_volatility))
 OR r.sig::regprocedure::oid<>prior_oid THEN RAISE EXCEPTION 'Future reader identity/ACL changed';END IF;
 END LOOP;
END $patch$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
DO $parity$
DECLARE b record;j jsonb;e jsonb;h jsonb; old_day jsonb;new_day jsonb;bank text;day_delta numeric;running_delta numeric;got numeric;expected_count integer;actual_events jsonb;
BEGIN
 FOR b IN SELECT * FROM schedule_baseline_v293 LOOP
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO e FROM public.lts_v229_expense_rows(b.user_id,'2013-10-10',current_date)x;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]') INTO h FROM public.lts_flow_past_operational_v2(b.user_id,current_date-60,current_date-1)x;
 IF e IS DISTINCT FROM b.expenses OR h IS DISTINCT FROM b.history THEN RAISE EXCEPTION 'Schedules changed actual expenses or historical Flow';END IF;
 j:=public.lts_daily_flow_fix86_v20(b.user_id,current_date,current_date+60);
 SELECT count(*) INTO expected_count FROM public.lts_flow_projected_transfer_legs_v293(b.user_id,current_date,current_date+60)
 WHERE confidence='bank_scheduled_owner_confirmed_v293';
 SELECT coalesce(jsonb_agg(x ORDER BY x::text),'[]') INTO actual_events FROM jsonb_array_elements(j->'events')x
 WHERE x->>'confidence'='bank_scheduled_owner_confirmed_v293';
 IF expected_count=0 OR jsonb_array_length(actual_events)<>expected_count OR expected_count%2<>0
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(actual_events)x WHERE x->>'is_projection' IS DISTINCT FROM 'true'
 OR x->>'realization_confirmed' IS DISTINCT FROM 'false' OR x->>'internal_transfer' IS DISTINCT FROM 'true')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(actual_events)x GROUP BY x->>'event_date',x->>'bank_schedule_source_id'
 HAVING count(*)<>2 OR sum((x->>'signed_amount')::numeric)<>0) THEN RAISE EXCEPTION 'Schedule pair is not neutral or correctly projected';END IF;
 IF (SELECT coalesce(jsonb_agg(x ORDER BY x::text),'[]') FROM jsonb_array_elements(j->'events')x WHERE x->>'confidence' IS DISTINCT FROM 'bank_scheduled_owner_confirmed_v293')
 IS DISTINCT FROM(SELECT coalesce(jsonb_agg(x ORDER BY x::text),'[]') FROM jsonb_array_elements(b.future->'events')x)
 THEN RAISE EXCEPTION 'Existing future events changed';END IF;
 FOR old_day IN SELECT * FROM jsonb_array_elements(b.future->'days') LOOP
  SELECT x INTO STRICT new_day FROM jsonb_array_elements(j->'days')x WHERE x->>'date'=old_day->>'date';
  IF new_day-'Itaú'-'Bradesco'-'C6'-'summary' IS DISTINCT FROM old_day-'Itaú'-'Bradesco'-'C6'-'summary'
   OR(new_day->'summary')-'transfers' IS DISTINCT FROM(old_day->'summary')-'transfers'
  THEN RAISE EXCEPTION 'Consolidated cash, liquidity or economic spend changed';END IF;
  FOREACH bank IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
   SELECT coalesce(sum((x->>'signed_amount')::numeric)FILTER(WHERE x->>'event_date'=old_day->>'date'),0),
    coalesce(sum((x->>'signed_amount')::numeric),0) INTO day_delta,running_delta FROM jsonb_array_elements(actual_events)x
    WHERE x->>'account'=bank AND(x->>'event_date')::date<=(old_day->>'date')::date;
   IF new_day->bank IS DISTINCT FROM(old_day->bank)||jsonb_build_object(
    'net',(old_day#>>ARRAY[bank,'net'])::numeric+day_delta,'balance',(old_day#>>ARRAY[bank,'balance'])::numeric+running_delta)
   THEN RAISE EXCEPTION 'Per-bank forecast delta is incorrect for % on %',bank,old_day->>'date';END IF;
  END LOOP;
 END LOOP;
 END LOOP;
END $parity$;
