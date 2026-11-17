BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure; d text; attrs jsonb; u uuid;
BEGIN
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V460_WORKER_ACTIVE';END IF;
 FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V460_WORKER_LOCK_BUSY';END IF;END LOOP;
 IF to_regnamespace('lts_receipt_private_v460') IS NULL THEN
  EXECUTE 'CREATE SCHEMA lts_receipt_private_v460';
 ELSIF to_regprocedure('lts_receipt_private_v460.utility_receipts(uuid,date)') IS NULL THEN RAISE EXCEPTION 'V460_UNRECOGNIZED_SCHEMA';END IF;
 IF EXISTS(SELECT 1 FROM pg_class WHERE relnamespace='lts_receipt_private_v460'::regnamespace)
 OR EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='lts_receipt_private_v460'::regnamespace AND oid<>coalesce(to_regprocedure('lts_receipt_private_v460.utility_receipts(uuid,date)'),0))
 THEN RAISE EXCEPTION 'V460_UNRECOGNIZED_SCHEMA';END IF;
 target:=to_regprocedure('lts_receipt_private_v460.utility_receipts(uuid,date)');
 IF target IS NOT NULL THEN
  IF md5(pg_get_functiondef(target))<>'854d3166b48e309d9216ca83423fe2ee' THEN RAISE EXCEPTION 'V460_HELPER_DRIFT';END IF;
 END IF;
 EXECUTE $helper$CREATE OR REPLACE FUNCTION lts_receipt_private_v460.utility_receipts(p_user_id uuid, p_as_of date)
 RETURNS TABLE(staging_id uuid, projection_ref text, projection_date date, description text, series_key text, direction text, actual_date date, actual_amount numeric, basis text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH candidates AS MATERIALIZED (
 SELECT s.id staging_id,'evento_base:'||e.idx::text projection_ref,(CASE WHEN pg_catalog.pg_input_is_valid(e.dados->>'dia','date') THEN (e.dados->>'dia')::date END) projection_date,
 e.dados->>'desc' description,public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,
 'expense'::text direction,s.posting_date actual_date,s.signed_amount actual_amount,
 'proved_retired_utility_forecast'::text basis,
 count(*) OVER(PARTITION BY s.id) source_claims,
 count(*) OVER(PARTITION BY e.idx) forecast_claims
 FROM public.projecao_op o
 JOIN public.evento_base e ON e.usuario_id=o.usuario_id
  AND 'evento_base:'||e.idx::text=o.dados#>>'{reconciliation,source_ref}'
 JOIN public.lts_open_finance_staging s ON s.user_id=o.usuario_id
  AND s.id::text=o.dados#>>'{reconciliation,staging_id}'
 JOIN public.lts_v178_review_decision r ON r.user_id=s.user_id
  AND r.source_table='lts_open_finance_staging' AND r.source_ref=s.id::text
 WHERE o.usuario_id=p_user_id AND o.dados->>'tipo'='cancelamento'
 AND o.dados->>'escopo'='ocorrencia' AND o.dados->>'status'='ativa'
 AND o.dados->'revertidaEm'='null'::jsonb AND o.dados#>'{depois,cancelada}'='true'::jsonb
 AND o.dados#>>'{reconciliation,basis}'='posted_unique_utility_receiver_plus_prior_owner_classification'
 AND o.dados#>'{reconciliation,original_forecast}'=e.dados
 AND o.dados->>'dia'=e.dados->>'dia' AND o.dados->>'desde'=e.dados->>'dia'
 AND o.dados->>'desc'=e.dados->>'desc' AND o.dados->>'conta'=e.dados->>'conta'
 AND e.dados->>'efeito'='saida' AND e.dados->>'conta' IN('Itau','Itaú')
 AND e.dados->>'desc' ~* '^Enel([[:space:]-]|$)'
 AND e.dados->>'dia' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 AND pg_catalog.pg_input_is_valid(e.dados->>'dia','date')
 AND CASE WHEN e.dados->>'valor' ~ '^[0-9]+([.][0-9]+)?$' THEN (e.dados->>'valor')::numeric>0 ELSE false END
 AND s.resource_type='transaction' AND s.currency='BRL' AND s.institution_code='341'
 AND s.provider_deleted_at IS NULL AND s.signed_amount<0 AND s.occurred_at<=current_timestamp
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.raw_hash ~ '^[0-9a-f]{64}$' AND s.raw_hash=o.dados#>>'{reconciliation,raw_hash}'
 AND s.posting_date::text=o.dados#>>'{reconciliation,actual_bank_posting_date}'
 AND CASE WHEN pg_catalog.pg_input_is_valid(o.dados#>>'{reconciliation,actual_signed_amount}','numeric')
 THEN (o.dados#>>'{reconciliation,actual_signed_amount}')::numeric=s.signed_amount ELSE false END
 AND s.description_raw ~* 'ELETROPAULO[[:space:]]+[0-9]{4,8}'
 AND s.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
 AND date_trunc('month',s.posting_date)=date_trunc('month',(CASE WHEN pg_catalog.pg_input_is_valid(e.dados->>'dia','date') THEN (e.dados->>'dia')::date END))
 AND r.category_label='Energia' AND r.property_code IS NOT NULL
 AND r.category_label=o.dados#>>'{reconciliation,category}'
 AND r.property_code=o.dados#>>'{reconciliation,property_code}'
 AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CNPJ'
 AND nullif(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','') IS NOT NULL
 AND EXISTS(
  SELECT 1 FROM public.lts_open_finance_staging prior
  JOIN public.lts_v178_review_decision owner_decision ON owner_decision.user_id=prior.user_id
   AND owner_decision.source_table='lts_open_finance_staging' AND owner_decision.source_ref=prior.id::text
  WHERE prior.user_id=p_user_id AND prior.id<>s.id AND prior.institution_code=s.institution_code
  AND prior.resource_type='transaction' AND prior.currency='BRL' AND prior.signed_amount<0
  AND prior.provider_deleted_at IS NULL AND prior.normalized_payload->>'status'='POSTED'
  AND prior.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND prior.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND prior.posting_date<date_trunc('month',s.posting_date)::date
  AND owner_decision.decision_basis='authenticated_user_v229'
  AND owner_decision.category_label=r.category_label AND owner_decision.property_code=r.property_code
  AND prior.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CNPJ'
  AND prior.raw_payload#>>'{paymentData,receiver,documentNumber,value}'=s.raw_payload#>>'{paymentData,receiver,documentNumber,value}'
  AND substring(prior.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
   =substring(s.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
 )
 AND EXISTS(
  SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.currency='BRL'
  AND b.provider_deleted_at IS NULL AND b.institution_code=s.institution_code
  AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND b.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND CASE WHEN pg_catalog.pg_input_is_valid(b.normalized_payload->>'as_of','timestamp with time zone')
   THEN (b.normalized_payload->>'as_of')::timestamptz END>=s.occurred_at
 )
 AND (SELECT count(*) FROM public.lts_open_finance_staging other
  WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code=s.institution_code
  AND other.provider_deleted_at IS NULL AND other.currency='BRL' AND other.signed_amount<0
  AND other.normalized_payload->>'status'='POSTED' AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND other.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND date_trunc('month',other.posting_date)=date_trunc('month',s.posting_date)
  AND substring(other.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
   =substring(s.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})'))=1
)
SELECT staging_id,projection_ref,projection_date,description,series_key,direction,actual_date,actual_amount,basis
FROM candidates WHERE source_claims=1 AND forecast_claims=1;
$function$$helper$;
 REVOKE ALL ON SCHEMA lts_receipt_private_v460 FROM PUBLIC,anon,authenticated;
 REVOKE ALL ON FUNCTION lts_receipt_private_v460.utility_receipts(uuid,date) FROM PUBLIC,anon,authenticated;
 IF md5(pg_get_functiondef('lts_receipt_private_v460.utility_receipts(uuid,date)'::regprocedure))<>'854d3166b48e309d9216ca83423fe2ee'
 OR (SELECT prosecdef OR provolatile<>'s' FROM pg_proc WHERE oid='lts_receipt_private_v460.utility_receipts(uuid,date)'::regprocedure)
 OR has_schema_privilege('anon','lts_receipt_private_v460','USAGE') OR has_schema_privilege('authenticated','lts_receipt_private_v460','USAGE')
 OR has_function_privilege('anon','lts_receipt_private_v460.utility_receipts(uuid,date)','EXECUTE') OR has_function_privilege('authenticated','lts_receipt_private_v460.utility_receipts(uuid,date)','EXECUTE')
 THEN RAISE EXCEPTION 'V460_PRIVATE_HELPER_CONTRACT';END IF;
 target:='public.lts_recurring_receipt_identities_v303(uuid,date)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='fbb5db9c22d8b9e8de6137ea3ebd37d1' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_recurring_receipt_identities_v303(p_user_id uuid, p_as_of date)
 RETURNS TABLE(staging_id uuid, projection_ref text, projection_date date, description text, series_key text, direction text, actual_date date, actual_amount numeric, basis text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH payroll AS (
 SELECT m.staging_id,m.projection_ref,m.projection_date,e.dados->>'desc' description,
 public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,'income'::text direction,
 s.posting_date actual_date,s.signed_amount actual_amount,'proved_payroll_projection'::text basis
 FROM public.lts_payroll_bank_matches_v231(p_user_id)m
 JOIN public.evento_base e ON e.usuario_id=p_user_id AND m.projection_ref='evento_base:'||e.idx::text
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=m.staging_id
 WHERE e.dados->>'dia'=m.projection_date::text AND e.dados->>'efeito'='entrada'
 AND m.projection_amount=CASE WHEN e.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$' THEN abs((e.dados->>'valor')::numeric) END
 AND m.actual_amount=m.projection_amount AND m.actual_amount>0 AND s.signed_amount=m.actual_amount
 AND s.posting_date=m.actual_date AND m.projection_date<=p_as_of
 AND s.resource_type='transaction' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND m.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND s.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
 AND public.lts_forecast_series_key_v1(e.dados->>'desc') IN('salary','salary_advance')
), cards AS (
 SELECT pay.id staging_id,'evento_base:'||e.idx::text projection_ref,l.expected_due_date projection_date,
 e.dados->>'desc' description,public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,
 'expense'::text direction,pay.posting_date actual_date,pay.signed_amount actual_amount,
 'proved_legacy_card_settlement'::text basis
 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.evento_base e ON e.usuario_id=l.user_id AND e.dados->>'dia'=l.expected_due_date::text
  AND public.lts_v178_norm(e.dados->>'desc')='mastercard' AND public.lts_v178_norm(e.dados->>'conta')='itau'
  AND e.dados->>'efeito'='saida'
 WHERE l.user_id=p_user_id AND l.active AND inv.institution_code='341' AND pay.institution_code='341'
 AND public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)='itau_mastercard'
 AND pay.resource_type='transaction' AND pay.currency='BRL' AND pay.provider_deleted_at IS NULL AND pay.signed_amount<0
 AND pay.normalized_payload->>'status'='POSTED' AND pay.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND pay.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of AND l.expected_due_date<=p_as_of
 AND public.lts_legacy_mastercard_settled_v291(p_user_id,jsonb_build_object('source','legacy_fix86',
 'source_ref','evento_base:'||e.idx::text,'description',e.dados->>'desc','account','Itaú','event_date',e.dados->>'dia',
 'signed_amount',CASE WHEN e.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$' THEN -abs((e.dados->>'valor')::numeric) END,
 'internal_transfer',false))
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,p_as_of) IS NOT NULL
), aeternum AS MATERIALIZED (
 /* v375-reviewed-aeternum-receipt */
 SELECT(receipt->>'staging_id')::uuid,receipt->>'projection_ref',(receipt->>'projection_date')::date,
 receipt->>'description',receipt->>'series_key',receipt->>'direction',(receipt->>'actual_date')::date,
 (receipt->>'actual_amount')::numeric,receipt->>'basis'
 FROM public.evento_base e
 CROSS JOIN LATERAL(SELECT lts_receipt_private_v375.legacy_aeternum_receipt(p_user_id,jsonb_build_object(
  'source','legacy_fix86','source_ref','evento_base:'||e.idx::text,'description',e.dados->>'desc',
  'account','Bradesco','event_date',e.dados->>'dia','signed_amount',CASE WHEN e.dados->>'valor'~'^[0-9]+([.][0-9]+)?$'THEN-(e.dados->>'valor')::numeric END,
  'internal_transfer',false),p_as_of)receipt OFFSET 0)proof
 WHERE e.usuario_id=p_user_id AND public.lts_v178_norm(e.dados->>'desc')='visa aeternum'
 AND e.dados->>'dia'>=date_trunc('month',p_as_of)::date::text AND e.dados->>'dia'<=p_as_of::text
 AND receipt IS NOT NULL AND(receipt->>'actual_date')::date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
), utilities AS MATERIALIZED (SELECT * FROM lts_receipt_private_v460.utility_receipts(p_user_id,p_as_of)), candidates AS (SELECT * FROM payroll UNION ALL SELECT * FROM cards UNION ALL SELECT * FROM aeternum UNION ALL SELECT * FROM utilities), unambiguous AS (
 SELECT staging_id FROM candidates GROUP BY staging_id
 HAVING count(DISTINCT projection_ref)=1 AND count(DISTINCT series_key)=1
 AND count(DISTINCT direction)=1 AND count(DISTINCT actual_amount)=1
)
SELECT DISTINCT c.* FROM candidates c JOIN unambiguous u USING(staging_id);
$function$$definition$;
 ELSIF md5(d)<>'e9e929e7dfe951dc6f19dd032a2f91f0' THEN RAISE EXCEPTION 'V460_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'e9e929e7dfe951dc6f19dd032a2f91f0' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V460_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='lts_product_refresh_private_v415.review_profile_v450()'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='219dba6201aa21e8603b9959b7c7c32d' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_profile_v450()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ SELECT $manifest${
  "producers": [
    {
      "md5": "3900ca2edf2711a189defff21baff121",
      "signature": "public.lts_current_evidence_position_v1(uuid)"
    },
    {
      "md5": "206c6ae57f42d3872a5526b6074bb9f2",
      "signature": "public.lts_corrected_cashflow_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "b2a59acca5d7b3bda6c4d7623ae5576c",
      "signature": "public.lts_corrected_cashflow_fix86_v2(uuid,date,date)"
    },
    {
      "md5": "5107d8d47f89f04c44d77941b05900e2",
      "signature": "public.lts_canonical_description_fix86_v1(text)"
    },
    {
      "md5": "20d7ec098884b5a8ac06116781d8f3ac",
      "signature": "public.lts_corrected_cashflow_fix86_v3(uuid,date,date)"
    },
    {
      "md5": "bf16d2f5f23eac410cf1516674048d59",
      "signature": "public.lts_internal_transfer_legs_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "c994cbe994eb1a22d43a79793b0f14c9",
      "signature": "public.lts_corrected_cashflow_fix86_v4(uuid,date,date)"
    },
    {
      "md5": "e9e5f710fe7144af4117a4a11688890d",
      "signature": "public.lts_historical_effective_cash_v2(uuid,date,date)"
    },
    {
      "md5": "6676a65ce3e8e41b678e62f0b489251a",
      "signature": "public.lts_historical_effective_cash_v3(uuid,date,date)"
    },
    {
      "md5": "1219e04b97f74a5190639e3d3f7d9618",
      "signature": "public.lts_flow_current_effective_v1(uuid,date,date)"
    },
    {
      "md5": "1c6fd4b90d14f41339b91d2db104319b",
      "signature": "public.lts_confirmation_key_for_flow_ref_v1(uuid,text)"
    },
    {
      "md5": "b5d0f51f32e389f903e2b6e2785cf63f",
      "signature": "public.lts_historical_effective_cash_v4(uuid,date,date)"
    },
    {
      "md5": "5ba5df8823c2986f3d94cee05433abe9",
      "signature": "public.lts_corrected_cashflow_operational_v1(uuid,date,date)"
    },
    {
      "md5": "2fe93166917418b9155a52c3ca39db74",
      "signature": "public.lts_canonical_category_v1(uuid,text)"
    },
    {
      "md5": "a6f95cef0dc87e44756cd08a476339bc",
      "signature": "public.lts_payroll_withholding_effective_v1(uuid,date,date)"
    },
    {
      "md5": "9330a40ad6071900cda300452a1c213b",
      "signature": "public.lts_historical_effective_cash_v5(uuid,date,date)"
    },
    {
      "md5": "0b181ac93fc98827cdf834043f214df9",
      "signature": "public.lts_flow_past_operational_v2(uuid,date,date)"
    },
    {
      "md5": "7280cf73ab6e4dd3003ab7ec66f5c013",
      "signature": "public.lts_corrected_cashflow_fix86_v5(uuid,date,date)"
    },
    {
      "md5": "2d94c51243c430e1ddfdcc8b98783c72",
      "signature": "public.lts_expense_management_group_v3(text,text,text,text,text)"
    },
    {
      "md5": "1be62bc2e068051f98f14c5fa2c828c3",
      "signature": "public.lts_expense_management_subgroup_v2(text,text,text,text,text)"
    },
    {
      "md5": "21af2733b8d46a42325233fa8e37257b",
      "signature": "public.lts_expense_effective_rows_v176(uuid,date,date)"
    },
    {
      "md5": "8bd38f36cd64245bdf8a84464a298839",
      "signature": "public.lts_v178_norm(text)"
    },
    {
      "md5": "affd7eefd5f929701be548b3da275f64",
      "signature": "public.lts_card_family_key_v181(text,text)"
    },
    {
      "md5": "c35a0e6a6941157964a79eb5f5b31fcf",
      "signature": "public.lts_card_invoice_account_v181(text)"
    },
    {
      "md5": "6c2360ed89bd0ee12de2e662de1ffce2",
      "signature": "public.lts_open_finance_current_bank_position_v1(uuid)"
    },
    {
      "md5": "b9d8f8f0db01f7a9a2310398ec5776bc",
      "signature": "public.lts_current_evidence_position_v2(uuid)"
    },
    {
      "md5": "848c0d41a080916b4c0a6b74dcc17a82",
      "signature": "public.lts_card_family_v226(text,text)"
    },
    {
      "md5": "ef996716f66fc61e5e466ce1636d6713",
      "signature": "public.lts_card_merchant_key_v226(text)"
    },
    {
      "md5": "d98e3a726149666eddf069cef8ad7a4e",
      "signature": "public.lts_card_source_rows_v226(uuid)"
    },
    {
      "md5": "71d0beacbd4803f0e14bbc2885e7247e",
      "signature": "public.lts_card_cycles_v226(uuid)"
    },
    {
      "md5": "9baacf4fb28872f1c17c00b862cad01f",
      "signature": "public.lts_card_exact_recovery_v226(uuid,date,date)"
    },
    {
      "md5": "1183985090fd8773db59036cee9e7ec6",
      "signature": "public.lts_expense_effective_rows_v225_baseline(uuid,date,date)"
    },
    {
      "md5": "3026f1d05acf5bc8ec573c9bfbf25531",
      "signature": "public.lts_flow_operational_read_v229(uuid,date,date)"
    },
    {
      "md5": "aae8c78fc55fe52fa0ddab347480f37c",
      "signature": "public.lts_v229_new_bank_rows(uuid,date,date)"
    },
    {
      "md5": "6bf5e8d7c0dda985892c8209b7222337",
      "signature": "public.lts_expense_rows_v230_baseline(uuid,date,date)"
    },
    {
      "md5": "ac823d4947b9a4f9739c24533ead5bc2",
      "signature": "public.lts_v229_review_rows(uuid,date,date)"
    },
    {
      "md5": "a95cf3f7802c4d3bafd7bfb49551e042",
      "signature": "public.lts_bank_description_key_v229(text)"
    },
    {
      "md5": "5edc57b30e5d6b8a52d632efa08ec498",
      "signature": "public.lts_card_invoice_amounts_v230(uuid)"
    },
    {
      "md5": "512e6b2b7f396b1e67e99818869ec12a",
      "signature": "public.lts_bank_merchant_key_v231(text)"
    },
    {
      "md5": "1dbb589d3877c60420fdff81c384fb8c",
      "signature": "public.lts_bank_posted_rows_v231(uuid)"
    },
    {
      "md5": "c89adcb69252efa960cbb34df2a89768",
      "signature": "public.lts_bank_known_classification_v231(uuid,uuid)"
    },
    {
      "md5": "24140ece2345c630f3db5051a6e422e9",
      "signature": "public.lts_payroll_bank_matches_v231(uuid)"
    },
    {
      "md5": "3df237f6269a6a13bc3403b05276fcac",
      "signature": "public.lts_card_installment_key_v231(public.lts_open_finance_staging)"
    },
    {
      "md5": "bd41db5479a15491422cf6268db89b47",
      "signature": "public.lts_v229_expense_rows_pre_v238(uuid,date,date)"
    },
    {
      "md5": "3f1a2c6e73150f6874cbda3db88317f9",
      "signature": "public.lts_card_document_matches_v234(uuid)"
    },
    {
      "md5": "68a27f360b474f8ac0df91a7650fe924",
      "signature": "public.lts_card_document_rows_v234(uuid)"
    },
    {
      "md5": "4df73b4ad0cafadc367377e48c5ca251",
      "signature": "public.lts_operational_source_key_v238(uuid)"
    },
    {
      "md5": "c0a390f6b415cde4fc47225bed44ffdf",
      "signature": "public.lts_realized_bank_sources_v238(uuid)"
    },
    {
      "md5": "a2ab1bb252ba1c27cb0ad7fa62cbe5cd",
      "signature": "public.lts_v229_expense_rows(uuid,date,date)"
    },
    {
      "md5": "164c5a3d3705549fcdbf2a6e93d6b9ed",
      "signature": "public.lts_card_workbook_bank_rows_v1(uuid)"
    },
    {
      "md5": "891b9f6b72365cc6d142aa098f941ff1",
      "signature": "public.lts_card_bank_monthly_deltas_v1(uuid)"
    },
    {
      "md5": "0c9a66e16022bb799bb268295515d50c",
      "signature": "public.lts_open_finance_checking_positions_v1(uuid)"
    },
    {
      "md5": "4bc0f47babbba8bf30fced74161cf19a",
      "signature": "public.lts_flow_classification_decision_v1(uuid,jsonb)"
    },
    {
      "md5": "60015122f8b310f2b3f79538e851f2cf",
      "signature": "public.lts_forecast_series_key_v1(text)"
    },
    {
      "md5": "1f72d7ac2b27a5e111de3f1c7d41fb42",
      "signature": "public.lts_historical_effective_cash_pre_v246(uuid,date,date)"
    },
    {
      "md5": "e2950ce945db74cbf6acc68587dcb7d6",
      "signature": "public.lts_card_observed_expense_eligible_v1(jsonb,date,date)"
    },
    {
      "md5": "240849f813a9ac43b853d42440ef02b0",
      "signature": "public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)"
    },
    {
      "md5": "e3e63ef8481594d301f5b0560d6ae25b",
      "signature": "public.lts_c6_paid_identity_v237(uuid)"
    },
    {
      "md5": "38238af5e695c1d54d45e63f1579dd26",
      "signature": "public.lts_operational_source_key_pre_v242(uuid)"
    },
    {
      "md5": "0498aef77c7c7970de52c6712c0d6c30",
      "signature": "public.lts_historical_cash_engine_v243(uuid,date,date)"
    },
    {
      "md5": "5db62be42ab458431614f11172fb70bc",
      "signature": "public.lts_card_invoice_amounts_v230_engine_v243(uuid)"
    },
    {
      "md5": "65fbb2bf3db4cefcce6f70e7a89f9561",
      "signature": "public.lts_payroll_bank_matches_v231_engine_v243(uuid)"
    },
    {
      "md5": "6b8b11bef56c749826f713904fdea55c",
      "signature": "public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)"
    },
    {
      "md5": "3d06e4c309d8b0bc0466558f8f92e1a7",
      "signature": "public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)"
    },
    {
      "md5": "d5e085fe7dbc8f6a2ad562feb290c1fb",
      "signature": "public.lts_card_source_rows_pre_v262(uuid)"
    },
    {
      "md5": "363c2c63d3ee64df40173f8c3d7aab21",
      "signature": "public.lts_owner_confirmed_transfer_pairs_v263(uuid)"
    },
    {
      "md5": "0738e3c16dfe4fdea7b6a59d42d5535c",
      "signature": "public.lts_current_received_card_bills_v263(uuid)"
    },
    {
      "md5": "c8c716093de7f247be51f6ed6f34bd8f",
      "signature": "public.lts_expense_effective_rows_pre_v268(uuid,date,date)"
    },
    {
      "md5": "3869ff49b557837aecbc11b8528fca6a",
      "signature": "public.lts_c6_cycle_identity_v269(uuid)"
    },
    {
      "md5": "dd6e02daa77ff6fb09df0324e3e45692",
      "signature": "public.lts_card_document_candidates_v269(uuid)"
    },
    {
      "md5": "d0e199988d394dd3e875f8c059933fe7",
      "signature": "public.lts_c6_completeness_state_v269(uuid)"
    },
    {
      "md5": "cbfae2833915df136d8046fd9e18f81c",
      "signature": "public.lts_card_settlement_contract_v273(uuid,uuid)"
    },
    {
      "md5": "c7fe16708fd3a9a1a768c0cfa8ee9a8c",
      "signature": "public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)"
    },
    {
      "md5": "56a8a53a1290893ae4f94634ffb01867",
      "signature": "public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)"
    },
    {
      "md5": "45974b44368efcd4fa7080851a2125e1",
      "signature": "public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "29778e4a296e728ad9723a6e08e1c55b",
      "signature": "public.lts_bill_source_fields_v286(jsonb,jsonb,date)"
    },
    {
      "md5": "9f5b3bc99757b695e3c32022c90388fb",
      "signature": "public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)"
    },
    {
      "md5": "a8a083f160fb6e2937dc96e165b2fbd8",
      "signature": "public.lts_card_due_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "8cc4cb82649edc926c2842afb7522d06",
      "signature": "public.lts_card_projection_rows_v290(uuid)"
    },
    {
      "md5": "f5ff0aefd33935bb5eabf3fdc925fe74",
      "signature": "public.lts_card_settlement_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "0d845b5e55b0505af153d66adfcd6ea4",
      "signature": "public.lts_expense_rows_pre_categories_v290(uuid,date,date)"
    },
    {
      "md5": "6e7bf2157a330190a5003cd29247161d",
      "signature": "lts_income_private.category_v296(uuid,text,text)"
    },
    {
      "md5": "3c681814ed788e864f2e75511fa4ffd1",
      "signature": "public.lts_card_cycle_settlement_v301(jsonb,jsonb)"
    },
    {
      "md5": "ad76fd524058f3b4e75bc481a032c338",
      "signature": "public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "5f78416d190a1a7a375e3e0e11fe8445",
      "signature": "public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "33c9ee21e5e049a5be0266c67c719620",
      "signature": "public.lts_posted_own_transfer_out_v304(uuid)"
    },
    {
      "md5": "291dc64044041416759df58589a50b44",
      "signature": "public.lts_prepared_card_cycles_v307(uuid)"
    },
    {
      "md5": "655b63c0813b334710615843b9b9ddb4",
      "signature": "public.lts_aeternum_forecast_cycles_v311(uuid)"
    },
    {
      "md5": "dc900351b38a8f5a3bbf31955dc4c61a",
      "signature": "public.lts_card_forecast_overlay_v311(uuid,jsonb)"
    },
    {
      "md5": "866bfd2faad09d44a60f946b7b8c6c43",
      "signature": "public.lts_workbook_transfer_identity_v336(uuid)"
    },
    {
      "md5": "34b7114165a4e91be404399836782d83",
      "signature": "public.lts_workbook_transfer_identity_v338(uuid)"
    },
    {
      "md5": "092e901ed772fb34d2bda78bfdafcb10",
      "signature": "public.lts_c6_contract_clock_rows_v349(jsonb)"
    },
    {
      "md5": "b7ab98acb2b884c21b7355302a79cff5",
      "signature": "public.lts_card_item_is_invoice_payment_v351(jsonb)"
    },
    {
      "md5": "e38bfe13754a3a8b5696db120b1004d5",
      "signature": "public.lts_card_cycle_settlement_v351(jsonb,jsonb)"
    },
    {
      "md5": "0bcd78087d78d80dd2b00724318d6903",
      "signature": "public.lts_transfer_refresh_valid_v363(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "ad87d534451381da68a290d7ab67f38b",
      "signature": "public.lts_previously_proved_transfer_pairs_v363(uuid)"
    },
    {
      "md5": "031156449872239330aba72b614af71b",
      "signature": "public.lts_card_projection_date_v370(uuid,text,date,date,date)"
    },
    {
      "md5": "c79ae9493992a7826017fa3062f97060",
      "signature": "public.lts_card_transition_cash_date_v370(uuid,text,date)"
    },
    {
      "md5": "6a73e664c65611c7a1f51b9b54380b3d",
      "signature": "public.lts_card_transition_overlay_v370(uuid,jsonb)"
    },
    {
      "md5": "e7ed129c02e3212302a4759a4a950724",
      "signature": "public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)"
    },
    {
      "md5": "d1ba27f82c8ec6fcecbe0637969bb238",
      "signature": "public.lts_fgts_position_evidence_v386(uuid,date)"
    },
    {
      "md5": "58eebeb755504d01304bd801d569e036",
      "signature": "public.lts_card_due_estimate_overlay_v391(uuid,jsonb)"
    },
    {
      "md5": "556b9cdfff74827eea5819422c278546",
      "signature": "public.lts_cofrinho_composition_v399(uuid,date)"
    },
    {
      "md5": "eeeba973bfb0d4b067e004fd7ab5199a",
      "signature": "public.lts_cofrinho_documentary_composition_v402(uuid,date)"
    },
    {
      "md5": "b9849fe1221396d0a6c891463f43f7bb",
      "signature": "public.lts_cofrinho_provider_position_v402(uuid,date)"
    },
    {
      "md5": "cd55278c925c273fab0f32691b3a6d77",
      "signature": "lts_projection_private_v412.fixed_amount(jsonb,date)"
    },
    {
      "md5": "f42d27119ebc9c79d65df908a2e006fd",
      "signature": "lts_projection_private_v412.owner_policy(uuid)"
    },
    {
      "md5": "61d623e8d18f329f6bebccd4afeaf719",
      "signature": "lts_projection_private_v412.horizon_end(date)"
    },
    {
      "md5": "7bc0289413a6d546c5070414827023ad",
      "signature": "lts_projection_private_v412.review_window(jsonb,date)"
    },
    {
      "md5": "17c3b90c1df758e489d13378936391df",
      "signature": "lts_projection_private_v412.base_flow(uuid,date,date)"
    },
    {
      "md5": "d378c15fc35b8c8c6e10c5b928cfe96f",
      "signature": "lts_projection_private_v412.source_label(text)"
    },
    {
      "md5": "86f60fe0c33409204db6de7dc0d1bc7b",
      "signature": "lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)"
    },
    {
      "md5": "a0c466ed037263cc6e3419b06a26bcfe",
      "signature": "lts_projection_private_v412.calendar_templates_v412(uuid,jsonb)"
    },
    {
      "md5": "8241371be1fd9688da69459c0c5b3c3e",
      "signature": "lts_projection_private_v412.known_card_periods_v412(uuid)"
    },
    {
      "md5": "36e88d8f2482bd86bd24e3c129efb668",
      "signature": "lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "20cd10920678a7233965813167ec0706",
      "signature": "lts_projection_private_v412.reference_state(uuid)"
    },
    {
      "md5": "b5c214f5a8e1f54c7a82038bedbc03a1",
      "signature": "lts_projection_private_v412.build(uuid,date)"
    },
    {
      "md5": "5fc273e25705711595caa96fee9f691d",
      "signature": "lts_product_refresh_private_v415.card_source_key(uuid)"
    },
    {
      "md5": "e23ee4f8f05cfedac0ca3c68b04bbec8",
      "signature": "lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean)"
    },
    {
      "md5": "eb5ec59c4a5ba9090c8bf1645d6ab258",
      "signature": "lts_projection_private_v412.scope_history_v416(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "c14a4064624418b03cd0fc6dc9e7ce99",
      "signature": "lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date)"
    },
    {
      "md5": "7d6a29396f98680308840f19e25f7a0a",
      "signature": "lts_projection_private_v412.scope_slots_v416(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "82627286a1c3a73ee4d18f1dba54a866",
      "signature": "public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "9c0d1ac15cb98696ef8fc98aca9ef6b6",
      "signature": "lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)"
    },
    {
      "md5": "fcdc0852c1f0e8316ea961168b04b33d",
      "signature": "public.lts_confirmed_schedule_pairs_v431(uuid)"
    },
    {
      "md5": "ff09da81dbc2a7e7358cac2315fe9147",
      "signature": "lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)"
    },
    {
      "md5": "4755895d26b059d2cbf969b200d9ecb9",
      "signature": "lts_projection_private_v412.card_new_spend_provision(jsonb,date)"
    },
    {
      "md5": "75a1eb59a97d445da40c51a6d642aeae",
      "signature": "lts_projection_private_v412.verify_card_legacy_obligations(uuid,jsonb)"
    },
    {
      "md5": "d5f23851a4049a9c380b3d13991d0814",
      "signature": "lts_projection_private_v412.card_legacy_obligations_match(jsonb,jsonb)"
    },
    {
      "md5": "30a6a78744316806e0ca52a632c73e6b",
      "signature": "public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)"
    },
    {
      "md5": "01810b2f491005875361b564088edb53",
      "signature": "lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date)"
    },
    {
      "md5": "8829d7dff268811b63f7a3b19eaff092",
      "signature": "public.lts_expense_matched_bank_rows_v445(uuid,date,date)"
    },
    {
      "md5": "99f49c4f11e130d6cab4196173f41ec0",
      "signature": "public.lts_v246_invalidate_finance_cache()"
    },
    {
      "signature": "lts_product_refresh_private_v415.documented_own_out_v450(uuid)",
      "md5": "9b8208a7d073c1d68272875841215911"
    },
    {
      "signature": "lts_product_refresh_private_v415.reviewed_c6_mode_v450(jsonb,jsonb,jsonb)",
      "md5": "5fd0dd7b5989e3d59c33d06820568bab"
    },
    {
      "signature": "public.lts_recurring_receipt_identities_v303(uuid,date)",
      "md5": "e9e929e7dfe951dc6f19dd032a2f91f0"
    },
    {
      "signature": "lts_receipt_private_v460.utility_receipts(uuid,date)",
      "md5": "854d3166b48e309d9216ca83423fe2ee"
    }
  ],
  "tables": [
    {
      "kind": "r",
      "name": "audit_log",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_product_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_catalog",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_external_reference_fact",
      "epoch": false,
      "owner": null,
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_sync_run",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_expense_effective_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_resource_map",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_v229_documentary_match",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_workbook_identity_evidence_v232",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_formula_resolution_v237",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_documentary_payment_link_v272",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_settlement_expense_contract_v273",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_binding_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_rule_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_recurring_plan_v366",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_transition_v370",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_estimate_v391",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "queue",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_product_refresh_private_v415"
    },
    {
      "kind": "r",
      "name": "received_income_evidence_v443",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_projection_private_v412"
    }
  ],
  "epoch_tables": [
    {
      "signature": "public.accounts",
      "md5": "0cd95ba1233a645b7b6b89b899c91ee9"
    },
    {
      "signature": "public.financial_events",
      "md5": "cdd46c379c75ec1b13c0576d213d116c"
    },
    {
      "signature": "public.asset_positions",
      "md5": "784bbef4179e4c6201a0a57469fc2b9f"
    },
    {
      "signature": "public.card_invoices",
      "md5": "79141e85d01638ee3b3b5bcc85288ab0"
    },
    {
      "signature": "public.source_documents",
      "md5": "d2502a75b65d841b0078bdd23dc3f544"
    },
    {
      "signature": "public.app_settings",
      "md5": "8a272a34fee05cd774115f8b74bc891d"
    },
    {
      "signature": "public.legacy_namespace",
      "md5": "f1e3991f741b971ca5584408140f60b8"
    },
    {
      "signature": "public.evento_base",
      "md5": "67e711865d230fa0ebfeba0041da1d90"
    },
    {
      "signature": "public.historico_analitico",
      "md5": "a0743bb7ec6a95ea3fc069f531fa81f9"
    },
    {
      "signature": "public.evento_usuario",
      "md5": "d59d0ad57334f4dc2d4d28cb1858ff01"
    },
    {
      "signature": "public.reconciliacao",
      "md5": "931e76d391d7a2b142e983a1ef6c27a7"
    },
    {
      "signature": "public.deslocamento",
      "md5": "434b2d0111de5fb71ac0b34fd0fdb331"
    },
    {
      "signature": "public.projecao_op",
      "md5": "2898399189c102b2a555b92ee9fca339"
    },
    {
      "signature": "public.lts_projection_replacement_rule",
      "md5": "55abffad3dd07c3cf55f4ed7fc5b801e"
    },
    {
      "signature": "public.lts_semantic_rule",
      "md5": "81260f5c0c534b1aa65371f93040223b"
    },
    {
      "signature": "public.lts_manual_card_purchase",
      "md5": "4745ae14abd398447abd1d75094368fb"
    },
    {
      "signature": "public.lts_reconciliation_evidence",
      "md5": "29454b21cd3d71fae9c0e16967f7d876"
    },
    {
      "signature": "public.lts_document_card_purchase",
      "md5": "51f552d78c82e0a0ee24790ae1d293c4"
    },
    {
      "signature": "public.lts_fact_confirmation",
      "md5": "c252c1d875d3dfed8e6b5a299a539a09"
    },
    {
      "signature": "public.lts_flow_event_operation",
      "md5": "ced7e25c93af7437e65d0f450dae2c2f"
    },
    {
      "signature": "public.lts_commitment_documentary_schedule",
      "md5": "693ccd59d4f2c6ec1f9488a87541bef0"
    },
    {
      "signature": "public.lts_category_alias",
      "md5": "390fd09ae6c62e74adc764aff90404e6"
    },
    {
      "signature": "public.lts_semantic_amount_signature",
      "md5": "9158c8a6ddc3c3f60475ee2508e5d75c"
    },
    {
      "signature": "public.lts_card_history_recovered_purchase",
      "md5": "58596956f3c48ab508c925d2aab72466"
    },
    {
      "signature": "public.lts_open_finance_connection",
      "md5": "26b5c52a8f4be62ee376a6fe73888006"
    },
    {
      "signature": "public.lts_open_finance_staging",
      "md5": "3a4e2f69a3c7ae6d2564028a67121893"
    },
    {
      "signature": "public.lts_expense_documentary_amount_override",
      "md5": "5aea157c6ec11bee333ecb60340b98e1"
    },
    {
      "signature": "public.lts_card_historical_category_allocation",
      "md5": "17099f1184e352b7e39c9095d15ff88a"
    },
    {
      "signature": "public.lts_card_historical_validation_registry",
      "md5": "4c9b886570b29d69d91ae380336d5a28"
    },
    {
      "signature": "public.lts_liquidity_movement",
      "md5": "532e6df37a44350e864ff915bb958109"
    },
    {
      "signature": "public.lts_v175_workbook_monthly_category_source",
      "md5": "26bcfbde7b3616877262f5e5d4a09c98"
    },
    {
      "signature": "public.lts_v178_review_decision",
      "md5": "63cda13f1dcd530f551ab33fde4679f9"
    },
    {
      "signature": "public.lts_open_finance_observation",
      "md5": "10ab88c362d788e3023e10e025ed033a"
    },
    {
      "signature": "public.lts_validated_lock_registry",
      "md5": "522e3739fa5e349273c96eecfb990969"
    },
    {
      "signature": "public.lts_card_workbook_evidence_v226",
      "md5": "09977fb370184dcd69f03053c6825f01"
    },
    {
      "signature": "public.lts_card_document_supplement_v234",
      "md5": "5f25b9b2ab48bec94eeb07a7010d5fd0"
    },
    {
      "signature": "public.lts_card_history_source_audit_v235",
      "md5": "6e43df483c77c1b26d4777e6cbfb09ae"
    },
    {
      "signature": "public.lts_realized_bank_event_v238",
      "md5": "b9fdfeb875a350e9165fc66f4ff7a806"
    },
    {
      "signature": "public.lts_workbook_transfer_evidence_v336",
      "md5": "c9a73adb0694016e461716891c3a6279"
    },
    {
      "signature": "public.lts_workbook_transfer_reversal_v338",
      "md5": "3afb12f53e2d84a603838c6b293bbbcf"
    }
  ],
  "views": [
    {
      "md5": "30b883b57eac28644fafa04f96aec7ed",
      "signature": "public.lts_expense_realized"
    },
    {
      "md5": "5fb751309feb03a8b3ef84bf3816729c",
      "signature": "public.lts_card_purchase_detail"
    },
    {
      "md5": "950ad5a413e3cc3bf880714055858c89",
      "signature": "public.lts_workbook_nonspend_source_v343"
    }
  ]
}$manifest$::jsonb $function$$definition$;
 ELSIF md5(d)<>'307c43cfe2b9ecc89f60eb95b6c77c45' THEN RAISE EXCEPTION 'V460_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'307c43cfe2b9ecc89f60eb95b6c77c45' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V460_FUNCTION_CONTRACT_CHANGED';END IF;
END $patch$;
COMMIT;
