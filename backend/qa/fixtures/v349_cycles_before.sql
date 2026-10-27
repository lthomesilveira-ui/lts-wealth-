CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE result jsonb; c6_contract_uncertain boolean; c6_unresolved jsonb; c6_document_ambiguous jsonb;
BEGIN

with document_matches_v298 AS MATERIALIZED (
 SELECT * FROM public.lts_card_document_matches_v234(p_user_id)
), c6_eligible AS MATERIALIZED (
 SELECT ci.source_id FROM (
 SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)
 UNION ALL SELECT tx.id,date_trunc('month',b.posting_date)::date,b.posting_date,'received_bill_identity'::text
 FROM public.lts_open_finance_staging tx JOIN public.lts_open_finance_staging b
 ON b.user_id=tx.user_id AND b.institution_code=tx.institution_code AND b.resource_type='invoice'
 AND b.provider_deleted_at IS NULL AND b.provider_account_ref=tx.provider_account_ref
 AND b.normalized_payload->>'provider_id'=tx.raw_payload#>>'{creditCardMetadata,billId}'
 WHERE tx.user_id=p_user_id AND tx.institution_code='336' AND tx.resource_type='card_transaction'
 AND tx.provider_deleted_at IS NULL
 ) ci JOIN public.card_invoices open_cycle ON open_cycle.user_id=p_user_id
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)='c6'
 AND open_cycle.reference_month=ci.reference_month AND open_cycle.due_date=ci.due_date
 AND open_cycle.status IN('open','projected')
), rows as materialized (select * from public.lts_card_source_rows_v226(p_user_id)),
c6_contract_rows AS MATERIALIZED (
 SELECT r.*,jsonb_build_array(s.institution_code,s.provider_account_ref,r.last4,
 (s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz,
 public.lts_card_merchant_key_v226(r.description),r.total_installments)::text contract_key,
 (extract(year FROM r.reference_month)::int*12+extract(month FROM r.reference_month)::int-r.installment_number) cycle_offset
 FROM rows r LEFT JOIN public.lts_card_document_supplement_v234 doc ON doc.id=r.source_id AND doc.user_id=p_user_id
 JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id
 AND (s.id=r.source_id OR (doc.id IS NOT NULL AND s.id::text=doc.metadata->>'prior_purchase_source_id'))
 WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment AND r.amount>0 AND r.total_installments>1
 AND r.installment_number BETWEEN 1 AND r.total_installments AND r.reference_month IS NOT NULL
 AND s.resource_type='card_transaction' AND s.institution_code='336' AND nullif(s.provider_account_ref,'') IS NOT NULL
 AND nullif(r.last4,'') IS NOT NULL
 AND s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$'
 AND (doc.id IS NULL OR (doc.installment_number=(s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::int+1
 AND doc.total_installments=(s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int
 AND doc.last4=coalesce(s.raw_payload#>>'{creditCardMetadata,cardNumber}',s.normalized_payload->>'last4')
 AND doc.purchase_date=((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date))
), c6_contract_validity AS MATERIALIZED (
 SELECT contract_key,count(DISTINCT cycle_offset)=1 AND count(*)=count(DISTINCT installment_number) valid,
 max(reference_month+make_interval(months=>total_installments-installment_number)) end_month
 FROM c6_contract_rows GROUP BY contract_key
), c6_projection_sources AS MATERIALIZED (
 SELECT DISTINCT ON(r.contract_key,(r.reference_month+make_interval(months=>step))::date) r.*,step projection_step
 FROM c6_contract_rows r JOIN c6_contract_validity v USING(contract_key)
 CROSS JOIN LATERAL generate_series(1,least(120,r.total_installments-r.installment_number)) step
 WHERE v.valid AND NOT EXISTS(SELECT 1 FROM c6_contract_rows actual WHERE actual.contract_key=r.contract_key
 AND actual.reference_month=(r.reference_month+make_interval(months=>step))::date)
 ORDER BY r.contract_key,(r.reference_month+make_interval(months=>step))::date,r.installment_number DESC
),
accounts as materialized (
 select s.institution_name bank,public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 s.normalized_payload->>'name' name,s.normalized_payload->>'last4' last4,
 s.raw_payload#>>'{creditData,status}' status,s.raw_payload#>'{creditData,additionalCards}' additional_cards,
 nullif(s.normalized_payload->>'due_date','')::date last_due,s.last_seen_at observed_at
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='credit_card' and s.provider_deleted_at is null
), pending as materialized (
 select family,reference_month,min(due_date) due_date,count(*) n,round(sum(amount),2) amount,
 count(*) filter(where category_basis='unresolved') unclassified,max(observed_at) observed_at,
 jsonb_agg((to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM document_matches_v298 m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) items
 from rows r where NOT EXISTS(SELECT 1 FROM public.card_invoices paid WHERE paid.user_id=p_user_id AND r.family='c6' AND public.lts_card_family_v226(paid.card_name,paid.card_name)=r.family AND paid.reference_month=r.reference_month AND paid.status='paid') and not is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and reference_month>=date_trunc('month',current_date)::date group by family,reference_month
), first_cycles as materialized (select family,min(reference_month) AS month from pending group by family),
installments as materialized (
 select r.family,(r.reference_month+make_interval(months=>n))::date reference_month,r.amount,r.category_basis,r.observed_at,
 to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM document_matches_v298 m WHERE m.provider_id=r.source_id))),'{}'::jsonb)||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','remaining_installments_of_received_purchase') item
 from rows r join first_cycles f on f.family=r.family and f.month=r.reference_month
 cross join lateral generate_series(1,least(120,r.total_installments-r.installment_number)) n
 where r.family<>'c6' AND not r.is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and r.amount>0 and r.installment_number>0 and r.total_installments>r.installment_number

 UNION ALL
 SELECT r.family,(r.reference_month+make_interval(months=>n))::date,r.amount,r.category_basis,r.observed_at,
 (to_jsonb(r)-'contract_key'-'cycle_offset'-'projection_step')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount))
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM document_matches_v298 m -- v307-shared-document-match
 WHERE m.provider_id=r.source_id))),'{}'::jsonb)
 ||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'due_date',NULL,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','latest_strongly_identified_purchase_installment')
 FROM c6_projection_sources r CROSS JOIN LATERAL (SELECT r.projection_step n) step
 WHERE (r.reference_month+make_interval(months=>n))::date>=date_trunc('month',current_date)::date
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices paid WHERE paid.user_id=p_user_id AND public.lts_card_family_v226(paid.card_name,paid.card_name)='c6'
 AND paid.reference_month=(r.reference_month+make_interval(months=>n))::date AND paid.status='paid')
), projected as materialized (
 select family,reference_month,count(*) n,round(sum(amount),2) amount,count(*) filter(where category_basis='unresolved') unclassified,
 max(observed_at) observed_at,jsonb_agg(item order by item->>'description',item->>'source_id') items from installments group by family,reference_month
), composition as materialized (
 select coalesce(p.family,j.family) family,coalesce(p.reference_month,j.reference_month) reference_month,p.due_date,
 CASE WHEN coalesce(p.family,j.family)='c6' THEN coalesce(p.n,0)+coalesce(j.n,0) ELSE coalesce(p.n,j.n) END n,
 CASE WHEN coalesce(p.family,j.family)='c6' THEN coalesce(p.amount,0)+coalesce(j.amount,0) ELSE coalesce(p.amount,j.amount) END amount,
 CASE WHEN coalesce(p.family,j.family)='c6' THEN coalesce(p.unclassified,0)+coalesce(j.unclassified,0) ELSE coalesce(p.unclassified,j.unclassified) END unclassified,
 coalesce(p.observed_at,j.observed_at) observed_at,
 CASE WHEN coalesce(p.family,j.family)='c6' THEN coalesce(p.items,'[]'::jsonb)||coalesce(j.items,'[]'::jsonb) ELSE coalesce(p.items,j.items) END items,
 case when coalesce(p.family,j.family)='c6' AND p.n>0 AND j.n>0 THEN 'received_and_projected_installments' when p.n>0 and p.reference_month=f.month AND EXISTS(SELECT 1 FROM rows r WHERE r.family=p.family AND r.reference_month=p.reference_month AND r.provider_status='DOCUMENTED') then 'bank_document_composition' when p.n>0 and p.reference_month=f.month then 'open_finance_composition' when p.n>0 then 'provider_installments' else 'derived_current_installments' end basis
 from pending p full join projected j on j.family=p.family and j.reference_month=p.reference_month
 left join first_cycles f on f.family=coalesce(p.family,j.family)
), docs as materialized (
 select i.*,public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family
 from public.card_invoices i where i.user_id=p_user_id and i.due_date>=current_date and i.status<>'paid'
), cycles0 as (
 select coalesce(p.family,d.family) family,coalesce(p.reference_month,d.reference_month) AS month,
 coalesce(p.due_date,d.due_date) due_date,
 case when p.family<>'c6' AND p.basis='derived_current_installments' then greatest(p.amount,coalesce(d.amount,0)) else coalesce(p.amount,d.amount) end amount,
 case when p.family<>'c6' AND p.basis='derived_current_installments' and d.amount>p.amount then 'documented_floor_partial_detail'
 else coalesce(p.basis,case when d.source='derived_installments' then 'contracted_installments' else 'documented_snapshot' end) end basis,
 coalesce(p.n,0) item_count,coalesce(p.unclassified,0) unclassified,coalesce(p.items,'[]'::jsonb) items,p.observed_at,d.amount documentary_amount,
 case when d.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then d.metadata->>'as_of' end documentary_as_of
 from composition p full join docs d on d.family=p.family and d.reference_month=p.reference_month
), received_bills AS MATERIALIZED (
 SELECT b.* FROM public.lts_current_received_card_bills_v263(p_user_id) b
 WHERE (b.due_date>=current_date OR EXISTS(
 SELECT 1 FROM public.card_invoices open_cycle
 WHERE open_cycle.user_id=p_user_id
 AND (open_cycle.status IN('open','projected') OR (b.family='c6' AND open_cycle.status='closed'
 AND open_cycle.metadata->>'bank_statement_full_composition'='true' AND open_cycle.amount=b.amount))
 AND open_cycle.reference_month=b.reference_month
 AND open_cycle.due_date=b.due_date
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)=b.family))
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND ((i.status NOT IN('open','projected') AND NOT(b.family='c6' AND i.status='closed'
 AND i.metadata->>'bank_statement_full_composition'='true' AND i.amount=b.amount)) OR i.due_date IS DISTINCT FROM b.due_date
 OR (CASE WHEN i.metadata->>'as_of' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 THEN (i.metadata->>'as_of')::date ELSE '-infinity'::date END)
 >(b.source_updated_at AT TIME ZONE 'America/Sao_Paulo')::date))
), current_cycles AS (
 SELECT coalesce(c.family,b.family) family,coalesce(c.month,b.reference_month) AS month,coalesce(b.due_date,c.due_date) due_date,
 coalesce(b.amount,c.amount) amount,CASE WHEN b.invoice_source_id IS NOT NULL
 THEN 'open_finance_invoice_v263' ELSE c.basis END basis,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.n ELSE c.item_count END item_count,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN t.unclassified ELSE c.unclassified END unclassified,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN coalesce(t.items,'[]'::jsonb) ELSE c.items END items,
 coalesce(b.source_updated_at,c.observed_at) observed_at,
 c.documentary_amount,c.documentary_as_of,b.invoice_source_id,b.source_updated_at invoice_source_updated_at,
 b.received_at invoice_received_at,b.payment_status,b.reported_payment_amount,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN b.amount-coalesce(t.amount,0) END invoice_composition_difference,
 CASE WHEN b.invoice_source_id IS NOT NULL THEN abs(b.amount-coalesce(t.amount,0))<0.005 END invoice_composition_complete
 FROM cycles0 c FULL JOIN received_bills b ON b.family=c.family AND b.reference_month=c.month
 LEFT JOIN public.lts_open_finance_staging sb ON sb.id=b.invoice_source_id AND sb.user_id=p_user_id
 LEFT JOIN LATERAL (
 SELECT count(*) n,coalesce(sum(br.amount),0) amount,
 count(*) FILTER(WHERE br.category_basis='unresolved') unclassified,
 jsonb_agg((to_jsonb(br)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount))
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=br.source_id OR d.id=(SELECT m.document_id FROM document_matches_v298 m WHERE m.provider_id=br.source_id))),'{}'::jsonb)
 ORDER BY br.posting_date DESC,br.description,br.source_id) items
 FROM rows br WHERE br.family=b.family AND br.reference_month=b.reference_month
 AND (br.bill_id=sb.normalized_payload->>'provider_id' OR (br.provider_status='DOCUMENTED' AND br.due_date=b.due_date
 AND EXISTS(SELECT 1 FROM public.lts_card_document_supplement_v234 ds WHERE ds.id=br.source_id AND ds.user_id=p_user_id AND ds.provider_account_ref=sb.provider_account_ref))) AND NOT br.is_payment
 AND br.provider_status IN('POSTED','PENDING','DOCUMENTED')
 AND (EXISTS(SELECT 1 FROM public.lts_open_finance_staging tx
 WHERE tx.user_id=p_user_id AND tx.id=br.source_id AND tx.currency='BRL') OR br.provider_status='DOCUMENTED')
 )t ON true
), card_rows as (
 select a.*,coalesce((select jsonb_agg(to_jsonb(c)-'family' order by month) from current_cycles c where c.family=a.family),'[]'::jsonb) cycles from accounts a
)
select jsonb_build_object('version','card-cycles-v226','as_of',current_date,'computed_at',clock_timestamp(),
 'active_billing_accounts',(select count(*) from accounts where status='ACTIVE'),
 'cards',coalesce((select jsonb_agg(to_jsonb(c) order by bank,name) from card_rows c),'[]'::jsonb),
 'financial_effect','none','provider_balance_used_as_invoice',false),
 EXISTS( SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO result,c6_contract_uncertain;
-- A family-level uncertainty must not abort the shared reader or disappear in SUM.
SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) INTO c6_unresolved
FROM public.lts_card_source_rows_v226(p_user_id) r
WHERE r.family='c6' AND NOT r.is_payment AND r.reference_month IS NULL;
SELECT coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO c6_document_ambiguous
FROM public.lts_card_document_candidates_v269(p_user_id) c
JOIN public.lts_card_document_supplement_v234 d ON d.id=c.document_id AND d.user_id=p_user_id
WHERE d.family='c6' AND (c.dc>1 OR c.pc>1) AND d.reference_month>=date_trunc('month',current_date)::date;
IF jsonb_array_length(c6_document_ambiguous)>0 THEN
 WITH evidence AS MATERIALIZED (SELECT * FROM public.lts_card_source_rows_v226(p_user_id))
 SELECT jsonb_agg(c||jsonb_build_object('document_item',to_jsonb(dr),'provider_item',to_jsonb(pr))) INTO c6_document_ambiguous
 FROM jsonb_array_elements(c6_document_ambiguous) c LEFT JOIN evidence dr ON dr.source_id::text=c->>'document_id'
 LEFT JOIN evidence pr ON pr.source_id::text=c->>'provider_id';
