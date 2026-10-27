"""Documented one-occurrence forecast batch, native PostgreSQL. Synthetic only."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
batch=(R/'backend/patches/v350/documented_forecast_batch.sql').read_text()
cols='event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean'
print(r'''
BEGIN;
CREATE TABLE public.accounts(id uuid,user_id uuid,institution text);
CREATE TABLE public.evento_base(usuario_id uuid,idx integer,dados jsonb);
CREATE TABLE public.financial_events(id uuid DEFAULT gen_random_uuid(),user_id uuid,account_id uuid,legacy_id text,event_date date,description_raw text,description_normalized text,amount numeric,nature text,category text,counterparty text,source text,status text,is_internal_transfer boolean,is_projection boolean,is_suppressed boolean,metadata jsonb);
CREATE TABLE public.lts_projection_replacement_rule(id text,user_id uuid,source_table text,description_exact text,account_exact text,date_from date,date_to date,action text,replacement_source text,replacement_ref text,reason text,evidence jsonb,active boolean);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,normalized_payload jsonb,raw_payload jsonb,posting_date date,signed_amount numeric,raw_hash text,provider_account_ref text,description_raw text,institution_name text);
CREATE TABLE public.lts_commitment_documentary_schedule(user_id uuid,commitment_id text,due_date date,amount_total numeric);
CREATE FUNCTION public.lts_v178_norm(text)RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower(translate($1,'ú','u'))$$;
INSERT INTO public.accounts VALUES('a0000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Itaú');
INSERT INTO public.evento_base VALUES
 ('00000000-0000-4000-8000-000000000001',1,'{"dia":"2027-01-31","desc":"Salário","conta":"Itau","valor":100,"efeito":"entrada"}'),
 ('00000000-0000-4000-8000-000000000001',2,'{"dia":"2027-02-01","desc":"English Class","conta":"Itau","valor":20,"efeito":"saida"}'),
 ('00000000-0000-4000-8000-000000000001',3,'{"dia":"2027-02-28","desc":"Salário","conta":"Itau","valor":100,"efeito":"entrada"}'),
 ('00000000-0000-4000-8000-000000000001',4,'{"dia":"2027-02-01","desc":"Unrelated expense","conta":"Itau","valor":30,"efeito":"saida"}');
INSERT INTO public.evento_base SELECT '00000000-0000-4000-8000-000000000002',idx,dados FROM public.evento_base;
INSERT INTO public.lts_commitment_documentary_schedule VALUES('00000000-0000-4000-8000-000000000001','coopharma','2027-01-31',30),('00000000-0000-4000-8000-000000000001','coopharma','2027-02-28',30);
''')
print('CREATE FUNCTION public.lts_corrected_cashflow_fix86_v4(p_uid uuid,p_from date,p_to date)RETURNS TABLE('+cols+r''')LANGUAGE sql AS $$
SELECT(h.dados->>'dia')::date,'Itaú',h.dados->>'desc',(CASE WHEN h.dados->>'efeito'='entrada'THEN 1 ELSE -1 END)*(h.dados->>'valor')::numeric,'legacy_fix86','evento_base:'||h.idx,'legacy_projection_adjusted','assigned',h.idx,(h.dados->>'dia')::date,false FROM public.evento_base h
WHERE h.usuario_id=p_uid AND(h.dados->>'dia')::date BETWEEN p_from AND p_to
AND NOT EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule r WHERE r.user_id=p_uid AND r.active AND r.description_exact=h.dados->>'desc'AND r.account_exact=h.dados->>'conta'AND(h.dados->>'dia')::date BETWEEN r.date_from AND r.date_to)
UNION ALL SELECT e.event_date,'Itaú',e.description_normalized,e.amount,'current_event',e.legacy_id,CASE e.status WHEN 'scheduled'THEN 'documented_scheduled'ELSE 'documented_expected'END,'assigned',NULL,e.event_date,false FROM public.financial_events e WHERE e.user_id=p_uid AND NOT e.is_suppressed AND e.event_date BETWEEN p_from AND p_to$$;
''')
print('CREATE FUNCTION public.lts_corrected_cashflow_fix86_v5(p_uid uuid,p_from date,p_to date)RETURNS TABLE('+cols+')LANGUAGE sql AS $$SELECT *FROM public.lts_corrected_cashflow_fix86_v4(p_uid,p_from,p_to)$$;')
for name in ['v350_withholding.sql','v350_operational.sql']:print((R/'backend/qa/fixtures'/name).read_text()+';')
print(r'''
CREATE FUNCTION public.lts_v229_expense_rows(uuid,date,date)RETURNS TABLE(row_key text,amount numeric)LANGUAGE sql AS $$SELECT 'synthetic-history',44::numeric$$;
INSERT INTO public.lts_open_finance_staging SELECT ('b0000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000001','transaction',NULL,'{"status":"PENDING"}','{"status":"PENDING"}',CASE i WHEN 1 THEN date '2027-01-27'ELSE date '2027-02-15'END,CASE i WHEN 1 THEN -5 ELSE -10 END,'synthetic-hash-'||i,'synthetic-bank-account','Synthetic bank schedule '||i,'Itaú'FROM generate_series(1,2)i;
SELECT set_config('lts.v350_owner','00000000-0000-4000-8000-000000000001',true);
SELECT set_config('lts.v350_manifest',jsonb_build_object('window_from','2027-01-01','window_to','2027-03-31',
 'replacements',(SELECT jsonb_agg(to_jsonb(r))FROM public.lts_corrected_cashflow_operational_v1('00000000-0000-4000-8000-000000000001','2027-01-01','2027-03-31')r WHERE source_ref IN('evento_base:1','evento_base:2')),
 'rules',(SELECT jsonb_agg(jsonb_build_object('id','synthetic-rule-'||idx,'source_ref',idx::text,'source_payload',dados,'date_from',dados->>'dia','date_to',dados->>'dia','action','suppress_legacy','description_exact',dados->>'desc','account_exact','Itau','reason','Documented one occurrence','evidence','{}'::jsonb))FROM public.evento_base WHERE usuario_id='00000000-0000-4000-8000-000000000001'AND idx<=2),
 'events',jsonb_build_array(jsonb_build_object('kind','documented_net_payroll','legacy_id','synthetic-net-payroll','account_id','a0000000-0000-4000-8000-000000000001','bank','Itaú','event_date','2027-01-29','description_raw','Salário líquido','description_normalized','Salário líquido','amount',90,'nature','income','category','Salário','source','documented_net_payroll','status','expected','metadata',jsonb_build_object('cash_basis','documented_net_payroll','document_sha256',repeat('a',64),'source_file','synthetic.png')))
 ||(SELECT jsonb_agg(jsonb_build_object('kind','documented_bank_schedule','legacy_id','synthetic-bank-'||id,'account_id','a0000000-0000-4000-8000-000000000001','bank','Itaú','event_date',posting_date,'description_raw',description_raw,'description_normalized',description_raw,'amount',signed_amount,'nature','expense','category','Synthetic category','source','documented_bank_schedule','status','scheduled','staging_id',id,'staging_raw_hash',raw_hash,'provider_account_ref',provider_account_ref,'metadata',jsonb_build_object('bank_scheduled_received',true,'schedule_evidence_files',jsonb_build_array('synthetic.png'))))FROM public.lts_open_finance_staging))::text,true);
CREATE TEMP TABLE v350_batch(sql text);
''')
print('INSERT INTO v350_batch VALUES($qa$'+batch+'$qa$);')
print(r'''
CREATE TEMP TABLE v350_cases(name text,mutation text);
INSERT INTO v350_cases VALUES
 ('posted is not pending',$q$UPDATE public.lts_open_finance_staging SET normalized_payload='{"status":"POSTED"}'WHERE signed_amount=-5$q$),
 ('changed hash',$q$UPDATE public.lts_open_finance_staging SET raw_hash='changed'WHERE signed_amount=-5$q$),
 ('wrong owner',$q$SELECT set_config('lts.v350_owner','00000000-0000-4000-8000-000000000002',true)$q$),
 ('changed legacy amount',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{valor}','101')WHERE idx=1$q$),
 ('duplicate operation',$q$SELECT set_config('lts.v350_manifest',jsonb_set(current_setting('lts.v350_manifest')::jsonb,'{events}',(current_setting('lts.v350_manifest')::jsonb->'events')||jsonb_build_array(current_setting('lts.v350_manifest')::jsonb#>'{events,0}'))::text,true)$q$),
 ('net incorrectly labelled gross',$q$SELECT set_config('lts.v350_manifest',jsonb_set(current_setting('lts.v350_manifest')::jsonb,'{events,0,description_normalized}','"Salário"')::text,true)$q$),
 ('missing documentary hash',$q$SELECT set_config('lts.v350_manifest',jsonb_set(current_setting('lts.v350_manifest')::jsonb,'{events,0,metadata,document_sha256}','null')::text,true)$q$),
 ('stale effective amount',$q$SELECT set_config('lts.v350_manifest',jsonb_set(current_setting('lts.v350_manifest')::jsonb,'{replacements,0,signed_amount}','71')::text,true)$q$),
 ('expanded cancellation scope',$q$SELECT set_config('lts.v350_manifest',jsonb_set(current_setting('lts.v350_manifest')::jsonb,'{rules,1,date_to}','"2027-02-02"')::text,true)$q$);
DO $test$DECLARE c record;m text;BEGIN FOR c IN SELECT *FROM v350_cases LOOP BEGIN
 EXECUTE c.mutation;m:=NULL;BEGIN EXECUTE(SELECT sql FROM v350_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS NULL OR m NOT LIKE 'V350_%'THEN RAISE EXCEPTION 'Invalid proof accepted: % / %',c.name,m;END IF;
 RAISE EXCEPTION USING ERRCODE='V3500',MESSAGE='rollback fixture';EXCEPTION WHEN SQLSTATE 'V3500'THEN NULL;END;END LOOP;END$test$;
''')
print(batch)
print(r'''
DO $test$DECLARE m text;BEGIN
 IF(current_setting('lts.v350_receipt')::jsonb->>'delta')::numeric<>25 THEN RAISE EXCEPTION 'Incorrect net cash';END IF;
 IF(SELECT signed_amount FROM public.lts_corrected_cashflow_operational_v1('00000000-0000-4000-8000-000000000001','2027-01-01','2027-03-31')WHERE source_ref='synthetic-net-payroll')<>90 THEN RAISE EXCEPTION 'Withholding deducted again';END IF;
 IF(SELECT signed_amount FROM public.lts_corrected_cashflow_operational_v1('00000000-0000-4000-8000-000000000001','2027-01-01','2027-03-31')WHERE source_ref='evento_base:3')<>70 THEN RAISE EXCEPTION 'Other salary month changed';END IF;
 IF EXISTS(SELECT 1 FROM public.financial_events WHERE user_id<>'00000000-0000-4000-8000-000000000001'OR NOT is_projection OR is_internal_transfer OR status NOT IN('scheduled','expected'))THEN RAISE EXCEPTION 'Owner or realization changed';END IF;
 BEGIN EXECUTE(SELECT sql FROM v350_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V350_ALREADY_APPLIED_REVIEW_REQUIRED'THEN RAISE EXCEPTION 'Replay not rejected';END IF;
END$test$;
SELECT jsonb_build_object('pass',true,'version',350,'rejection_cases',(SELECT count(*)FROM v350_cases),'actual_payroll_withholding_contract',true,'net_not_deducted_twice',true,'other_month_preserved',true,'raw_source_preserved',true,'realized_spending_preserved',true,'replay_rejected',true);
ROLLBACK;
''')
