-- Run only after the isolated synthetic setup and source_adapter.sql.
CREATE TABLE public.qa_adapter_checks(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass));
CREATE VIEW public.qa_adapter_facts AS
 SELECT f.* FROM public.qa_adapter_policy p CROSS JOIN LATERAL
 lts_projection_private_v412.monthly_source_facts_v412('00000000-0000-4000-8000-000000000001',
 '2025-01-01','2025-12-31',p.policy)f;
INSERT INTO public.qa_adapter_checks
SELECT 'twelve months with transactions do not certify complete corpus',count(*)=2 AND bool_and(coverage='observed')
 FROM public.qa_adapter_facts WHERE series_key='person care';
INSERT INTO public.qa_adapter_checks
SELECT 'unaudited absent expense is never a documented zero',count(*)=0
 FROM public.qa_adapter_facts WHERE series_key='person care' AND coverage='documented_zero';
WITH ledger AS (
 SELECT e.competence_month AS period,
  encode(sha256(convert_to(jsonb_agg(to_jsonb(e)ORDER BY e.row_key)::text,'UTF8')),'hex') AS sha
 FROM public.lts_v229_expense_rows('00000000-0000-4000-8000-000000000001','2025-01-01','2025-12-31')e GROUP BY 1
), bank AS (
 SELECT date_trunc('month',b.posting_date)::date AS period,
  encode(sha256(convert_to(jsonb_agg(jsonb_build_object('source_id',b.id,'posting_date',b.posting_date,
   'signed_amount',b.signed_amount,'currency',b.currency,'account_ref',b.provider_account_ref,
   'institution_code',b.institution_code,'description',b.description_raw,'status',b.normalized_payload->>'status')
   ORDER BY b.id)::text,'UTF8')),'hex') AS sha
 FROM public.lts_bank_posted_rows_v231('00000000-0000-4000-8000-000000000001')b GROUP BY 1
), proof AS (
 SELECT jsonb_agg(jsonb_build_object('series_key','person care','month',l.period,'coverage','complete',
  'ledger_sha256',l.sha,'bank_sha256',b.sha,'audit_ref','synthetic-audit','audit_sha256',repeat('f',64),
  'reviewed_on','2026-01-01')ORDER BY l.period) AS entries FROM ledger l JOIN bank b USING(period)
)
UPDATE public.qa_adapter_policy p SET policy=p.policy||jsonb_build_object('audited_coverage',proof.entries) FROM proof;
INSERT INTO public.qa_adapter_checks
SELECT 'covered ledger contains twelve months',count(*)=12 FROM public.qa_adapter_facts WHERE series_key='person care';
INSERT INTO public.qa_adapter_checks
SELECT 'direct scope excludes cards, other beneficiary and other owner',sum(amount_brl)=150 FROM public.qa_adapter_facts WHERE series_key='person care';
INSERT INTO public.qa_adapter_checks
SELECT 'ten covered zero months remain in denominator',count(*)=10 AND bool_and(amount_brl=0)
 FROM public.qa_adapter_facts WHERE series_key='person care' AND coverage='documented_zero';
INSERT INTO public.qa_adapter_checks
SELECT 'identified general category does not infer a named beneficiary',coverage='documented_zero' AND amount_brl=0
 FROM public.qa_adapter_facts WHERE series_key='person care' AND month='2025-02-01';
INSERT INTO public.qa_adapter_checks
SELECT 'documentary settlement does not block zero coverage',coverage='documented_zero'
 FROM public.qa_adapter_facts WHERE series_key='person care' AND month='2025-10-01';
INSERT INTO public.qa_adapter_checks
SELECT 'issuer total counted once without purchases or payments',count(*)=12 AND sum(amount_brl)=6078
 FROM public.qa_adapter_facts WHERE series_key='card_c6';
INSERT INTO public.qa_adapter_checks
SELECT 'posted bill aliases retain twelve source values',count(*)=12 AND sum(amount_brl)=1278 AND bool_and(coverage='complete')
 FROM public.qa_adapter_facts WHERE series_key='utility';
INSERT INTO public.qa_adapter_checks
SELECT 'all complete facts preserve source identities and hashes',bool_and(jsonb_array_length(source_refs)>0 AND jsonb_array_length(raw_hashes)>0)
 FROM public.qa_adapter_facts;
INSERT INTO public.qa_adapter_checks
SELECT 'future year scenario reads no unclosed historical facts',count(*)=0
 FROM public.qa_adapter_policy p CROSS JOIN LATERAL lts_projection_private_v412.monthly_source_facts_v412(
 '00000000-0000-4000-8000-000000000001',make_date(extract(year FROM current_date)::int+1,1,1),
 make_date(extract(year FROM current_date)::int+1,12,31),p.policy)f;

DELETE FROM public.lts_open_finance_staging WHERE posting_date BETWEEN '2025-06-01' AND '2025-06-30';
DELETE FROM public.qa_adapter_expenses WHERE competence_month='2025-06-01';
INSERT INTO public.qa_adapter_checks
SELECT 'truly missing month is absent, never zero',count(*)=0 FROM public.qa_adapter_facts WHERE month='2025-06-01';
INSERT INTO public.qa_adapter_expenses VALUES
 ('00000000-0000-4000-8000-000000000001','unknown:1','2025-05-03','2025-05-01',25,'A classificar',NULL,'Unknown','synthetic','unknown','direct_cash',NULL);
