-- V307: preserve native financial responses while eliminating repeated work.
-- Source-specific decisions, transfer/payment identities and read boundaries stay intact.
DO $patch$
DECLARE f record;d text;prior jsonb;
BEGIN
 -- Fail before changing anything if a reviewed source contract has moved.
 FOR f IN SELECT * FROM(VALUES
 ('public.lts_historical_cash_engine_v243(uuid,date,date)','0498aef77c7c7970de52c6712c0d6c30'),
 ('public.lts_historical_effective_cash_v2(uuid,date,date)','e9e5f710fe7144af4117a4a11688890d'),
 ('public.lts_historical_effective_cash_v3(uuid,date,date)','050c13521f38b8357a59e62ee0edc50f'),
 ('public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)','240849f813a9ac43b853d42440ef02b0'),
 ('public.lts_v246_invalidate_finance_cache()','99f49c4f11e130d6cab4196173f41ec0'),
 ('public.lts_card_due_rule_changed_v290()','41afb5446b828a833c712a6e1afff444'),
 ('public.lts_historical_effective_cash_pre_v246(uuid,date,date)','1f72d7ac2b27a5e111de3f1c7d41fb42')
 ) x(signature,expected_md5) LOOP
  IF (SELECT md5(pg_get_functiondef(oid)) FROM pg_proc WHERE oid=to_regprocedure(f.signature))
   IS DISTINCT FROM f.expected_md5 THEN RAISE EXCEPTION 'V307 dependency lease changed: %',f.signature;END IF;
 END LOOP;
 IF has_table_privilege('anon','public.lts_v229_read_cache','SELECT')
 OR has_table_privilege('anon','public.lts_v229_read_cache','INSERT')
 OR has_table_privilege('authenticated','public.lts_v229_read_cache','SELECT')
 OR has_table_privilege('authenticated','public.lts_v229_read_cache','INSERT')
 THEN RAISE EXCEPTION 'V307 requires the existing private cache boundary';END IF;
 -- V246 ignores only sync_run_id/last_seen_at/updated_at in staging; the
 -- new fingerprint hashes these receipt fields across every bank explicitly.
 IF EXISTS(SELECT 1 FROM(VALUES
 ('lts_open_finance_staging'),('card_invoices'),('lts_card_document_supplement_v234'),
 ('financial_events'),('lts_semantic_rule'),('lts_v178_review_decision'),
 ('lts_reconciliation_evidence'),('source_documents')
 ) r(table_name) WHERE 4<>(SELECT count(*) FROM pg_trigger t
 JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname=r.table_name AND NOT t.tgisinternal
 AND t.tgenabled='O' AND t.tgfoid='public.lts_v246_invalidate_finance_cache()'::regprocedure))
 THEN RAISE EXCEPTION 'V307 financial invalidation triggers changed';END IF;
 FOR f IN SELECT * FROM(VALUES
 ('public.lts_browser_flow_v3(date,date)','41362aab6cbd75cbdf07bf35d469c85a','be39fcc328bf7cfcb121c397412d4c3c'),
 ('public.lts_flow_classification_source_overlay_v1(uuid,jsonb)','9d17d21a15033ec36732c02c786b2f93','7e06b19c18e390462ca13f16a1266cd0'),
 ('public.lts_flow_historical_balance_truth_overlay_v1(uuid,jsonb)','c57a346a425aeb2a2541a8d431f089dd','92a277addd3e4bc8f673dca2012c35cb'),
 ('public.lts_flow_documentary_close_overlay_v1(uuid,jsonb)','9861c02438b37c4e25c3d2de9c908e65','bc783ed13273a0bc8cfabca92db54d02'),
 ('public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)','2644f35b6491e39c5d9d5e588e3cd638','b39fae95c6521eed97336038429e10ca'),
 ('public.lts_workbook_first_c6_date_v253(uuid)','9c440953ab95d278069021b9409ee30f','bc49ad8dba4956282a3067bc62d9b7ea'),
 ('public.lts_daily_flow_full_query_v4(uuid,date,date)','ed0bac91cb4e30a465f980e1d48081b1','87816e9d81d6ae72e0ffa4f6a7ea924b'),
 ('public.lts_c6_completeness_state_v269(uuid)','edf82eac9983a8679c37d9b7a9de3f1f','b987868460604430e0fd3c15cb22a9a0'),
 ('public.lts_card_invoice_amounts_v230_engine_v243(uuid)','7ad9c0296f9582e47c9a6c63cf8558d2','316bba0d2c608c0a11b77b3a76c8ef49'),
 ('public.lts_browser_flow_v242(date,date)','3c25b1950d348a417dc996f1863f294e','3a412531342a1ece832f01f849fa8c4f'),
 ('public.lts_card_cycles_v226(uuid)','bad00fdc296f78ad36e2cca6ef1ce75d','58b393f8b4b6c6c2958b1599b54786d2')
 ) x(signature,before_md5,after_md5) LOOP
  SELECT pg_get_functiondef(oid) INTO d FROM pg_proc WHERE oid=to_regprocedure(f.signature);
  IF d IS NULL OR md5(d) NOT IN(f.before_md5,f.after_md5)
  THEN RAISE EXCEPTION 'V307 definition lease changed: %',f.signature;END IF;
 END LOOP;

 IF to_regprocedure('public.lts_prepared_card_cycles_v307(uuid)') IS NULL THEN
  EXECUTE $helper$
