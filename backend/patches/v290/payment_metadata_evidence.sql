-- V290: keep payment evidence valid across order/update metadata changes only.
DO $guard$ BEGIN
 IF md5(pg_get_functiondef('public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure))<>'b29e55e246c82376f676f175cbe65b44'
 OR md5(pg_get_functiondef('public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)'::regprocedure))<>'78b09cbf84d046f4bbc595753a3edd03'
 OR md5(pg_get_functiondef('public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure))<>'21af2733b8d46a42325233fa8e37257b'
 OR md5(pg_get_functiondef('public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure))<>'c8c716093de7f247be51f6ed6f34bd8f'
 THEN RAISE EXCEPTION 'V290 evidence reader lease changed'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.lts_card_settlement_evidence_valid_v273(p_user_id uuid, p_payment_id uuid, p_link jsonb, p_invoice jsonb, p_payment jsonb, p_items jsonb, p_as_of date, p_contract jsonb, p_coverage jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT coalesce(

 (p_link-'created_at')=p_contract->'link_contract' AND p_contract->>'active'='true' AND p_contract->>'user_id'=p_user_id::text AND p_contract->>'payment_id'=p_payment_id::text
 AND p_contract->>'invoice_id'=p_link->>'invoice_source_id'
 AND (p_contract->>'amount')::numeric=(p_link->>'expected_amount')::numeric
 AND CASE WHEN p_contract->>'item_evidence_policy'='raw_except_order_updatedAt_v290' THEN
 (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','signed_amount',(i->>'signed_amount')::numeric,
  'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}',
  'operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id')
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)
 =(SELECT jsonb_agg(m-'raw_hash' ORDER BY m->>'id') FROM jsonb_array_elements(p_contract->'manifest')m)
 AND (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','sha256',
  encode(sha256(convert_to(((i->'raw_payload')-'order'-'updatedAt')::text,'UTF8')),'hex')) ORDER BY i->>'id')
  FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)
 =p_contract->'item_canonical_manifest'
 ELSE (SELECT jsonb_agg(jsonb_build_object('id',i->>'id','raw_hash',i->>'raw_hash','signed_amount',(i->>'signed_amount')::numeric,'status',i#>>'{normalized_payload,status}','raw_status',i#>>'{raw_payload,status}','operation_type',i#>>'{raw_payload,operationType}') ORDER BY i->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i)=p_contract->'manifest' END
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)i WHERE i#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED' OR i#>>'{raw_payload,status}' IS DISTINCT FROM 'POSTED')
 AND jsonb_typeof(p_coverage)='array'
 AND (SELECT jsonb_agg(jsonb_build_object('id',e->>'source_ref','amount',(e->>'amount')::numeric,'competence_month',e->>'competence_month','coverage_mode',e->>'coverage_mode') ORDER BY e->>'source_ref') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_coverage)='array' THEN p_coverage ELSE '[]'::jsonb END)e)
 = (SELECT jsonb_agg(jsonb_build_object('id',m->>'id','amount',-(m->>'signed_amount')::numeric,'competence_month',p_contract->>'competence_month','coverage_mode',p_contract->>'coverage_mode') ORDER BY m->>'id') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_contract->'consumption_manifest')='array' THEN p_contract->'consumption_manifest' ELSE '[]'::jsonb END)m)
 AND
 p_link->>'user_id'=p_user_id::text AND p_invoice->>'user_id'=p_user_id::text AND p_payment->>'user_id'=p_user_id::text
 AND p_link->>'active'='true'
 AND p_link->>'payment_source_id'=p_payment_id::text AND p_payment->>'id'=p_payment_id::text
 AND p_link->>'invoice_source_id'=p_invoice->>'id' AND p_link->>'invoice_source_id'<>p_link->>'payment_source_id'
 AND p_invoice->>'resource_type'='invoice' AND p_payment->>'resource_type'='transaction'
 AND p_invoice->>'provider_deleted_at' IS NULL AND p_payment->>'provider_deleted_at' IS NULL
 AND p_invoice->>'institution_code'=p_link->>'institution_code' AND p_payment->>'institution_code'=p_link->>'institution_code'
 AND split_part(p_invoice->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND split_part(p_payment->>'provider_record_id',':',1)=p_link->>'provider_item_id'
 AND p_invoice->>'provider_account_ref'=p_link->>'invoice_account_ref'
 AND p_payment->>'provider_account_ref'=p_link->>'payment_account_ref'
 AND p_invoice->>'currency'='BRL' AND p_payment->>'currency'='BRL'
 AND (p_link->>'expected_amount')::numeric>0
 AND (p_invoice->>'signed_amount')::numeric=(p_link->>'expected_amount')::numeric
 AND (p_payment->>'signed_amount')::numeric=-(p_link->>'expected_amount')::numeric
 AND p_invoice#>>'{normalized_payload,due_date}'=p_link->>'expected_due_date'
 AND p_invoice#>>'{normalized_payload,closing_date}'=p_link->>'expected_closing_date'
 AND p_payment->>'posting_date'=p_link->>'expected_payment_date'
 AND (p_link->>'expected_payment_date')::date>(p_link->>'expected_closing_date')::date
 AND (p_link->>'expected_payment_date')::date<=p_as_of
 AND p_payment#>>'{normalized_payload,status}'='POSTED' AND p_payment#>>'{raw_payload,status}'='POSTED'
 AND p_payment#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND (CASE WHEN p_contract->>'invoice_evidence_policy'='raw_except_updatedAt_v1' THEN
   jsonb_typeof(p_invoice->'raw_payload')='object'
   AND jsonb_typeof(p_contract->'invoice_canonical_payload')='object'
   AND jsonb_typeof(p_invoice#>'{raw_payload,updatedAt}')='string'
   AND p_invoice#>>'{raw_payload,updatedAt}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$'
   AND ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload'
 ELSE p_contract->>'invoice_evidence_policy' IS NULL
   AND p_invoice->>'raw_hash'=p_contract->>'invoice_current_hash' END) AND p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments'
 AND jsonb_array_length(p_contract->'settlement_manifest')=1
 AND (SELECT sum((pay->>'amount')::numeric) FROM jsonb_array_elements(p_contract->'issuer_payments')pay WHERE pay->>'valueType'='FULL_PAYMENT' AND pay->>'paymentMode'='DEBIT_ACCOUNT' AND pay->>'currencyCode'='BRL')=(p_link->>'expected_amount')::numeric AND p_payment->>'raw_hash'=p_link->>'payment_raw_hash'
 AND jsonb_typeof(p_link->'documentary_sources')='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_link->'documentary_sources')='array' THEN p_link->'documentary_sources' ELSE '[]'::jsonb END)>=2
 AND nullif(p_invoice#>>'{normalized_payload,provider_id}','') IS NOT NULL
 AND jsonb_typeof(p_items)='array' AND jsonb_array_length(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END)>0
 AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i WHERE NOT coalesce(
   i->>'user_id'=p_user_id::text AND i->>'resource_type'='card_transaction' AND i->>'provider_deleted_at' IS NULL
   AND i->>'institution_code'=p_link->>'institution_code' AND i->>'currency'='BRL'
   AND i->>'provider_account_ref'=p_link->>'invoice_account_ref'
   AND i#>>'{raw_payload,creditCardMetadata,billId}'=p_invoice#>>'{normalized_payload,provider_id}'
   AND i->>'signed_amount' IS NOT NULL,false))
 AND (SELECT count(DISTINCT i->>'id')=count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)
 AND (SELECT sum(-(i->>'signed_amount')::numeric) FILTER(WHERE i#>>'{raw_payload,operationType}' IS DISTINCT FROM 'PAGAMENTO_FATURA') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_items)='array' THEN p_items ELSE '[]'::jsonb END) i)=(p_link->>'expected_amount')::numeric
,false)
$function$;
CREATE OR REPLACE FUNCTION public.lts_card_settlement_expense_excluded_v273(p_user_id uuid, p_payment_id uuid, p_coverage jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE c jsonb; l jsonb; b jsonb; t jsonb; items jsonb;
BEGIN
 c:=public.lts_card_settlement_contract_v273(p_user_id,p_payment_id);
 -- Covered reader definitions are leased to prevent silent recursion/coverage changes.

 -- An unrelated debit never opens any link, item or expense reader.
 IF c IS NULL OR c->>'active' IS DISTINCT FROM 'true' THEN RETURN false; END IF;
 IF md5(pg_get_functiondef('public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure)) IS DISTINCT FROM '21af2733b8d46a42325233fa8e37257b'
 OR md5(pg_get_functiondef('public.lts_expense_effective_rows_pre_v268(uuid,date,date)'::regprocedure)) IS DISTINCT FROM 'c8c716093de7f247be51f6ed6f34bd8f' THEN RETURN false; END IF;
 SELECT to_jsonb(link),to_jsonb(inv),to_jsonb(pay) INTO l,b,t
 FROM public.lts_card_documentary_payment_link_v272 link
 JOIN public.lts_open_finance_staging inv ON inv.user_id=link.user_id AND inv.id=link.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=link.user_id AND pay.id=link.payment_source_id
 WHERE link.user_id=p_user_id AND link.payment_source_id=p_payment_id AND link.invoice_source_id=(c->>'invoice_id')::uuid AND link.active;
 IF l IS NULL THEN RETURN false; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) INTO items
 FROM public.lts_open_finance_staging i
 WHERE i.user_id=p_user_id AND i.resource_type='card_transaction' AND i.provider_deleted_at IS NULL
 AND i.provider_account_ref=b->>'provider_account_ref' AND i.institution_code=l->>'institution_code'
 AND i.raw_payload#>>'{creditCardMetadata,billId}'=b#>>'{normalized_payload,provider_id}';
 RETURN public.lts_card_settlement_evidence_valid_v273(p_user_id,p_payment_id,l,b,t,items,current_date,c,p_coverage);
END
$function$;

-- Enrol only a previously reviewed settlement whose changed raw payload is
-- available in the observation journal and differs solely in order/updatedAt.
DO $enrol$
DECLARE c record; items jsonb; stable_manifest jsonb; changed jsonb; valid boolean; coverage jsonb; l jsonb; b jsonb; p jsonb;
BEGIN
 FOR c IN SELECT * FROM public.lts_card_settlement_expense_contract_v273 WHERE active LOOP
  SELECT to_jsonb(link),to_jsonb(inv),to_jsonb(pay) INTO l,b,p
  FROM public.lts_card_documentary_payment_link_v272 link
  JOIN public.lts_open_finance_staging inv ON inv.user_id=link.user_id AND inv.id=link.invoice_source_id
  JOIN public.lts_open_finance_staging pay ON pay.user_id=link.user_id AND pay.id=link.payment_source_id
  WHERE link.user_id=c.user_id AND link.payment_source_id=c.payment_source_id AND link.active;
  IF l IS NULL OR public.lts_card_payment_refresh_annotation_v273(c.user_id,l,b,p,c.payload,current_date) IS NULL
  THEN RAISE EXCEPTION 'Reviewed invoice payment no longer matches'; END IF;
  SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) INTO items FROM public.lts_open_finance_staging s
  WHERE s.user_id=c.user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
   AND s.provider_account_ref=b->>'provider_account_ref' AND s.institution_code=l->>'institution_code'
   AND s.raw_payload#>>'{creditCardMetadata,billId}'=b#>>'{normalized_payload,provider_id}';
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(items)i
   JOIN jsonb_array_elements(c.payload->'manifest')m ON m->>'id'=i->>'id'
   LEFT JOIN LATERAL(SELECT o.raw_payload FROM public.lts_open_finance_observation o
    WHERE o.user_id=c.user_id AND o.raw_hash=m->>'raw_hash' ORDER BY o.observed_at DESC LIMIT 1)old ON true
   WHERE i->>'raw_hash' IS DISTINCT FROM m->>'raw_hash'
   AND (old.raw_payload IS NULL OR ((i->'raw_payload')-'order'-'updatedAt') IS DISTINCT FROM (old.raw_payload-'order'-'updatedAt')))
  THEN RAISE EXCEPTION 'Substantive purchase evidence changed; review required'; END IF;
  SELECT jsonb_agg(jsonb_build_object('id',i->>'id','sha256',
   encode(sha256(convert_to(((i->'raw_payload')-'order'-'updatedAt')::text,'UTF8')),'hex')) ORDER BY i->>'id')
  INTO stable_manifest FROM jsonb_array_elements(items)i;
  SELECT coalesce(jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,
   'competence_month',e.competence_month,'coverage_mode',e.coverage_mode)),'[]') INTO coverage
  FROM public.lts_expense_effective_rows_v176(c.user_id,(c.payload->>'competence_month')::date,
   ((c.payload->>'competence_month')::date+interval '1 month -1 day')::date)e
  WHERE e.source_table='lts_open_finance_staging' AND e.source_ref IN
   (SELECT m->>'id' FROM jsonb_array_elements(c.payload->'consumption_manifest')m);
  changed:=c.payload||jsonb_build_object('item_evidence_policy','raw_except_order_updatedAt_v290',
   'item_canonical_manifest',stable_manifest,'metadata_reviewed_at',clock_timestamp(),
   'metadata_review_basis','all_prior_payloads_available_and_only_order_updatedAt_changed');
  valid:=public.lts_card_settlement_evidence_valid_v273(c.user_id,c.payment_source_id,l,b,p,items,current_date,changed,coverage);
  IF valid IS DISTINCT FROM true THEN RAISE EXCEPTION 'Exact payment and consumption coverage did not validate'; END IF;
  UPDATE public.lts_card_settlement_expense_contract_v273 SET payload=changed
   WHERE user_id=c.user_id AND payment_source_id=c.payment_source_id AND payload=c.payload;
 END LOOP;
END $enrol$;

CREATE OR REPLACE FUNCTION public.lts_card_invoice_settled_v290(p_user_id uuid,p_name text,p_month date,p_due date,p_amount numeric)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $f$
SELECT EXISTS(
 SELECT 1 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.card_invoices ci ON ci.user_id=l.user_id AND ci.card_name=p_name
 AND ci.reference_month=p_month AND ci.due_date=p_due AND ci.amount=p_amount
 WHERE l.user_id=p_user_id AND l.active AND l.expected_due_date=p_due AND l.expected_amount=p_amount
 AND date_trunc('month',l.expected_due_date)::date=p_month
 AND public.lts_card_family_v226(ci.card_name,ci.card_name)=public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) IS NOT NULL
)
$f$;
REVOKE ALL ON FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) TO service_role;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure))<>'3b14ea1c3311c3566e186d3cbc3fec94' THEN RAISE EXCEPTION 'Pending projection reader changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_pending_projections_v233(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH anchors AS MATERIALIZED (
 SELECT DISTINCT ON (institution) institution bank,(metadata->>'balance_as_of')::date dt
 FROM public.accounts WHERE user_id=p_user_id AND is_active
 AND metadata->>'evidence_sha256' IS NOT NULL AND institution IN ('Itaú','Bradesco','C6')
 AND (metadata->>'balance_as_of')::date<current_date
 ORDER BY institution,(metadata->>'balance_as_of')::date DESC
), candidates AS MATERIALIZED (
 SELECT x||CASE WHEN q.unposted THEN jsonb_build_object('unposted_past_projection',true) ELSE '{}'::jsonb END x
 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date)) x
 JOIN anchors a ON a.bank=x->>'account' AND (x->>'event_date')::date>a.dt
 CROSS JOIN LATERAL(SELECT x->>'source'='current_event' AND (x->>'event_date')::date<current_date
 AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=p_user_id AND fe.is_projection AND NOT fe.is_suppressed
 AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
 AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric) unposted) q
 WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
 AND (x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') OR q.unposted)
), posted AS MATERIALIZED (
 SELECT s.*,CASE institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' ELSE 'C6' END bank
 FROM public.lts_bank_posted_rows_v231(p_user_id) s
 WHERE resource_type='transaction' AND institution_code IN ('341','237','336') AND currency='BRL'
 AND provider_deleted_at IS NULL AND normalized_payload->>'status'='POSTED'
 AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
), positions AS MATERIALIZED (
 SELECT institution_code,normalized_payload->>'provider_account_id' account_id,(normalized_payload->>'as_of')::timestamptz observed_at
 FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND resource_type='balance'
 AND currency='BRL' AND provider_deleted_at IS NULL AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
), payroll AS MATERIALIZED (SELECT projection_ref FROM public.lts_payroll_bank_matches_v231(p_user_id)),
settled_fgts AS MATERIALIZED (
 SELECT receipt->'projection_refs' projection_refs
 FROM posted s JOIN positions p ON p.institution_code=s.institution_code
 AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 CROSS JOIN LATERAL(SELECT public.lts_bank_fgts_combined_receipt_v261(p_user_id,s.id) receipt) proof
 WHERE s.institution_code='341' AND s.signed_amount>0 AND receipt IS NOT NULL
)
SELECT coalesce(jsonb_agg(public.lts_flow_classification_decision_v1(p_user_id,c.x) ORDER BY c.x->>'event_date',c.x->>'source_ref'),'[]'::jsonb)
FROM candidates c WHERE NOT EXISTS(SELECT 1 FROM payroll p WHERE p.projection_ref=c.x->>'source_ref')
AND NOT EXISTS(SELECT 1 FROM settled_fgts s WHERE s.projection_refs ? (c.x->>'source_ref'))
AND NOT EXISTS(
 SELECT 1 FROM public.lts_v229_documentary_match dm
 JOIN posted s ON s.id=dm.staging_id AND s.signed_amount=dm.signed_amount
 JOIN positions p ON p.institution_code=s.institution_code
   AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 WHERE dm.user_id=p_user_id AND dm.source_ref=c.x->>'source_ref'
 AND dm.bank=c.x->>'account' AND dm.signed_amount=(c.x->>'signed_amount')::numeric
 AND dm.canonical_date IN((c.x->>'event_date')::date,(c.x->>'original_date')::date)
 AND dm.evidence->>'basis'='owner_confirmed_exact_obligation'
 AND dm.evidence->>'raw_hash'=s.raw_hash
 AND s.posting_date=(dm.evidence->>'actual_posting_date')::date
)
AND NOT EXISTS (
 SELECT 1 FROM posted s JOIN positions p ON p.institution_code=s.institution_code
 AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 WHERE s.bank=c.x->>'account' AND s.posting_date=(c.x->>'event_date')::date
 AND s.signed_amount=(c.x->>'signed_amount')::numeric
 AND (lower(trim(s.description_raw))=lower(trim(c.x->>'description')) OR s.id::text=c.x->>'open_finance_id'
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
 WHERE z->>'ref' IN (c.x->>'source_ref',(c.x->>'source')||':'||(c.x->>'source_ref'))))
)

