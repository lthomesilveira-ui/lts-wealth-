-- Official bank values override the read model only when the entire document
-- matches its unchanged workbook source. Original cells and categories remain intact.
CREATE OR REPLACE FUNCTION public.lts_card_workbook_bank_rows_v1(p_user_id uuid)
RETURNS SETOF public.lts_card_workbook_evidence_v226
LANGUAGE sql STABLE SET search_path='' AS $function$
WITH candidates AS MATERIALIZED (
 SELECT w.*,w.evidence->'bank_invoice' b FROM public.lts_card_workbook_evidence_v226 w WHERE w.user_id=p_user_id
), valid AS MATERIALIZED (
 SELECT user_id,family,reference_month FROM candidates
 GROUP BY user_id,family,reference_month
 HAVING count(*)=min(expected_rows) AND min(expected_rows)=max(expected_rows)
 AND count(DISTINCT source_hash)=1 AND count(DISTINCT source_sheet)=1
 AND count(DISTINCT expected_invoice_amount)=1
 AND count(DISTINCT b->>'source_sha256')=1 AND count(DISTINCT b->>'source_library_file_id')=1
 AND count(DISTINCT b->>'source_line')=count(*)
 AND bool_and(coalesce(b->>'basis'='official_bank_statement_user_provided'
  AND length(b->>'source_sha256')=64 AND b->>'source_library_file_id' LIKE 'libfile_%'
  AND b->>'workbook_source_hash'=source_hash AND b->>'workbook_source_sheet'=source_sheet
  AND (b->>'workbook_source_row')::int=source_row AND (b->>'original_amount')::numeric=amount
  AND b->>'original_category'=category AND b->>'original_last4'=last4
  AND (b->>'reference_month')::date=reference_month AND (b->>'expected_rows')::int=expected_rows
  AND (b->>'invoice_amount')::numeric=expected_invoice_amount
  AND b->>'purchase_date' ~ '^\d{4}-\d{2}-\d{2}$' AND b->>'last4' ~ '^\d{4}$'
  AND (b->>'installment_number')::int BETWEEN 1 AND (b->>'installments')::int
  AND nullif(b->>'description','') IS NOT NULL,false))
 AND round(sum((b->>'amount')::numeric),2)=max(expected_invoice_amount)
)
SELECT (jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,
 to_jsonb(w)||CASE WHEN v.user_id IS NOT NULL THEN jsonb_build_object(
 'amount',(w.evidence#>>'{bank_invoice,amount}')::numeric,
 'last4',w.evidence#>>'{bank_invoice,last4}',
 'evidence',w.evidence||jsonb_build_object('bank_precedence_applied',true))
 ELSE jsonb_build_object('evidence',w.evidence-'bank_precedence_applied') END)).*