INSERT INTO public.qa_adapter_checks
SELECT 'unknown direct source blocks zero completeness',count(*)=0 FROM public.qa_adapter_facts WHERE series_key='person care' AND month='2025-05-01';
INSERT INTO public.qa_adapter_expenses VALUES
 ('00000000-0000-4000-8000-000000000001','unknown:2','2025-03-03','2025-03-01',25,'A classificar',NULL,'Unknown','synthetic','unknown2','direct_cash',NULL);
INSERT INTO public.qa_adapter_checks
SELECT 'known expense plus unknown source remains partial',coverage='observed' AND amount_brl=50
 FROM public.qa_adapter_facts WHERE series_key='person care' AND month='2025-03-01';
UPDATE public.lts_card_documentary_payment_link_v272 SET payment_raw_hash=repeat('f',64);
INSERT INTO public.qa_adapter_checks
SELECT 'changed settlement hash no longer grants zero coverage',count(*)=0 FROM public.qa_adapter_facts WHERE series_key='person care' AND month='2025-10-01';
INSERT INTO public.lts_open_finance_staging
 SELECT md5('duplicate-utility')::uuid,user_id,resource_type,provider_deleted_at,currency,signed_amount,
 raw_hash,posting_date,institution_code,institution_name,provider_account_ref,normalized_payload,raw_payload,description_raw
 FROM public.lts_open_finance_staging WHERE id=md5('utility-11')::uuid;
INSERT INTO public.qa_adapter_checks
SELECT 'multiple bill candidates remain partial',coverage='observed'
 FROM public.qa_adapter_facts WHERE series_key='utility' AND month='2025-11-01';
INSERT INTO public.lts_open_finance_staging
 SELECT md5('duplicate-invoice')::uuid,user_id,resource_type,provider_deleted_at,currency,signed_amount,
 raw_hash,posting_date,institution_code,institution_name,provider_account_ref,normalized_payload,raw_payload,description_raw
 FROM public.lts_open_finance_staging WHERE id=md5('invoice-7')::uuid;
INSERT INTO public.qa_adapter_checks
SELECT 'ambiguous invoice month is not summed or chosen',count(*)=0 FROM public.qa_adapter_facts WHERE series_key='card_c6' AND month='2025-07-01';
INSERT INTO public.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000002','invoice',NULL,'BRL',100,
 repeat('f',64),'2025-01-01','000','Foreign bank','foreign','{"valid":"broken","due_date":"broken"}','{}',NULL);
INSERT INTO public.qa_adapter_checks
SELECT 'malformed foreign owner source cannot poison owner read',count(*)>0 FROM public.qa_adapter_facts;

INSERT INTO public.qa_adapter_checks
SELECT 'tax templates preserve installments, license and ownership',count(*)=3 AND sum(t.amount_brl)=220
 FROM public.qa_adapter_policy p CROSS JOIN LATERAL lts_projection_private_v412.calendar_templates_v412(
 '00000000-0000-4000-8000-000000000001',p.policy)t WHERE t.series_key IN('tax a','tax b');
INSERT INTO public.qa_adapter_checks
SELECT 'annual income keeps original unusual calendar',event_month=2 AND event_day=20 AND amount_brl=300
 FROM public.qa_adapter_policy p CROSS JOIN LATERAL lts_projection_private_v412.calendar_templates_v412(
 '00000000-0000-4000-8000-000000000001',p.policy)t WHERE t.series_key='annual income';
INSERT INTO public.qa_adapter_checks
SELECT 'history mean never clones inflated future utility template',count(*)=0
 FROM public.qa_adapter_policy p CROSS JOIN LATERAL lts_projection_private_v412.calendar_templates_v412(
 '00000000-0000-4000-8000-000000000001',p.policy)t WHERE t.series_key='utility';
INSERT INTO public.qa_adapter_checks
SELECT 'canonical shifted card dates remain exact',count(*)=2 AND bool_and(
 (reference_month='2026-11-01' AND due_date='2026-12-03') OR (reference_month='2026-12-01' AND due_date='2027-01-03'))
 FROM lts_projection_private_v412.known_card_periods_v412('00000000-0000-4000-8000-000000000001') WHERE series_key='card_aeternum';
INSERT INTO public.qa_adapter_checks
SELECT 'unknown card amount remains null and incomplete',amount_brl IS NULL AND complete=false
 FROM lts_projection_private_v412.known_card_periods_v412('00000000-0000-4000-8000-000000000001') WHERE series_key='card_c6';
INSERT INTO public.qa_adapter_checks
SELECT 'documentary paid cycle remains protected',paid AND closed
 FROM lts_projection_private_v412.known_card_periods_v412('00000000-0000-4000-8000-000000000001') WHERE series_key='card_itau';
INSERT INTO public.qa_adapter_checks
SELECT 'private adapters expose no public auth execute',bool_and(NOT p.prosecdef
 AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE')
 AND has_function_privilege('service_role',p.oid,'EXECUTE'))
 FROM pg_proc p WHERE p.pronamespace='lts_projection_private_v412'::regnamespace;

SELECT count(*) AS checks,bool_and(pass) AS pass FROM public.qa_adapter_checks;
