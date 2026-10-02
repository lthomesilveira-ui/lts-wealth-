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
 FROM public.lts_card_workbook_evidence_v226 w
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