FROM public.lts_card_workbook_evidence_v226 w LEFT JOIN valid v USING(user_id,family,reference_month)
WHERE w.user_id=p_user_id
$function$;
REVOKE ALL ON FUNCTION public.lts_card_workbook_bank_rows_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_workbook_bank_rows_v1(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_bank_monthly_deltas_v1(p_user_id uuid)
RETURNS TABLE(source_id bigint,delta numeric)
LANGUAGE sql STABLE SET search_path='' AS $function$
SELECT s.id,sum(w.amount-(w.evidence#>>'{bank_invoice,original_amount}')::numeric)
FROM public.lts_card_workbook_bank_rows_v1(p_user_id) w
JOIN public.lts_v175_workbook_monthly_category_source s ON s.user_id=w.user_id
 AND s.id=(w.evidence#>>'{bank_invoice,monthly_allocation,source_id}')::bigint
 AND s.competence_month=w.reference_month
 AND s.source_workbook_sha256=w.evidence#>>'{bank_invoice,monthly_allocation,source_hash}'
 AND s.source_row=(w.evidence#>>'{bank_invoice,monthly_allocation,source_row}')::int
 AND s.category_raw=w.category AND s.category_raw=w.evidence#>>'{bank_invoice,monthly_allocation,category_raw}'
 AND s.amount=(w.evidence#>>'{bank_invoice,monthly_allocation,original_amount}')::numeric
WHERE w.user_id=p_user_id AND w.evidence->>'bank_precedence_applied'='true'
GROUP BY s.id HAVING sum(w.amount-(w.evidence#>>'{bank_invoice,original_amount}')::numeric)<>0
$function$;
REVOKE ALL ON FUNCTION public.lts_card_bank_monthly_deltas_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_bank_monthly_deltas_v1(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_workbook_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH formula_valid AS MATERIALIZED (
 SELECT f.* FROM public.lts_card_formula_resolution_v237 f
 JOIN public.lts_card_workbook_evidence_v226 w ON w.user_id=f.user_id AND w.family=f.family AND w.reference_month=f.reference_month
 WHERE f.user_id=p_user_id
 GROUP BY f.user_id,f.family,f.reference_month,f.source_hash
 HAVING count(*)=f.expected_rows AND min(w.source_hash)=f.source_hash AND max(w.source_hash)=f.source_hash
 AND min(w.source_sheet)=f.source_sheet AND max(w.source_sheet)=f.source_sheet
 AND round(sum(w.amount),2)=f.raw_detail_total AND min(w.expected_invoice_amount)=f.invoice_amount AND max(w.expected_invoice_amount)=f.invoice_amount
 AND count(*) FILTER(WHERE EXISTS(SELECT 1 FROM jsonb_to_recordset(f.excluded_rows) x(source_row int,category text,amount numeric) WHERE x.source_row=w.source_row AND x.category=w.category AND x.amount=w.amount))=jsonb_array_length(f.excluded_rows)
), rows AS MATERIALIZED (
 SELECT w.*,EXISTS(SELECT 1 FROM jsonb_to_recordset(coalesce(f.excluded_rows,'[]')) x(source_row int,category text,amount numeric) WHERE x.source_row=w.source_row AND x.category=w.category AND x.amount=w.amount) formula_excluded
 FROM public.lts_card_workbook_bank_rows_v1(p_user_id) w LEFT JOIN formula_valid f ON f.user_id=w.user_id AND f.family=w.family AND f.reference_month=w.reference_month
 WHERE w.user_id=p_user_id
), cycles AS (
 SELECT family,reference_month,max(expected_invoice_amount) amount,count(*) raw_item_count,
 count(*) FILTER(WHERE NOT formula_excluded) item_count,sum(amount) raw_detail_total,
 sum(amount) FILTER(WHERE NOT formula_excluded) detail_total,
 bool_and(evidence->>'bank_precedence_applied'='true') bank_document_complete,
 jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'source_date',source_date,
 'category',category,'category_basis','historical_workbook','last4',last4,'amount',amount,
 'description',CASE WHEN evidence->>'bank_precedence_applied'='true' THEN evidence#>>'{bank_invoice,description}' ELSE 'Linha '||source_row||' da planilha · estabelecimento não informado' END,
 'date_kind',CASE WHEN evidence->>'bank_precedence_applied'='true' THEN 'purchase_date' ELSE 'reference_month' END,
 'reference_month',reference_month,'purchase_date',CASE WHEN evidence->>'bank_precedence_applied'='true' THEN evidence#>>'{bank_invoice,purchase_date}' END,'posting_date',null)
 ||CASE WHEN evidence->>'bank_precedence_applied'='true' THEN jsonb_build_object(
 'installment_number',(evidence#>>'{bank_invoice,installment_number}')::int,
 'installments',(evidence#>>'{bank_invoice,installments}')::int,
 'bank_document',evidence->'bank_invoice') ELSE '{}'::jsonb END
 ORDER BY source_row) FILTER(WHERE NOT formula_excluded) items,
 coalesce(jsonb_agg(jsonb_build_object('source_row',source_row,'source_sheet',source_sheet,'category',category,'amount',amount)
 ORDER BY source_row) FILTER(WHERE formula_excluded),'[]') excluded_items
 FROM rows GROUP BY family,reference_month
 HAVING count(distinct source_hash)=1 AND count(distinct expected_rows)=1 AND count(*)=max(expected_rows)
 AND count(distinct expected_invoice_amount)=1
)
SELECT coalesce(jsonb_agg(jsonb_build_object('family',c.family,'reference_month',c.reference_month,
 'bank',CASE WHEN c.family LIKE 'itau%' THEN 'Itaú' WHEN c.family='c6' THEN 'C6' ELSE 'Bradesco' END,
 'card_name',c.family,'due_date',null,'amount',c.amount,'item_count',c.item_count,'detail_total',c.detail_total,
 'difference',round(c.amount-c.detail_total,2),'detail_complete',round(c.amount-c.detail_total,2)=0,
 'source',CASE WHEN c.bank_document_complete AND round(c.amount-c.detail_total,2)=0 THEN 'document_reconciled' WHEN round(c.amount-c.detail_total,2)=0 THEN 'workbook_reconciled' ELSE 'workbook_partial' END,'items',c.items)
 ||CASE WHEN f.family IS NOT NULL AND round(c.detail_total,2)=f.invoice_amount THEN
 jsonb_build_object('formula_resolution',jsonb_build_object('source_note',f.source_note,'raw_detail_total',c.raw_detail_total,
 'raw_item_count',c.raw_item_count,'excluded_items',c.excluded_items,'formula_evidence',f.formula_evidence)) ELSE '{}' END
 ORDER BY c.reference_month DESC),'[]') FROM cycles c LEFT JOIN formula_valid f ON f.user_id=p_user_id AND f.family=c.family AND f.reference_month=c.reference_month
$function$
;
CREATE OR REPLACE FUNCTION public.lts_card_exact_recovery_v226(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean, replaced_source_table text, replaced_source_ref text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with open_finance(event_date,transaction_date,competence_month,amount,category,center_cost,counterparty,origin_type,origin_name,source_table,source_ref,coverage_mode,is_property,is_financing,replaced_source_table,replaced_source_ref) as materialized(
with rows as materialized(select * from public.lts_card_source_rows_v226(p_user_id) where not is_payment),
bills as materialized (
 select s.id,s.posting_date,s.signed_amount,s.normalized_payload->>'provider_id' bill_id,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='invoice'
 and s.provider_deleted_at is null and s.posting_date between p_from and least(p_to,current_date)
), eligible as materialized (
 select c.*,b.bill_id from public.lts_expense_effective_read_cache c join bills b
 on b.posting_date=c.event_date and abs(b.signed_amount-c.amount)<0.005
 and b.family=public.lts_card_family_v226(c.origin_name,c.origin_name)
 cross join lateral(select sum(r.amount) amount,count(*) n from rows r where r.bill_id=b.bill_id)x
 where c.user_id=p_user_id and c.coverage_mode='card_invoice_aggregate_fallback'
 and x.n>0 and abs(x.amount-c.amount)<0.005
 and (select count(*) from bills bb where bb.posting_date=c.event_date and abs(bb.signed_amount-c.amount)<0.005
 and bb.family=public.lts_card_family_v226(c.origin_name,c.origin_name))=1
)
select e.event_date,r.purchase_date,e.competence_month,r.amount,r.category,
 case when r.category ~ '^Benjamin[[:space:]]*[-—]' then 'Benjamin' when r.category ~ '^Larissa[[:space:]]*[-—]' then 'Larissa'
 when r.category='Rafiki' then 'Rafiki' else 'Não atribuído' end,
 r.description,'cartão'::text,e.origin_name,'lts_open_finance_staging'::text,r.source_id::text,
 'card_detail_open_finance_exact'::text,false,false,e.source_table,e.source_ref
from eligible e join rows r on r.bill_id=e.bill_id
), formula_valid AS MATERIALIZED (
 SELECT f.* FROM public.lts_card_formula_resolution_v237 f
 JOIN LATERAL (
  SELECT count(*) n,min(w.expected_rows) minimum_rows,max(w.expected_rows) maximum_rows,
   count(DISTINCT w.expected_invoice_amount) distinct_amounts,max(w.expected_invoice_amount) invoice_amount,
   round(sum(w.amount),2) raw_total
  FROM public.lts_card_workbook_evidence_v226 w
  WHERE w.user_id=f.user_id AND w.family=f.family AND w.reference_month=f.reference_month
   AND w.source_hash=f.source_hash AND w.source_sheet=f.source_sheet
 ) checked ON checked.n=f.expected_rows AND checked.minimum_rows=f.expected_rows AND checked.maximum_rows=f.expected_rows
  AND checked.distinct_amounts=1 AND checked.invoice_amount=f.invoice_amount AND checked.raw_total=f.raw_detail_total
 WHERE f.user_id=p_user_id
), workbook_rows AS MATERIALIZED (
 SELECT w.*,x.source_row IS NOT NULL excluded
 FROM public.lts_card_workbook_bank_rows_v1(p_user_id) w
 LEFT JOIN formula_valid f ON f.user_id=w.user_id AND f.family=w.family AND f.reference_month=w.reference_month
  AND f.source_hash=w.source_hash AND f.source_sheet=w.source_sheet
 LEFT JOIN LATERAL jsonb_to_recordset(coalesce(f.excluded_rows,'[]')) x(source_row int,category text,amount numeric)
  ON x.source_row=w.source_row AND x.category=w.category AND x.amount=w.amount
 WHERE w.user_id=p_user_id
), workbook_cycles as materialized(
 select family,reference_month,max(expected_invoice_amount) invoice_amount
 from workbook_rows where user_id=p_user_id
 group by family,reference_month
 having count(distinct source_hash)=1 and count(distinct expected_rows)=1 and count(*)=max(expected_rows)
 and count(distinct expected_invoice_amount)=1 and round(sum(amount) FILTER(WHERE NOT excluded),2)=round(max(expected_invoice_amount),2)
), workbook_eligible as materialized(
 select c.*,w.family from public.lts_expense_effective_read_cache c join workbook_cycles w
 on w.family=public.lts_card_family_v226(c.origin_name,c.origin_name)
 and w.reference_month=c.competence_month and round(w.invoice_amount,2)=round(c.amount,2)
 where c.user_id=p_user_id and c.coverage_mode='card_invoice_aggregate_fallback'
 and c.event_date between p_from and least(p_to,current_date)
 and not exists(select 1 from open_finance r where r.replaced_source_table=c.source_table and r.replaced_source_ref=c.source_ref)
 and (select count(*) from public.lts_expense_effective_read_cache x where x.user_id=p_user_id
  and x.coverage_mode='card_invoice_aggregate_fallback' and x.competence_month=c.competence_month
  and public.lts_card_family_v226(x.origin_name,x.origin_name)=w.family and round(x.amount,2)=round(w.invoice_amount,2))=1
)
select * from open_finance
union all
select e.event_date,null::date,e.competence_month,w.amount,w.category,
 case when w.category ~* '^Benjamin[[:space:]]*[-—]' then 'Benjamin' when w.category ~* '^Larissa[[:space:]]*[-—]' then 'Larissa'
 when w.category ~* '^Lucas[[:space:]]*[-—]' then 'Lucas' when w.category='Rafiki' then 'Rafiki' else 'Não atribuído' end,
 'Composição da planilha · '||w.category||' · linha '||w.source_row,
 'cartão'::text,e.origin_name,'lts_card_workbook_evidence_v226'::text,w.source_hash||':'||w.source_sheet||':'||w.source_row,
 'card_detail_workbook_exact'::text,false,false,e.source_table,e.source_ref
from workbook_eligible e join workbook_rows w on w.user_id=p_user_id
 and w.family=e.family and w.reference_month=e.competence_month
where not w.excluded
$function$
;
CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v225_baseline(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base_all as materialized (
  select h.*
  from public.lts_expense_effective_read_cache h
  where h.user_id=p_user_id
    and h.event_date between greatest(p_from,date '2013-10-10') and least(p_to,current_date)
),
card_full as materialized (
  select competence_month,round(sum(amount),2) total
  from public.lts_expense_effective_read_cache
  where user_id=p_user_id and origin_type='cartão'
  group by competence_month
),
src_month as materialized (
  select s.competence_month,round(sum(s.amount),2) source_total,max(s.card_total) declared_total,count(*) source_rows
  from public.lts_v175_workbook_monthly_category_source s
  where s.user_id=p_user_id
  group by s.competence_month
),
eligible as materialized (
  select s.competence_month,s.declared_total,s.source_total
  from src_month s
  join card_full c using(competence_month)
  where abs(s.source_total-s.declared_total)<=0.01
    and abs(c.total-s.declared_total)<=0.01
    and s.competence_month>=date_trunc('month',p_from)::date
    and s.competence_month<=date_trunc('month',p_to)::date
    and (
      s.competence_month>date_trunc('month',p_from)::date
      or p_from=date_trunc('month',p_from)::date
    )
    and (
      s.competence_month<date_trunc('month',p_to)::date
      or p_to>=(date_trunc('month',p_to)+interval '1 month - 1 day')::date
    )
),
retained as (
  select b.event_date,b.transaction_date,b.competence_month,b.amount,b.category,b.center_cost,b.counterparty,
         b.origin_type,b.origin_name,b.source_table,b.source_ref,b.coverage_mode,b.is_property,b.is_financing
  from base_all b
  where not (
    b.origin_type='cartão'
    and exists(select 1 from eligible e where e.competence_month=b.competence_month)
  )
),
allocated as (
  select
    s.competence_month as event_date,
    s.competence_month as transaction_date,
    s.competence_month,
    s.amount+coalesce(bank_delta.delta,0),
    coalesce(a.canonical_category,s.category_raw) as category,
    case
      when s.parent_group like 'Benjamin - %' or s.category_raw like 'Benjamin - %' then 'Benjamin'
      when s.parent_group='Larissa' or s.category_raw like 'Larissa - %' then 'Larissa'
      when lower(trim(s.category_raw)) in ('rafiki','pet') then 'Rafiki'
      when s.parent_group='Cipó 396' then 'Casa'
      else 'Não atribuído'
    end as center_cost,
    s.parent_group as counterparty,
    'cartão'::text as origin_type,
    'Consolidado histórico dos cartões'::text as origin_name,
    'lts_v175_workbook_monthly_category_source'::text as source_table,
    s.id::text as source_ref,
    'card_category_allocated_workbook_v176'::text as coverage_mode,
    (s.parent_group='Cipó 396' or s.category_raw ~* 'O Parque') as is_property,
    false as is_financing
  from public.lts_v175_workbook_monthly_category_source s
  join eligible e using(competence_month)
  left join public.lts_card_bank_monthly_deltas_v1(p_user_id) bank_delta on bank_delta.source_id=s.id
  left join lateral (
    select ca.canonical_category
    from public.lts_category_alias ca
    where ca.active=true and lower(trim(ca.alias))=lower(trim(s.category_raw))
    limit 1
  ) a on true
  where s.user_id=p_user_id
)
select * from retained
union all
select * from allocated
$function$
;
NOTIFY pgrst,'reload schema';
