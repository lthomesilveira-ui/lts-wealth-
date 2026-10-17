CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb; official record; matched boolean; cycle_state jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 d as(select reported_invoice_total,due_date,source_as_of from public.lts_card_document_supplement_v234 where user_id=u and family=p_family and reference_month=date_trunc('month',p_month)::date order by source_as_of desc,created_at desc limit 1),
 t as(select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d)),'due_date',coalesce((select posting_date from b limit 1),(select due_date from d),(select min(due_date) from r)),
 'difference',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d))-(select amount from t),
 'basis',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'bank_document_composition' else null end,
 'source_note',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'Composição do banco complementada pelas parcelas comprovadas na fatura parcial.' else null end,
 'items',coalesce((select jsonb_agg(to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(u) m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
 'financial_effect','none') into result;
 if (result->>'item_count')::int=0 or abs(coalesce((result->>'difference')::numeric,0))>=0.005 then
  select w into alternative from jsonb_array_elements(public.lts_card_workbook_cycles_v226(u)||public.lts_card_document_cycles_v226(u))w
  where w->>'family'=p_family and (w->>'reference_month')::date=date_trunc('month',p_month)::date
  and (result->>'invoice_amount' is null or (w->>'amount')::numeric=(result->>'invoice_amount')::numeric)
  and (result->>'invoice_amount' is null or abs((w->>'difference')::numeric)<abs((result->>'difference')::numeric))
  order by abs((w->>'difference')::numeric),case when w->>'source'='document_reconciled' then 0 else 1 end limit 1;
  if alternative is not null then
   result:=result||alternative||jsonb_build_object('version','card-detail-v226','invoice_amount',(alternative->>'amount')::numeric,
    'due_date',coalesce(result->>'due_date',alternative->>'due_date'),'amount',(alternative->>'detail_total')::numeric,
    'alternative_items',result->'items','alternative_note','Itens também recebidos do banco para esta mesma fatura. São outra fonte de consulta, não despesas adicionais; não somar novamente.',
    'source_note',case when alternative->>'source'='document_reconciled' then 'Composição do documento importado, conferida com o total desta fatura.'
     else 'Composição da planilha por categoria, valor e mês de referência. Estabelecimento e dia da compra não estão informados nessa fonte. A diferença, quando houver, permanece explícita.' end);
  end if;
 end if;
 result:=result||jsonb_build_object(
  'unclassified',(select count(*) from jsonb_array_elements(result->'items')x where x->>'category_basis'='unresolved'),
  'categories',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'category' category,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'category')q),
  'instruments',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'last4' last4,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'last4')q)
 );

 SELECT ci.amount,ci.due_date,sd.id source_document_id,sd.sha256,sd.storage_path,sd.metadata,
  coalesce((sd.metadata->>'closing_date')::date,(ci.metadata->>'bank_statement_closing_date')::date) closing_date
 INTO official
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 WHERE ci.user_id=u AND public.lts_card_family_v226(ci.card_name,sd.institution)=p_family
  AND ci.reference_month=date_trunc('month',p_month)::date AND ci.status='closed'
  AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
 ORDER BY ci.created_at DESC LIMIT 1;
 IF FOUND THEN
  SELECT count(*)=(official.metadata->>'nonpayment_detail_lines')::int
   AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(official.metadata->'existing_source_items') e
    WHERE NOT coalesce((e->>'is_payment')::boolean,false)
     AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(result->'items') i
      WHERE i->>'source_id'=e->>'source_id'
       AND (i->>'amount')::numeric=(e->>'amount')::numeric
       AND i->>'last4' IS NOT DISTINCT FROM e->>'last4'
       AND i->>'purchase_date' IS NOT DISTINCT FROM e->>'purchase_date'
       AND i->>'installment_number' IS NOT DISTINCT FROM e->>'installment_number'
       AND i->>'total_installments' IS NOT DISTINCT FROM e->>'total_installments'))
  INTO matched FROM jsonb_array_elements(result->'items');
  result:=result||jsonb_build_object(
   'invoice_amount',official.amount,'due_date',official.due_date,
   'difference',official.amount-(result->>'amount')::numeric,
   'basis','bank_document_composition',
   'source_note',CASE WHEN matched AND official.amount=(result->>'amount')::numeric
    THEN 'Fatura oficial fechada em '||to_char(official.closing_date,'DD/MM/YYYY')||'; itens conferidos com o documento e diferença zero.'
    ELSE 'Fatura oficial recebida; a correspondência dos itens ou a diferença requer revisão.' END,
   'document_items_matched',matched,
   'invoice_document',jsonb_build_object('source_document_id',official.source_document_id,
    'file_ref',coalesce(official.metadata->>'library_file_id',official.storage_path),
    'sha256',official.sha256,'pages',official.metadata->'pages',
    'closing_date',official.closing_date,'document_date',official.metadata->'document_date'),
   'financial_effect','none');
 END IF;

 IF p_family='c6' AND date_trunc('month',p_month)::date>=date_trunc('month',current_date)::date THEN
  SELECT ca INTO cycle_state FROM jsonb_array_elements(public.lts_card_cycles_v226(u)->'cards') ca WHERE ca->>'family'='c6' LIMIT 1;
  IF cycle_state->>'complete'='false' THEN
   result:=result||jsonb_build_object('complete',false,'amount',NULL,'detail_total',NULL,'difference',NULL,
    'invoice_composition_complete',false,'detail_complete',false,'categories','[]'::jsonb,'instruments','[]'::jsonb,
    'unresolved_items',cycle_state->'unresolved_items','ambiguous_document_candidates',cycle_state->'ambiguous_document_candidates',
    'source_note','Evidências ainda não conciliadas. Não somar possíveis correspondências duplicadas como despesas.');
  END IF;
 END IF;

 -- Local v2 prototype: an unbound opaque pin leaves resolution inactive.
 DECLARE q26_p record; q26_r jsonb; q26_o jsonb; q26_items jsonb;
  q26_before numeric; q26_after numeric; q26_n bigint;
 BEGIN
  WITH q26_scoped AS MATERIALIZED (
 SELECT e.*,e.metadata->'contract' AS c,e.metadata->'state' AS st
 FROM public.lts_reconciliation_evidence e
 WHERE e.user_id=u AND (e.evidence_type='owner_confirmed_card_observation_pair_v1'
  OR e.id='55555555-5555-4555-8555-555555555555'::uuid OR e.source_ref='owner_confirmed_card_observation_pair_v1:55555555-5555-4555-8555-555555555555'
  OR e.metadata#>>'{contract,operation_id}'='55555555-5555-4555-8555-555555555555')
), q26_shapes AS MATERIALIZED (
 SELECT x.*,coalesce(((jsonb_typeof(x.metadata)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.metadata)='object' THEN x.metadata ELSE '{}'::jsonb END) AS z(k))=3 AND x.metadata ?& ARRAY['contract','immutable_fingerprint','state']::text[])
 AND jsonb_typeof(x.metadata->'immutable_fingerprint')='string'
 AND x.metadata->>'immutable_fingerprint' ~ '^[0-9a-f]{64}$'
 AND ((jsonb_typeof(x.c)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.c)='object' THEN x.c ELSE '{}'::jsonb END) AS z(k))=24 AND x.c ?& ARRAY['amount','card_last4','competence_month','currency','evidence_id','family','identity_basis','installment_number','institution_code','invoice_anchor_id','invoice_anchor_identity','operation_id','owner_id','prior_card_identity','prior_expense_identity','prior_id','prior_identity','provider_account_ref','representative_card_identity','representative_expense_identity','representative_id','representative_identity','total_installments','version']::text[]) AND
   (jsonb_typeof((x.c->'version'))='number' AND ((x.c->'version'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof((x.c->'operation_id'))='string' AND
   jsonb_typeof((x.c->'evidence_id'))='string' AND
   jsonb_typeof((x.c->'owner_id'))='string' AND
   jsonb_typeof((x.c->'representative_id'))='string' AND
   jsonb_typeof((x.c->'prior_id'))='string' AND
   jsonb_typeof((x.c->'invoice_anchor_id'))='string' AND
   jsonb_typeof((x.c->'competence_month'))='string' AND
   jsonb_typeof((x.c->'amount'))='number' AND
   jsonb_typeof((x.c->'currency'))='string' AND
   jsonb_typeof((x.c->'family'))='string' AND
   jsonb_typeof((x.c->'institution_code'))='string' AND
   jsonb_typeof((x.c->'provider_account_ref'))='string' AND
   jsonb_typeof((x.c->'card_last4'))='string' AND
   (jsonb_typeof((x.c->'installment_number'))='number' AND ((x.c->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((x.c->'total_installments'))='number' AND ((x.c->'total_installments'))::text ~ '^-?[0-9]+$') AND
   ((jsonb_typeof((x.c->'representative_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_identity'))='object' THEN (x.c->'representative_identity') ELSE '{}'::jsonb END) AS z(k))=13 AND (x.c->'representative_identity') ?& ARRAY['currency','id','institution_code','normalized_payload','posting_date','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','signed_amount','user_id']::text[]) AND
   jsonb_typeof(((x.c->'representative_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'signed_amount'))='number' AND
   jsonb_typeof(((x.c->'representative_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'representative_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'representative_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'representative_identity')->'raw_payload'))='object' THEN ((x.c->'representative_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=8 AND ((x.c->'representative_identity')->'raw_payload') ?& ARRAY['accountId','amount','creditCardMetadata','currencyCode','date','id','status','type']::text[]) AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'type'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'accountId'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'currencyCode'))='string' AND
   ((jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata'))='object' THEN (((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata') ELSE '{}'::jsonb END) AS z(k))=7 AND (((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata') ?& ARRAY['billId','billPostDate','cardNumber','installmentNumber','purchaseDate','totalInstallments','transactionDateTime']::text[]) AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'billId'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'cardNumber'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'billPostDate'))='string' AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'purchaseDate'))='string' AND
   (jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))='number' AND (((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))='number' AND (((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((((x.c->'representative_identity')->'raw_payload')->'creditCardMetadata')->'transactionDateTime'))='string')) AND
   ((jsonb_typeof(((x.c->'representative_identity')->'normalized_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'representative_identity')->'normalized_payload'))='object' THEN ((x.c->'representative_identity')->'normalized_payload') ELSE '{}'::jsonb END) AS z(k))=14 AND ((x.c->'representative_identity')->'normalized_payload') ?& ARRAY['account_last4','account_type','amount','bill_id','currency','date','installment_number','last4','layer','provider_account_id','provider_civil_date','provider_id','status','total_installments']::text[]) AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'last4'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'layer'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'bill_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'currency'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'account_type'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'account_last4'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_account_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_id'))='string' AND
   jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'provider_civil_date'))='string' AND
   (jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'installment_number'))='number' AND ((((x.c->'representative_identity')->'normalized_payload')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((((x.c->'representative_identity')->'normalized_payload')->'total_installments'))='number' AND ((((x.c->'representative_identity')->'normalized_payload')->'total_installments'))::text ~ '^-?[0-9]+$'))) AND
   ((jsonb_typeof((x.c->'prior_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_identity'))='object' THEN (x.c->'prior_identity') ELSE '{}'::jsonb END) AS z(k))=13 AND (x.c->'prior_identity') ?& ARRAY['currency','id','institution_code','normalized_payload','posting_date','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','signed_amount','user_id']::text[]) AND
   jsonb_typeof(((x.c->'prior_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'signed_amount'))='number' AND
   jsonb_typeof(((x.c->'prior_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'prior_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'prior_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'prior_identity')->'raw_payload'))='object' THEN ((x.c->'prior_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=8 AND ((x.c->'prior_identity')->'raw_payload') ?& ARRAY['accountId','amount','creditCardMetadata','currencyCode','date','id','status','type']::text[]) AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'type'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'accountId'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'currencyCode'))='string' AND
   ((jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata'))='object' THEN (((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata') ELSE '{}'::jsonb END) AS z(k))=7 AND (((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata') ?& ARRAY['billId','billPostDate','cardNumber','installmentNumber','purchaseDate','totalInstallments','transactionDateTime']::text[]) AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'billId'))='null' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'cardNumber'))='string' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'billPostDate'))='null' AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'purchaseDate'))='string' AND
   (jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))='number' AND (((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'installmentNumber'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))='number' AND (((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'totalInstallments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((((x.c->'prior_identity')->'raw_payload')->'creditCardMetadata')->'transactionDateTime'))='null')) AND
   ((jsonb_typeof(((x.c->'prior_identity')->'normalized_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'prior_identity')->'normalized_payload'))='object' THEN ((x.c->'prior_identity')->'normalized_payload') ELSE '{}'::jsonb END) AS z(k))=14 AND ((x.c->'prior_identity')->'normalized_payload') ?& ARRAY['account_last4','account_type','amount','bill_id','currency','date','installment_number','last4','layer','provider_account_id','provider_civil_date','provider_id','status','total_installments']::text[]) AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'date'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'last4'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'layer'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'amount'))='number' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'status'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'bill_id'))='null' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'currency'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'account_type'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'account_last4'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_account_id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_id'))='string' AND
   jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'provider_civil_date'))='string' AND
   (jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'installment_number'))='number' AND ((((x.c->'prior_identity')->'normalized_payload')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof((((x.c->'prior_identity')->'normalized_payload')->'total_installments'))='number' AND ((((x.c->'prior_identity')->'normalized_payload')->'total_installments'))::text ~ '^-?[0-9]+$'))) AND
   ((jsonb_typeof((x.c->'invoice_anchor_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'invoice_anchor_identity'))='object' THEN (x.c->'invoice_anchor_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'invoice_anchor_identity') ?& ARRAY['currency','id','institution_code','provider','provider_account_ref','provider_deleted_at','provider_record_id','raw_payload','resource_type','user_id']::text[]) AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'user_id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'currency'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'resource_type'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'institution_code'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_record_id'))='string' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_deleted_at'))='null' AND
   jsonb_typeof(((x.c->'invoice_anchor_identity')->'provider_account_ref'))='string' AND
   ((jsonb_typeof(((x.c->'invoice_anchor_identity')->'raw_payload'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(((x.c->'invoice_anchor_identity')->'raw_payload'))='object' THEN ((x.c->'invoice_anchor_identity')->'raw_payload') ELSE '{}'::jsonb END) AS z(k))=2 AND ((x.c->'invoice_anchor_identity')->'raw_payload') ?& ARRAY['id','totalAmountCurrencyCode']::text[]) AND
   jsonb_typeof((((x.c->'invoice_anchor_identity')->'raw_payload')->'id'))='string' AND
   jsonb_typeof((((x.c->'invoice_anchor_identity')->'raw_payload')->'totalAmountCurrencyCode'))='string')) AND
   ((jsonb_typeof((x.c->'representative_expense_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_expense_identity'))='object' THEN (x.c->'representative_expense_identity') ELSE '{}'::jsonb END) AS z(k))=7 AND (x.c->'representative_expense_identity') ?& ARRAY['amount','competence_month','event_date','purchase_date','source_ref','source_table','transaction_date']::text[]) AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'source_table'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'source_ref'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'event_date'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'transaction_date'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'competence_month'))='string' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'representative_expense_identity')->'purchase_date'))='string') AND
   ((jsonb_typeof((x.c->'prior_expense_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_expense_identity'))='object' THEN (x.c->'prior_expense_identity') ELSE '{}'::jsonb END) AS z(k))=7 AND (x.c->'prior_expense_identity') ?& ARRAY['amount','competence_month','event_date','purchase_date','source_ref','source_table','transaction_date']::text[]) AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'source_table'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'source_ref'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'event_date'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'transaction_date'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'competence_month'))='string' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'prior_expense_identity')->'purchase_date'))='string') AND
   ((jsonb_typeof((x.c->'representative_card_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'representative_card_identity'))='object' THEN (x.c->'representative_card_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'representative_card_identity') ?& ARRAY['amount','installment_number','is_payment','last4','posting_date','provider_status','purchase_date','reference_month','source_id','total_installments']::text[]) AND
   jsonb_typeof(((x.c->'representative_card_identity')->'source_id'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'provider_status'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'reference_month'))='string' AND
   (jsonb_typeof(((x.c->'representative_card_identity')->'installment_number'))='number' AND (((x.c->'representative_card_identity')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((x.c->'representative_card_identity')->'total_installments'))='number' AND (((x.c->'representative_card_identity')->'total_installments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((x.c->'representative_card_identity')->'last4'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'purchase_date'))='string' AND
   jsonb_typeof(((x.c->'representative_card_identity')->'is_payment'))='boolean') AND
   ((jsonb_typeof((x.c->'prior_card_identity'))='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof((x.c->'prior_card_identity'))='object' THEN (x.c->'prior_card_identity') ELSE '{}'::jsonb END) AS z(k))=10 AND (x.c->'prior_card_identity') ?& ARRAY['amount','installment_number','is_payment','last4','posting_date','provider_status','purchase_date','reference_month','source_id','total_installments']::text[]) AND
   jsonb_typeof(((x.c->'prior_card_identity')->'source_id'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'provider_status'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'amount'))='number' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'reference_month'))='string' AND
   (jsonb_typeof(((x.c->'prior_card_identity')->'installment_number'))='number' AND (((x.c->'prior_card_identity')->'installment_number'))::text ~ '^-?[0-9]+$') AND
   (jsonb_typeof(((x.c->'prior_card_identity')->'total_installments'))='number' AND (((x.c->'prior_card_identity')->'total_installments'))::text ~ '^-?[0-9]+$') AND
   jsonb_typeof(((x.c->'prior_card_identity')->'last4'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'posting_date'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'purchase_date'))='string' AND
   jsonb_typeof(((x.c->'prior_card_identity')->'is_payment'))='boolean') AND
   jsonb_typeof((x.c->'identity_basis'))='string')
 AND x.evidence_type='owner_confirmed_card_observation_pair_v1' AND x.status='documented'
 AND x.c->'version'='2'::jsonb AND (jsonb_typeof(x.st)='object' AND (SELECT count(*) FROM jsonb_object_keys(CASE WHEN jsonb_typeof(x.st)='object' THEN x.st ELSE '{}'::jsonb END) z(k))=3 AND x.st ?& ARRAY['active','revocation_operation_id','revoked_at']::text[]
 AND jsonb_typeof(x.st->'active')='boolean'
 AND ((x.st->'active'='true'::jsonb AND x.st->'revoked_at'='null'::jsonb AND x.st->'revocation_operation_id'='null'::jsonb)
 OR (x.st->'active'='false'::jsonb AND jsonb_typeof(x.st->'revoked_at')='string' AND length(x.st->>'revoked_at')>0
 AND jsonb_typeof(x.st->'revocation_operation_id')='string' AND x.st->>'revocation_operation_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')))),false) AS shape_ok
 FROM q26_scoped x
), q26_selected AS MATERIALIZED (
 SELECT x.* FROM q26_shapes x
 WHERE x.id='55555555-5555-4555-8555-555555555555'::uuid AND x.shape_ok
 AND (SELECT count(*) FROM q26_scoped y WHERE y.id=x.id)=1
 AND x.c->>'operation_id'='55555555-5555-4555-8555-555555555555' AND x.c->'evidence_id'=to_jsonb(x.id)
 AND x.c->'owner_id'=to_jsonb(x.user_id) AND x.st->'active'='true'::jsonb
 AND x.c->>'representative_id'<>x.c->>'prior_id'
 AND x.c->>'invoice_anchor_id' NOT IN(x.c->>'representative_id',x.c->>'prior_id')
 AND x.metadata->>'immutable_fingerprint'='UNBOUND_CANONICAL_SHA256_REQUIRES_PG17_REVIEW'
 AND pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to((jsonb_build_object('schema','q26-evidence-immutable-v2','evidence',jsonb_build_object('id',x.id,'user_id',x.user_id,'evidence_date',x.evidence_date,'account',x.account,'amount',x.amount,'description',x.description,'evidence_type',x.evidence_type,'source_ref',x.source_ref,'status',x.status),'contract',x.c))::text,'UTF8')),'hex')='UNBOUND_CANONICAL_SHA256_REQUIRES_PG17_REVIEW'
 AND NOT EXISTS(SELECT 1 FROM q26_shapes y WHERE y.id<>x.id AND (
   NOT y.shape_ok OR y.c->>'operation_id'=x.c->>'operation_id'
   OR (y.st->'active'='true'::jsonb AND (
    (y.c->>'representative_id'=x.c->>'representative_id' AND y.c->>'prior_id'=x.c->>'prior_id')
    OR (y.c->>'representative_id'=x.c->>'prior_id' AND y.c->>'prior_id'=x.c->>'representative_id')))))
), q26_pair AS MATERIALIZED (
 SELECT x.c,x.id AS evidence_id FROM q26_selected x
 JOIN public.lts_open_finance_staging r ON r.user_id=x.user_id AND r.id::text=x.c->>'representative_id'
 JOIN public.lts_open_finance_staging o ON o.user_id=x.user_id AND o.id::text=x.c->>'prior_id'
 JOIN public.lts_open_finance_staging b ON b.user_id=x.user_id AND b.id::text=x.c->>'invoice_anchor_id'
 WHERE (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'representative_id')=1
 AND (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'prior_id')=1
 AND (SELECT count(*) FROM public.lts_open_finance_staging z WHERE z.user_id=x.user_id AND z.id::text=x.c->>'invoice_anchor_id')=1
 AND ((SELECT jsonb_object_agg(k,to_jsonb(r)->k) FROM unnest(ARRAY['id','user_id','provider','currency','posting_date','resource_type','signed_amount','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(r.raw_payload)->k) FROM unnest(ARRAY['id','date','type','amount','status','accountId','currencyCode']::text[]) z(k))||jsonb_build_object('creditCardMetadata',(SELECT jsonb_object_agg(k,(r.raw_payload->'creditCardMetadata')->k) FROM unnest(ARRAY['billId','cardNumber','billPostDate','purchaseDate','installmentNumber','totalInstallments','transactionDateTime']::text[]) z(k))),'normalized_payload',(SELECT jsonb_object_agg(k,(r.normalized_payload)->k) FROM unnest(ARRAY['date','last4','layer','amount','status','bill_id','currency','account_type','account_last4','provider_account_id','provider_id','provider_civil_date','installment_number','total_installments']::text[]) z(k))))=x.c->'representative_identity'
 AND ((SELECT jsonb_object_agg(k,to_jsonb(o)->k) FROM unnest(ARRAY['id','user_id','provider','currency','posting_date','resource_type','signed_amount','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(o.raw_payload)->k) FROM unnest(ARRAY['id','date','type','amount','status','accountId','currencyCode']::text[]) z(k))||jsonb_build_object('creditCardMetadata',(SELECT jsonb_object_agg(k,(o.raw_payload->'creditCardMetadata')->k) FROM unnest(ARRAY['billId','cardNumber','billPostDate','purchaseDate','installmentNumber','totalInstallments','transactionDateTime']::text[]) z(k))),'normalized_payload',(SELECT jsonb_object_agg(k,(o.normalized_payload)->k) FROM unnest(ARRAY['date','last4','layer','amount','status','bill_id','currency','account_type','account_last4','provider_account_id','provider_id','provider_civil_date','installment_number','total_installments']::text[]) z(k))))=x.c->'prior_identity'
 AND ((SELECT jsonb_object_agg(k,to_jsonb(b)->k) FROM unnest(ARRAY['id','user_id','provider','currency','resource_type','institution_code','provider_record_id','provider_deleted_at','provider_account_ref']::text[]) z(k))||jsonb_build_object('raw_payload',(SELECT jsonb_object_agg(k,(b.raw_payload)->k) FROM unnest(ARRAY['id','totalAmountCurrencyCode']::text[]) z(k))))=x.c->'invoice_anchor_identity'
 AND r.provider_deleted_at IS NULL AND o.provider_deleted_at IS NULL AND b.provider_deleted_at IS NULL
 AND r.normalized_payload->>'status'='POSTED' AND o.normalized_payload->>'status'='PENDING'
 AND r.raw_payload#>>'{creditCardMetadata,billId}'=b.raw_payload->>'id'
 AND o.raw_payload#>>'{creditCardMetadata,billId}' IS NULL
 AND x.c->'amount'=to_jsonb(abs(r.signed_amount)) AND x.c->'amount'=to_jsonb(abs(o.signed_amount))
 AND x.c->'currency'=to_jsonb(r.currency) AND x.c->'currency'=to_jsonb(o.currency)
 AND x.c->'currency'=to_jsonb(b.currency)
)
  SELECT c,evidence_id INTO q26_p FROM q26_pair p
  WHERE p.c->>'family'=p_family AND p.c->'competence_month'=to_jsonb(date_trunc('month',p_month)::date);
  IF FOUND AND jsonb_typeof(result->'items')='array'
   AND (NOT (result ? 'document_items_matched') OR result->'document_items_matched' IN('null'::jsonb,'false'::jsonb)) THEN
   -- The result is already scoped to this cycle. Count all source-ID occurrences,
   -- including malformed/nonmatching amounts or months, before matching identity.
   IF (SELECT count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(result->'items')='array' THEN result->'items' ELSE '[]'::jsonb END) x WHERE x->>'source_id'=q26_p.c->>'representative_id')=1
   AND (SELECT count(*) FROM jsonb_array_elements(CASE WHEN jsonb_typeof(result->'items')='array' THEN result->'items' ELSE '[]'::jsonb END) x WHERE x->>'source_id'=q26_p.c->>'prior_id')=1
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(result->'items')='array' THEN result->'items' ELSE '[]'::jsonb END) x WHERE jsonb_typeof(x) IS DISTINCT FROM 'object' OR jsonb_typeof(x->'amount') IS DISTINCT FROM 'number') THEN
    SELECT x INTO q26_r FROM jsonb_array_elements(result->'items') x WHERE x->>'source_id'=q26_p.c->>'representative_id';
    SELECT x INTO q26_o FROM jsonb_array_elements(result->'items') x WHERE x->>'source_id'=q26_p.c->>'prior_id';
    IF q26_r @> q26_p.c->'representative_card_identity' AND q26_o @> q26_p.c->'prior_card_identity' THEN
     SELECT count(*),sum(CASE WHEN jsonb_typeof(x->'amount')='number' THEN (x->>'amount')::numeric END) INTO q26_n,q26_before FROM jsonb_array_elements(result->'items') x;
     IF result->'item_count'=to_jsonb(q26_n) AND result->'amount'=to_jsonb(q26_before)
      AND (NOT (result ? 'detail_total') OR result->'detail_total'=to_jsonb(q26_before))
      AND (NOT (result ? 'invoice_amount') OR result->'invoice_amount'='null'::jsonb OR jsonb_typeof(result->'invoice_amount')='number') THEN
      SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]'::jsonb) INTO q26_items
      FROM jsonb_array_elements(result->'items') WITH ORDINALITY a(x,ord) WHERE x->>'source_id' IS DISTINCT FROM q26_p.c->>'prior_id';
      q26_after:=q26_before-(CASE WHEN jsonb_typeof(q26_o->'amount')='number' THEN (q26_o->>'amount')::numeric END);
      result:=result||jsonb_build_object('items',q26_items,'amount',q26_after,'item_count',q26_n-1,
       'difference',CASE WHEN jsonb_typeof(result->'invoice_amount')='number' THEN (result->>'invoice_amount')::numeric-q26_after ELSE NULL END,
       'unclassified',(SELECT count(*) FROM jsonb_array_elements(q26_items) x WHERE x->>'category_basis'='unresolved'),
       'categories',(SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.category),'[]'::jsonb) FROM (SELECT x->>'category' category,count(*) n,sum((x->>'amount')::numeric) amount FROM jsonb_array_elements(q26_items) x GROUP BY 1) q),
       'instruments',(SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.last4),'[]'::jsonb) FROM (SELECT x->>'last4' last4,count(*) n,sum((x->>'amount')::numeric) amount FROM jsonb_array_elements(q26_items) x GROUP BY 1) q),
       'reconciliation_provenance',jsonb_build_object('operation_id',q26_p.c->>'operation_id','evidence_id',q26_p.evidence_id,
        'basis','owner_confirmed_nominal_composite_identity','representative_source_id',q26_p.c->>'representative_id','not_additional_expenses',true,'prior_observation',q26_o));
      IF result ? 'detail_total' THEN result:=jsonb_set(result,'{detail_total}',to_jsonb(q26_after)); END IF;
     END IF;
    END IF;
   END IF;
  END IF;
 END;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
end
$function$;
