-- V290: dated, owner-confirmed billing rules affect projections only.
CREATE TABLE public.lts_card_due_rule_v290(
 user_id uuid NOT NULL,family text NOT NULL,effective_from date NOT NULL,due_day integer NOT NULL CHECK(due_day BETWEEN 1 AND 28),
 decision_source text NOT NULL,confirmed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,family,effective_from),CHECK(extract(day FROM effective_from)=1)
);
ALTER TABLE public.lts_card_due_rule_v290 ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_rules ON public.lts_card_due_rule_v290 FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_card_due_rule_v290 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_card_due_rule_v290 TO authenticated;
GRANT ALL ON public.lts_card_due_rule_v290 TO service_role;
CREATE OR REPLACE FUNCTION public.lts_card_due_rule_changed_v290() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton; RETURN NULL; END $f$;
REVOKE ALL ON FUNCTION public.lts_card_due_rule_changed_v290() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_due_rule_changed_v290() TO service_role;
CREATE TRIGGER due_rule_changed_v290 AFTER INSERT OR UPDATE OR DELETE ON public.lts_card_due_rule_v290
 FOR EACH STATEMENT EXECUTE FUNCTION public.lts_card_due_rule_changed_v290();

CREATE OR REPLACE FUNCTION public.lts_card_due_overlay_v290(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN jsonb_set(p_payload,'{cards}',coalesce((
 SELECT jsonb_agg(c.value||jsonb_build_object('cycles',coalesce((
 SELECT jsonb_agg(y.value||CASE WHEN r.due_day IS NOT NULL AND y.value->>'invoice_source_id' IS NULL THEN
 jsonb_build_object('due_date',((y.value->>'month')::date+r.due_day-1),
 'original_due_date',y.value->>'due_date','due_date_basis','owner_confirmed_cycle_rule',
 'due_rule_effective_from',r.effective_from,'due_rule_confirmed_at',r.confirmed_at)
 WHEN r.due_day IS NOT NULL AND (y.value->>'due_date')::date<>((y.value->>'month')::date+r.due_day-1)
 THEN jsonb_build_object('due_date_conflict',true,'owner_expected_due_date',((y.value->>'month')::date+r.due_day-1))
 ELSE '{}'::jsonb END ORDER BY y.ord)
 FROM jsonb_array_elements(coalesce(c.value->'cycles','[]')) WITH ORDINALITY y(value,ord)
 LEFT JOIN LATERAL(SELECT r.* FROM public.lts_card_due_rule_v290 r WHERE r.user_id=p_user_id
 AND r.family=c.value->>'family' AND (y.value->>'month')::date>=r.effective_from
 ORDER BY r.effective_from DESC LIMIT 1)r ON true
 ),'[]'::jsonb)) ORDER BY c.ord)
 FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
),'[]'),false) ELSE p_payload END
$f$;
REVOKE ALL ON FUNCTION public.lts_card_due_overlay_v290(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_due_overlay_v290(uuid,jsonb) TO service_role;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure))<>'c5011ceab6b5451fb5cf173523cfc40d' THEN RAISE EXCEPTION 'V290 card reader changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE result jsonb; c6_contract_uncertain boolean; c6_unresolved jsonb; c6_document_ambiguous jsonb;
BEGIN
 SELECT EXISTS(WITH rows AS MATERIALIZED (SELECT * FROM public.lts_card_source_rows_v226(p_user_id)),
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
)
 SELECT 1 FROM c6_contract_validity WHERE NOT valid AND end_month>=date_trunc('month',current_date)::date
 UNION ALL SELECT 1 FROM rows r WHERE r.family='c6' AND r.provider_status IN('PENDING','POSTED','DOCUMENTED') AND NOT r.is_payment
 AND r.amount>0 AND r.total_installments>r.installment_number AND r.installment_number>0
 AND (r.reference_month IS NULL OR r.reference_month+make_interval(months=>r.total_installments-r.installment_number)>=date_trunc('month',current_date)::date)
 AND NOT EXISTS(SELECT 1 FROM c6_contract_rows identified WHERE identified.source_id=r.source_id)) INTO c6_contract_uncertain;