END IF;
IF c6_contract_uncertain OR jsonb_array_length(c6_unresolved)>0 OR jsonb_array_length(c6_document_ambiguous)>0 THEN
 SELECT result||jsonb_build_object('complete',false,'incomplete_families',jsonb_build_array('c6'),
  'cards',coalesce(jsonb_agg(CASE WHEN card->>'family'='c6' THEN card||jsonb_build_object(
   'complete',false,'uncertainty_reason',CASE WHEN c6_contract_uncertain THEN 'installment_identity' ELSE 'cycle_identity' END,
   'unresolved_items',c6_unresolved,'ambiguous_document_candidates',c6_document_ambiguous,
   'cycles',coalesce((SELECT jsonb_agg(CASE WHEN cycle->>'payment_status'='paid' OR (cycle->>'month')::date<date_trunc('month',current_date)::date THEN cycle ELSE cycle||jsonb_build_object('observed_unreconciled_amount',cycle->'amount','amount',NULL,
    'basis','incomplete_cycle_identity','complete',false,'invoice_composition_complete',false) END)
    FROM jsonb_array_elements(card->'cycles') cycle),'[]'::jsonb)) ELSE card END),'[]'::jsonb))
 INTO result FROM jsonb_array_elements(result->'cards') card;
ELSE
 result:=result||jsonb_build_object('complete',true,'incomplete_families','[]'::jsonb);
END IF;
RETURN public.lts_card_settlement_overlay_v290(p_user_id,public.lts_card_due_overlay_v290(p_user_id,public.lts_card_forecast_overlay_v311(p_user_id,result)));
END
$function$