CREATE OR REPLACE FUNCTION public.lts_prepared_card_cycles_v307(p_user_id uuid)
 RETURNS jsonb LANGUAGE plpgsql
 SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE s jsonb; cycles jsonb;
BEGIN
 IF p_user_id IS NULL OR current_setting('transaction_read_only')::boolean THEN
  RETURN public.lts_card_cycles_v226(p_user_id);
 END IF;
 s:=public.lts_c6_completeness_state_v269(p_user_id);
 SELECT c.payload INTO cycles FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='card_cycles_snapshot_v307'
 AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=s->>'source_revision';
 IF jsonb_typeof(cycles)='object' THEN RETURN cycles; END IF;
 RETURN public.lts_card_cycles_v226(p_user_id);
END $function$;
$helper$;
  REVOKE ALL ON FUNCTION public.lts_prepared_card_cycles_v307(uuid) FROM PUBLIC,anon,authenticated;
  GRANT EXECUTE ON FUNCTION public.lts_prepared_card_cycles_v307(uuid) TO service_role;
 END IF;
 IF (SELECT md5(pg_get_functiondef(oid))<>'291dc64044041416759df58589a50b44'
 OR prosecdef OR provolatile<>'v' OR proconfig IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo']
 FROM pg_proc WHERE oid='public.lts_prepared_card_cycles_v307(uuid)'::regprocedure)
 OR has_function_privilege('anon','public.lts_prepared_card_cycles_v307(uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_prepared_card_cycles_v307(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'V307 helper definition or access changed';END IF;

 FOR f IN SELECT * FROM(VALUES
 ('public.lts_browser_flow_v3(date,date)','41362aab6cbd75cbdf07bf35d469c85a','be39fcc328bf7cfcb121c397412d4c3c'),
 ('public.lts_flow_classification_source_overlay_v1(uuid,jsonb)','9d17d21a15033ec36732c02c786b2f93','7e06b19c18e390462ca13f16a1266cd0'),
 ('public.lts_flow_historical_balance_truth_overlay_v1(uuid,jsonb)','c57a346a425aeb2a2541a8d431f089dd','92a277addd3e4bc8f673dca2012c35cb'),
 ('public.lts_flow_documentary_close_overlay_v1(uuid,jsonb)','9861c02438b37c4e25c3d2de9c908e65','bc783ed13273a0bc8cfabca92db54d02'),
 ('public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)','2644f35b6491e39c5d9d5e588e3cd638','b39fae95c6521eed97336038429e10ca'),
 ('public.lts_workbook_first_c6_date_v253(uuid)','9c440953ab95d278069021b9409ee30f','bc49ad8dba4956282a3067bc62d9b7ea'),
 ('public.lts_daily_flow_full_query_v4(uuid,date,date)','ed0bac91cb4e30a465f980e1d48081b1','87816e9d81d6ae72e0ffa4f6a7ea924b'),
 ('public.lts_c6_completeness_state_v269(uuid)','edf82eac9983a8679c37d9b7a9de3f1f','b987868460604430e0fd3c15cb22a9a0'),
 ('public.lts_card_invoice_amounts_v230_engine_v243(uuid)','7ad9c0296f9582e47c9a6c63cf8558d2','316bba0d2c608c0a11b77b3a76c8ef49'),
 ('public.lts_browser_flow_v242(date,date)','3c25b1950d348a417dc996f1863f294e','3a412531342a1ece832f01f849fa8c4f'),
 ('public.lts_card_cycles_v226(uuid)','bad00fdc296f78ad36e2cca6ef1ce75d','58b393f8b4b6c6c2958b1599b54786d2')
 ) x(signature,before_md5,after_md5) LOOP
  SELECT pg_get_functiondef(oid),jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
   'config',proconfig,'definer',prosecdef,'volatility',provolatile)
  INTO d,prior FROM pg_proc WHERE oid=to_regprocedure(f.signature);
  IF md5(d)=f.after_md5 THEN CONTINUE;END IF;
  CASE f.signature
  WHEN 'public.lts_browser_flow_v3(date,date)' THEN
   d:=replace(d,'hd jsonb:=''[]''::jsonb;','hd jsonb:=''[]''::jsonb; hd_rows_v307 jsonb[]:=ARRAY[]::jsonb[];');
   d:=replace(d,'hd:=hd||jsonb_build_array(x);','hd_rows_v307:=array_append(hd_rows_v307,x);');
   d:=replace(d,'f:=jsonb_set(f,''{historical,days}'',hd,true);','hd:=to_jsonb(hd_rows_v307);
  f:=jsonb_set(f,''{historical,days}'',hd,true);');
  WHEN 'public.lts_flow_classification_source_overlay_v1(uuid,jsonb)' THEN
   d:=replace(d,'declare section text;','declare rows_v307 jsonb[]; section text;');
   d:=replace(d,'rows:=''[]''::jsonb;','rows:=''[]''::jsonb;rows_v307:=ARRAY[]::jsonb[];');
   d:=replace(d,'rows:=rows||jsonb_build_array(e);','rows_v307:=array_append(rows_v307,e);');
   d:=replace(d,'if p_flow->section is not null then','rows:=to_jsonb(rows_v307);
 if p_flow->section is not null then');
  WHEN 'public.lts_flow_historical_balance_truth_overlay_v1(uuid,jsonb)' THEN
   d:=replace(d,'v_days jsonb := ''[]''::jsonb;','v_days jsonb := ''[]''::jsonb; v307_days jsonb[]:=ARRAY[]::jsonb[];');
   d:=replace(d,'v_days:=v_days||jsonb_build_array(v_day);','v307_days:=array_append(v307_days,v_day);');
   d:=replace(d,'return jsonb_set(p_flow,''{historical,days}'',v_days,true)','v_days:=to_jsonb(v307_days);
  return jsonb_set(p_flow,''{historical,days}'',v_days,true)');
  WHEN 'public.lts_flow_documentary_close_overlay_v1(uuid,jsonb)' THEN
   d:=replace(d,'outdays jsonb := ''[]''::jsonb;','outdays jsonb := ''[]''::jsonb; v307_days jsonb[]:=ARRAY[]::jsonb[];');
   d:=replace(d,'outdays := outdays || jsonb_build_array(d);','v307_days:=array_append(v307_days,d);');
   d:=replace(d,'return jsonb_set(p_flow, ''{historical,days}'', outdays, true)','outdays:=to_jsonb(v307_days);
  return jsonb_set(p_flow, ''{historical,days}'', outdays, true)');
  WHEN 'public.lts_flow_historical_relative_balance_overlay_v1(uuid,jsonb)' THEN
   d:=replace(d,'account_patch as (','account_patch as materialized (');
   d:=replace(d,'bradesco_patch as (','bradesco_patch as materialized (');
   d:=replace(d,'c6_patch as (','c6_patch as materialized (');
   d:=replace(d,'consolidated_patch as (','consolidated_patch as materialized (');
   d:=replace(d,'fix_patch as (','fix_patch as materialized (');
  WHEN 'public.lts_daily_flow_full_query_v4(uuid,date,date)' THEN
   -- V3 changes classification columns only; the tail reads dates/accounts/amounts.
   d:=replace(d,'public.lts_historical_effective_cash_v3(p_user_id,p_from,date ''2026-07-07'')',
    'public.lts_historical_effective_cash_v2(p_user_id,p_from,date ''2026-07-07'')');
   -- Recent-anchor rows cannot join days before that anchor. Retain the
   -- original later-date range so moved-in original events remain eligible.
   d:=replace(d,'select * from public.lts_flow_past_operational_v1(p_user_id,''2026-07-08'',current_date-1)',
    'select * from public.lts_flow_past_operational_v1(p_user_id,''2026-07-08'',current_date-1)'
    ||chr(10)||'    WHERE p_to>=date ''2026-07-07'' -- v307: this branch cannot join an earlier requested day');
  WHEN 'public.lts_workbook_first_c6_date_v253(uuid)' THEN
   -- Remove classification work only. Preserve posted-identity suppression,
   -- bank-effective dates, the paid C6 recovery and the original memo contract.
   d:=regexp_replace(d,'\mj\M','v307_memo','g');
   d:=replace(d,$oldmin$SELECT min(h.event_date) INTO d
 FROM public.lts_historical_effective_cash_pre_v246(p_user_id,date '2013-10-10',date '2026-07-07') h
 WHERE h.account='C6';$oldmin$,$newmin$SELECT min(h.event_date) INTO d FROM (
WITH paid AS MATERIALIZED(SELECT public.lts_c6_paid_identity_v237(p_user_id) j),

posted_identity AS (
 SELECT ev.id evidence_id,min(f.id::text) fact_id FROM public.lts_reconciliation_evidence ev
 JOIN public.financial_events f ON f.user_id=ev.user_id AND f.event_date::text=ev.metadata->>'posting_date'
  AND f.amount=ev.amount AND lower(trim(f.description_raw))=lower(trim(ev.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
  AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(ev.account)),'ú','u')
 WHERE ev.user_id=p_user_id AND ev.evidence_type='bank_statement' AND ev.status='documented'
  AND ev.metadata->>'cash_effect'='statement_fact_not_new_projection' AND ev.metadata->>'initiated_date'=ev.evidence_date::text
  AND ev.metadata->>'posting_date'>ev.evidence_date::text AND f.metadata->>'documented_statement_fact'='true'
  AND NOT f.is_suppressed AND NOT f.is_projection AND f.status<>'cancelled'
 GROUP BY ev.id HAVING count(*)=1
),
source_rows AS MATERIALIZED (
 SELECT e.event_date,e.account,e.source,e.source_ref
 FROM public.lts_historical_effective_cash_v2(p_user_id,date '2013-10-10'-7,date '2026-07-07'+7) e
),
base AS MATERIALIZED (
 SELECT e.* FROM source_rows e WHERE NOT(e.source='reconciliation_evidence'
 AND EXISTS(SELECT 1 FROM posted_identity p WHERE p.evidence_id::text=e.source_ref))
),
effective AS MATERIALIZED(
 SELECT e.evidence_date,f.id::text fact_id
 FROM public.lts_reconciliation_evidence e JOIN public.financial_events f
 ON f.user_id=e.user_id AND f.event_date::text=e.metadata->>'posting_date'
 AND f.amount=e.amount AND lower(trim(f.description_raw))=lower(trim(e.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(e.account)),'ú','u')
 WHERE e.user_id=p_user_id AND e.evidence_type='bank_statement' AND e.status='documented'
 AND e.metadata->>'cash_effect'='statement_fact_not_new_projection'
 AND e.metadata->>'balance_effective_date'=e.evidence_date::text AND e.metadata->>'initiated_date'=e.evidence_date::text
 AND f.event_date>e.evidence_date AND f.event_date<=e.evidence_date+7
 AND f.metadata->>'documented_statement_fact'='true' AND NOT f.is_projection AND NOT f.is_suppressed AND f.status<>'cancelled'
 AND e.evidence_date BETWEEN date '2013-10-10'-7 AND date '2026-07-07'+7
 GROUP BY e.id,e.evidence_date,f.id,a.institution
 HAVING (SELECT count(*) FROM public.financial_events fx JOIN public.accounts ax ON ax.id=fx.account_id
 WHERE fx.user_id=e.user_id AND fx.event_date=f.event_date AND fx.amount=e.amount
 AND lower(trim(fx.description_raw))=lower(trim(e.description)) AND ax.institution=a.institution
 AND NOT fx.is_projection AND NOT fx.is_suppressed AND fx.status<>'cancelled')=1
),
displaced AS (
 SELECT CASE WHEN b.source='legacy_fix86'
 AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx'))
 THEN (paid.j->>'paid_date')::date ELSE coalesce(e.evidence_date,b.event_date) END event_date,b.account
 FROM base b CROSS JOIN paid LEFT JOIN effective e
 ON b.source IN('current_event','financial_events','confirmed_fact')
 AND b.source_ref IN(e.fact_id,'financial_events:'||e.fact_id)
),
recovered AS (
 SELECT (paid.j->>'paid_date')::date event_date,'C6'::text account
 FROM paid WHERE paid.j IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM base b WHERE b.source_ref='evento_base:'||(paid.j->>'payment_idx'))
)
SELECT * FROM displaced WHERE event_date BETWEEN date '2013-10-10' AND date '2026-07-07'
UNION ALL SELECT * FROM recovered WHERE event_date BETWEEN date '2013-10-10' AND date '2026-07-07'
) h WHERE h.account='C6';$newmin$);
  WHEN 'public.lts_c6_completeness_state_v269(uuid)' THEN
   d:=split_part(d,'AS $function$',1)||'AS $function$'||$state$
DECLARE fingerprint text; epoch bigint; result jsonb; cycles jsonb;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 -- Financial inputs in every bank are guarded by the existing epoch triggers.
 -- Include receipt-only fields explicitly: V246 deliberately ignores these.
 -- Settlement links/contracts are also hashed because they have no epoch trigger.
 SELECT 'v307-card-state:'||epoch||':'||md5(
  coalesce((SELECT string_agg(jsonb_build_array(s.id,s.sync_run_id,s.last_seen_at,s.updated_at)::text,'' ORDER BY s.id)
   FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(i)::text,'' ORDER BY i.id)
   FROM public.card_invoices i WHERE i.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(d)::text,'' ORDER BY d.id)
   FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(l)::text,'' ORDER BY l.id)
   FROM public.lts_card_documentary_payment_link_v272 l WHERE l.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(c)::text,'' ORDER BY c.payment_source_id)
   FROM public.lts_card_settlement_expense_contract_v273 c WHERE c.user_id=p_user_id),'')
 ) INTO fingerprint;
 SELECT payload INTO result FROM public.lts_v229_read_cache
 WHERE user_id=p_user_id AND kind='card_completeness_v269'
 AND as_of=current_date AND from_date=current_date AND to_date=current_date
 AND source_fingerprint=fingerprint;
 IF FOUND THEN RETURN result; END IF;
 cycles:=public.lts_card_cycles_v226(p_user_id);
 result:=jsonb_build_object('complete',coalesce((cycles->>'complete')::boolean,true),
  'incomplete_families',coalesce(cycles->'incomplete_families','[]'::jsonb),
  'source_revision',fingerprint,'source_epoch',epoch);
 IF epoch IS DISTINCT FROM(SELECT e.epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_completeness_v269',current_date,current_date,current_date,
   result,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
   payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_cycles_snapshot_v307',current_date,current_date,current_date,
   cycles,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
   payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 END IF;
 RETURN result;
END $state$||'$function$'||chr(10);
  WHEN 'public.lts_card_invoice_amounts_v230_engine_v243(uuid)' THEN
   d:=replace(d,'public.lts_card_cycles_v226(p_user_id)','public.lts_prepared_card_cycles_v307(p_user_id)');
  WHEN 'public.lts_browser_flow_v242(date,date)' THEN
   d:=replace(d,'public.lts_card_cycles_v226(u)','public.lts_prepared_card_cycles_v307(u)');
  WHEN 'public.lts_card_cycles_v226(uuid)' THEN
   d:=replace(d,'FROM public.lts_card_document_matches_v234(p_user_id)m',
    'FROM document_matches_v298 m -- v307-shared-document-match'||chr(10));
  ELSE RAISE EXCEPTION 'Unexpected V307 target';
  END CASE;
  EXECUTE d;
  IF (SELECT md5(pg_get_functiondef(oid)) FROM pg_proc WHERE oid=to_regprocedure(f.signature))<>f.after_md5
  THEN RAISE EXCEPTION 'V307 replacement result changed: %',f.signature;END IF;
  IF prior IS DISTINCT FROM(SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,
   'config',proconfig,'definer',prosecdef,'volatility',provolatile)
   FROM pg_proc WHERE oid=to_regprocedure(f.signature))
  THEN RAISE EXCEPTION 'V307 identity or security attributes changed: %',f.signature;END IF;
 END LOOP;
END $patch$;