with c6_eligible AS MATERIALIZED (
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
 jsonb_agg((to_jsonb(r)-'bank'-'family'-'card_name'-'billing_last4'-'bill_id')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) items
 from rows r where NOT EXISTS(SELECT 1 FROM public.card_invoices paid WHERE paid.user_id=p_user_id AND r.family='c6' AND public.lts_card_family_v226(paid.card_name,paid.card_name)=r.family AND paid.reference_month=r.reference_month AND paid.status='paid') and not is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and reference_month>=date_trunc('month',current_date)::date group by family,reference_month
), first_cycles as materialized (select family,min(reference_month) AS month from pending group by family),
installments as materialized (
 select r.family,(r.reference_month+make_interval(months=>n))::date reference_month,r.amount,r.category_basis,r.observed_at,
 to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=r.source_id))),'{}'::jsonb)||jsonb_build_object('reference_month',(r.reference_month+make_interval(months=>n))::date,'installment_number',r.installment_number+n,'provider_status','PROJECTED','projection_basis','remaining_installments_of_received_purchase') item
 from rows r join first_cycles f on f.family=r.family and f.month=r.reference_month
 cross join lateral generate_series(1,least(120,r.total_installments-r.installment_number)) n
 where r.family<>'c6' AND not r.is_payment and (r.provider_status IN ('PENDING','DOCUMENTED') OR (r.provider_status='POSTED' AND r.source_id IN (SELECT source_id FROM c6_eligible))) and r.amount>0 and r.installment_number>0 and r.total_installments>r.installment_number

 UNION ALL
 SELECT r.family,(r.reference_month+make_interval(months=>n))::date,r.amount,r.category_basis,r.observed_at,
 (to_jsonb(r)-'contract_key'-'cycle_offset'-'projection_step')||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount))
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id)m WHERE m.provider_id=r.source_id))),'{}'::jsonb)
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
 AND open_cycle.status IN('open','projected')
 AND open_cycle.reference_month=b.reference_month
 AND open_cycle.due_date=b.due_date
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)=b.family))
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND i.reference_month=b.reference_month
 AND public.lts_card_family_v226(i.card_name,i.card_name)=b.family
 AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date
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
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND (d.id=br.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(p_user_id) m WHERE m.provider_id=br.source_id))),'{}'::jsonb)
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
 'financial_effect','none','provider_balance_used_as_invoice',false) INTO result;
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
RETURN public.lts_card_due_overlay_v290(p_user_id,result);
END
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_projection_rows_v290(p_user_id uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH enabled AS MATERIALIZED(SELECT DISTINCT family,min(effective_from) first_month
 FROM public.lts_card_due_rule_v290 WHERE user_id=p_user_id GROUP BY family),
cycles AS MATERIALIZED(SELECT public.lts_card_cycles_v226(p_user_id) value WHERE EXISTS(SELECT 1 FROM enabled))
SELECT p_user_id,coalesce(ci.card_name,c->>'name'),(y->>'month')::date,(y->>'due_date')::date,
 'projected'::text,(y->>'amount')::numeric,'received_card_composition_v290'::text
FROM cycles,jsonb_array_elements(value->'cards')c
JOIN enabled r ON r.family=c->>'family'
CROSS JOIN LATERAL jsonb_array_elements(c->'cycles')y
LEFT JOIN LATERAL(SELECT i.card_name FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)=c->>'family'
 ORDER BY i.reference_month DESC,i.due_date DESC LIMIT 1)ci ON true
WHERE (y->>'month')::date>=r.first_month AND (y->>'due_date')::date>=current_date
AND y->>'invoice_source_id' IS NULL AND y->>'complete' IS DISTINCT FROM 'false'
AND y->>'amount' ~ '^[0-9]+([.][0-9]+)?$' AND jsonb_array_length(coalesce(y->'items','[]'))>0
$f$;
REVOKE ALL ON FUNCTION public.lts_card_projection_rows_v290(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_projection_rows_v290(uuid) TO service_role;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_card_invoice_amounts_v230(uuid)'::regprocedure))<>'b569557bd6f567b77bd413c7e323ef23' THEN RAISE EXCEPTION 'V290 card projection source changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
#variable_conflict use_column
DECLARE memo jsonb; source_epoch bigint; fingerprint text;
BEGIN
 IF p_user_id IS NULL THEN RETURN QUERY SELECT * FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id); RETURN;END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='source-v243:'||source_epoch;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='lts_card_invoice_amounts_v230_v243' AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO memo FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
  END IF;
 END IF;
 RETURN QUERY WITH current_projection AS MATERIALIZED(SELECT * FROM public.lts_card_projection_rows_v290(p_user_id)),
 base AS(SELECT r.*,a.ord FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text))
 SELECT b.user_id,b.card_name,b.reference_month,b.due_date,b.status,b.amount,b.source FROM base b
 WHERE NOT EXISTS(SELECT 1 FROM current_projection p WHERE p.reference_month=b.reference_month
 AND public.lts_card_family_v226(p.card_name,p.card_name)=public.lts_card_family_v226(b.card_name,b.card_name))
 UNION ALL SELECT * FROM current_projection;
END $function$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_flow_future_read_slice_v9(uuid,date,date)'::regprocedure))<>'ab9dc5d78cbbc116600f9f233268a032' THEN RAISE EXCEPTION 'V290 future flow reader changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_flow_future_read_slice_v9(p_user_id uuid, p_from date, p_to date)
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
  source_key:=public.lts_flow_read_source_key_v247(p_user_id);
  select * into c from public.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    if current_setting('transaction_read_only')::boolean then
      -- Same engine, horizon and fingerprint as refresh_v9. No source writes.
      horizon_end:=current_date+least(1800,greatest(60,requested_horizon,
        coalesce((select to_date-current_date from public.lts_flow_future_read_cache_v2
          where user_id=p_user_id and as_of=current_date),0)));
      select p_user_id user_id,current_date as_of,current_date from_date,horizon_end to_date,
        'daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'::text engine_version,
        public.lts_daily_flow_fix86_v20(p_user_id,current_date,horizon_end)
          ||jsonb_build_object('source_fingerprint',source_key) payload,now() refreshed_at into c;
    else
      perform public.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
      select * into c from public.lts_flow_future_read_cache_v2
       where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
         and payload->>'source_fingerprint'=source_key and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
       order by refreshed_at desc limit 1;
    end if;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=public.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.lts_card_invoice_amounts_v230(p_user_id)i where (i.status='open' OR (i.status='projected' AND i.source IN('derived_installments_v234','received_card_composition_v290'))) and i.due_date>=current_date));
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',coalesce(to_jsonb(
      CASE WHEN (SELECT count(*)=30 AND count(DISTINCT y.dt)=30 AND count(nullif(y.x#>>'{Consolidado,economic_net}',''))=30 FROM all_src y WHERE y.dt>s.dt AND y.dt<=s.dt+30)
      THEN nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric+(
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30) ELSE NULL END),'null'::jsonb),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$;

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;