AND NOT (c.x->>'source'='card_invoice' AND public.lts_card_invoice_settled_v290(
 p_user_id,split_part(c.x->>'source_ref','|',1),date_trunc('month',(c.x->>'event_date')::date)::date,
 (c.x->>'event_date')::date,abs((c.x->>'signed_amount')::numeric)))
$function$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)'::regprocedure))<>'77f2a525b311b880ebb936e6b1f59b1c' THEN RAISE EXCEPTION 'Flow source reader changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
with payroll_matches as materialized (select projection_ref from public.lts_payroll_bank_matches_v231(p_user_id)), card_amounts as materialized (select * from public.lts_card_invoice_amounts_v230(p_user_id)), scenario_off as (
  select lower(k) as root from public.legacy_namespace l,lateral jsonb_each_text(l.valor_bruto::jsonb) x(k,v)
  where l.usuario_id=p_user_id and l.chave='lts_cen_off_v2' and lower(v)='true'
), explicit_reconc as (
  select distinct nullif(dados->>'previsaoIdx','')::int idx from public.reconciliacao
  where usuario_id=p_user_id and dados->>'status' in ('reconciliada','ciclo-realizado') and nullif(dados->>'previsaoIdx','') is not null
), coopharma_nonbank as (
  select exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.id='suppress_coopharma_nonbank_future') onflag
), ops as (
  select dados,lower(trim(coalesce(dados->>'conta',''))) conta,lower(trim(coalesce(dados->>'desc',''))) descr,
         nullif(dados->>'dia','')::date dia,coalesce((dados->>'ts')::bigint,0) ts
  from public.projecao_op where usuario_id=p_user_id and coalesce(dados->>'status','ativa')='ativa' and nullif(dados->>'revertidaEm','') is null
), base0 as (
  select eb.idx,(eb.dados->>'dia')::date original_date,eb.dados->>'conta' account,eb.dados->>'desc' description,
         coalesce(a.source_signed_amount,(eb.dados->>'valor')::numeric) amount_abs,eb.dados->>'efeito' efeito,
         lower(trim(coalesce(eb.dados->>'conta',''))) conta_norm,lower(trim(coalesce(eb.dados->>'desc',''))) desc_norm
  from public.evento_base eb
  left join public.lts_card_history_source_audit_v235 a on a.user_id=eb.usuario_id
    and a.source_table='evento_base' and a.source_ref=eb.idx::text
    and a.event_date=(eb.dados->>'dia')::date and a.source_description=eb.dados->>'desc'
    and a.ledger_amount=round((eb.dados->>'valor')::numeric,2) and a.source_signed_amount<0
    and eb.dados->>'efeito'='saida'
  where eb.usuario_id=p_user_id and (eb.dados->>'dia')::date<=p_to and extract(year from (eb.dados->>'dia')::date)>=2018
    and not exists(select 1 from scenario_off s where s.root=lower(trim(coalesce(eb.dados->>'desc',''))))
    and not (eb.dados->>'desc'='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank) and (eb.dados->>'dia')::date>=date '2026-07-08')
    and not exists(select 1 from explicit_reconc r where r.idx=eb.idx)
    and not exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.source_table='evento_base'
      and (r.description_exact is null or r.description_exact=eb.dados->>'desc') and (r.account_exact is null or r.account_exact=eb.dados->>'conta')
      and (r.date_from is null or (eb.dados->>'dia')::date>=r.date_from) and (r.date_to is null or (eb.dados->>'dia')::date<=r.date_to))
), base_with_ops as (
  select b.*,
    exists(select 1 from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='cancelamento') cancelled,
    coalesce((select (o.dados#>>'{depois,valor}')::numeric from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='valor' order by o.ts desc limit 1),b.amount_abs) adjusted_amount,
    coalesce((select (o.dados#>>'{depois,dia}')::date from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='data' order by o.ts desc limit 1),b.original_date) adjusted_date,
    (select o.dados->'partes' from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='divisao' order by o.ts desc limit 1) split_parts
  from base0 b
), transformed_base as (
  select b.idx,coalesce(disp.para,b.adjusted_date) event_date,b.account,b.description,
         case when b.efeito='entrada' then b.adjusted_amount else -b.adjusted_amount end signed_amount,b.original_date,(disp.para is not null) displaced
  from base_with_ops b
  left join lateral (
    select (d.dados->>'para')::date para from public.deslocamento d
    where d.usuario_id=p_user_id and coalesce(d.dados->>'status','ativo')='ativo'
      and lower(trim(coalesce(d.dados->>'conta','')))=b.conta_norm and lower(trim(coalesce(d.dados->>'identidade','')))=b.desc_norm
      and (d.dados->>'de')::date=b.original_date order by coalesce((d.dados->>'ts')::bigint,0) desc limit 1
  ) disp on true where not b.cancelled and b.split_parts is null
  union all
  select b.idx,coalesce(disp.para,(p->>'dia')::date),b.account,b.description,
         case when b.efeito='entrada' then (p->>'valor')::numeric else -(p->>'valor')::numeric end,b.original_date,(disp.para is not null)
  from base_with_ops b cross join lateral jsonb_array_elements(b.split_parts) p
  left join lateral (
    select (d.dados->>'para')::date para from public.deslocamento d
    where d.usuario_id=p_user_id and coalesce(d.dados->>'status','ativo')='ativo'
      and lower(trim(coalesce(d.dados->>'conta','')))=b.conta_norm and lower(trim(coalesce(d.dados->>'identidade','')))=b.desc_norm
      and (d.dados->>'de')::date=b.original_date order by coalesce((d.dados->>'ts')::bigint,0) desc limit 1
  ) disp on true where not b.cancelled and b.split_parts is not null
), economic_withholding as (
  select (eb.dados->>'dia')::date event_date,'Folha'::text account,eb.dados->>'desc' description,-abs((eb.dados->>'valor')::numeric) signed_amount,
         'economic_withholding'::text src,'contrato:ct_ms9rzp71rpi9|evento_base:'||eb.idx::text src_ref,'validated_contract'::text conf,'nonbank'::text acct_assign,
         eb.idx legacy_idx,(eb.dados->>'dia')::date orig_date,false is_displaced
  from public.evento_base eb where eb.usuario_id=p_user_id and eb.dados->>'desc'='Pagamento Novo Coopharma'
    and (eb.dados->>'dia')::date between p_from and p_to and (select onflag from coopharma_nonbank) and (eb.dados->>'dia')::date>=date '2026-07-08'
), normalized as (
  select fe.event_date,coalesce(a.institution,'Não atribuída'),coalesce(fe.description_normalized,fe.description_raw,'(sem descrição)'),fe.amount,
         'current_event'::text,coalesce(fe.legacy_id,fe.id::text),
         case when fe.source='validated_contract_qa' then 'validated' when fe.status='scheduled' then 'documented_scheduled' when fe.status='expected' then 'documented_expected' else 'current_evidence' end,
         case when fe.account_id is null then 'pending' else 'assigned' end,fe.legacy_index,fe.event_date,false
  from public.financial_events fe left join public.accounts a on a.id=fe.account_id
  where fe.user_id=p_user_id and fe.event_date between p_from and p_to and coalesce(fe.is_suppressed,false)=false
    and coalesce(fe.is_internal_transfer,false)=false and coalesce(fe.nature,'')<>'transfer' and fe.status in ('scheduled','expected','active','needs_reconciliation')
    and not exists(select 1 from scenario_off s where s.root=lower(trim(coalesce(fe.description_normalized,fe.description_raw,''))))
    and not (coalesce(fe.description_normalized,fe.description_raw,'')='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank))
), cards as (
  select ci.due_date,coalesce((select r.account_exact from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.replacement_source='card_invoices' and r.date_from<=ci.due_date and r.date_to>=ci.due_date order by r.updated_at desc limit 1),public.lts_card_invoice_account_v181(ci.card_name),'Não atribuída'),
         'Fatura '||ci.card_name,-abs(ci.amount),'card_invoice'::text,ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM'),
         case when ci.status='closed' then 'documented_closed' when ci.status='open' then 'documented_open' else 'documented_projected_snapshot' end,
         case when public.lts_card_invoice_account_v181(ci.card_name) is not null or exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.replacement_source='card_invoices' and r.date_from<=ci.due_date and r.date_to>=ci.due_date) then 'assigned' else 'pending' end,
         null::int,ci.due_date,false
  from card_amounts ci where ci.user_id=p_user_id and ci.due_date between p_from and p_to AND NOT public.lts_card_invoice_settled_v290(p_user_id,ci.card_name,ci.reference_month,ci.due_date,ci.amount) and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
), allrows as (
  select t.event_date,t.account,t.description,t.signed_amount,'legacy_fix86'::text src,'evento_base:'||t.idx::text src_ref,case when exists(select 1 from public.lts_card_history_source_audit_v235 a where a.user_id=p_user_id
 and a.source_table='evento_base' and a.source_ref=t.idx::text and a.event_date=t.original_date
 and a.source_signed_amount<0 and -a.source_signed_amount=round(t.signed_amount,2))
 then 'historical_workbook_signed_adjustment' else 'legacy_projection_adjusted' end::text conf,
         'assigned'::text acct_assign,t.idx legacy_idx,t.original_date orig_date,t.displaced is_displaced
  from transformed_base t
  where t.event_date between p_from and p_to
    and not exists (
      select 1
      from card_amounts ci
      where ci.user_id=p_user_id
        and ci.reference_month=date_trunc('month',t.event_date)::date
        and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
        and public.lts_card_family_key_v181(ci.card_name,null) is not null
        and public.lts_card_family_key_v181(ci.card_name,null)=public.lts_card_family_key_v181(t.description,t.account)
    )
  union all select * from economic_withholding union all select * from normalized union all select * from cards
)
select a.event_date,a.account,a.description,a.signed_amount,a.src,a.src_ref,a.conf,a.acct_assign,a.legacy_idx,a.orig_date,a.is_displaced
from allrows a where not (a.src='legacy_fix86' and exists(select 1 from payroll_matches m where m.projection_ref=a.src_ref)) order by a.event_date,a.src,a.description;
$function$;

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;

