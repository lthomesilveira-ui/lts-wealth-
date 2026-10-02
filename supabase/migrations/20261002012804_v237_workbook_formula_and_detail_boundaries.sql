
-- Source resolutions add provenance; source amounts and source rows remain intact.
CREATE TABLE public.lts_card_detail_boundary_v237 (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 family text NOT NULL, detail_from date NOT NULL, evidence jsonb NOT NULL,
 verified_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,family)
);
CREATE TABLE public.lts_card_formula_resolution_v237 (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 family text NOT NULL, reference_month date NOT NULL, source_hash text NOT NULL,
 source_sheet text NOT NULL, expected_rows int NOT NULL CHECK(expected_rows>0),
 invoice_amount numeric NOT NULL, raw_detail_total numeric NOT NULL,
 excluded_rows jsonb NOT NULL CHECK(jsonb_typeof(excluded_rows)='array'),
 formula_evidence jsonb NOT NULL, source_note text NOT NULL,
 verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,family,reference_month,source_hash)
);
ALTER TABLE public.lts_card_detail_boundary_v237 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_card_formula_resolution_v237 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_detail_boundary_v237,public.lts_card_formula_resolution_v237 FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.lts_card_workbook_exclusion_v237(p_user_id uuid,p_family text,p_month date,p_hash text,p_sheet text,p_row int,p_category text,p_amount numeric)
RETURNS boolean LANGUAGE sql STABLE SET search_path=''
AS $function$
 SELECT EXISTS (
  SELECT 1 FROM public.lts_card_formula_resolution_v237 f
  CROSS JOIN LATERAL jsonb_to_recordset(f.excluded_rows) x(source_row int,category text,amount numeric)
  WHERE f.user_id=p_user_id AND f.family=p_family AND f.reference_month=p_month
   AND f.source_hash=p_hash AND f.source_sheet=p_sheet
   AND x.source_row=p_row AND x.category=p_category AND x.amount=p_amount
   AND EXISTS (
    SELECT 1 FROM public.lts_card_workbook_evidence_v226 w
    WHERE w.user_id=f.user_id AND w.family=f.family AND w.reference_month=f.reference_month
      AND w.source_hash=f.source_hash AND w.source_sheet=f.source_sheet
    GROUP BY w.user_id,w.family,w.reference_month,w.source_hash,w.source_sheet
    HAVING count(*)=f.expected_rows AND min(w.expected_rows)=f.expected_rows AND max(w.expected_rows)=f.expected_rows
      AND count(DISTINCT w.expected_invoice_amount)=1 AND max(w.expected_invoice_amount)=f.invoice_amount
      AND round(sum(w.amount),2)=f.raw_detail_total
   )
 )
$function$;
REVOKE ALL ON FUNCTION public.lts_card_workbook_exclusion_v237(uuid,text,date,text,text,int,text,numeric) FROM PUBLIC,anon,authenticated;

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
), workbook_cycles as materialized(
 select family,reference_month,max(expected_invoice_amount) invoice_amount
 from public.lts_card_workbook_evidence_v226 where user_id=p_user_id
 group by family,reference_month
 having count(distinct source_hash)=1 and count(distinct expected_rows)=1 and count(*)=max(expected_rows)
 and count(distinct expected_invoice_amount)=1 and round(sum(CASE WHEN public.lts_card_workbook_exclusion_v237(user_id,family,reference_month,source_hash,source_sheet,source_row,category,amount) THEN 0 ELSE amount END),2)=round(max(expected_invoice_amount),2)
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
from workbook_eligible e join public.lts_card_workbook_evidence_v226 w on w.user_id=p_user_id
 and w.family=e.family and w.reference_month=e.competence_month
where not public.lts_card_workbook_exclusion_v237(w.user_id,w.family,w.reference_month,w.source_hash,w.source_sheet,w.source_row,w.category,w.amount)
$function$
;
CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH r AS MATERIALIZED(SELECT * FROM public.lts_expense_rows_v230_baseline(p_user_id,p_from,p_to)),
e AS MATERIALIZED(SELECT * FROM public.lts_workbook_identity_evidence_v232 WHERE user_id=p_user_id)
SELECT r.row_key,r.event_date,r.transaction_date,r.competence_month,r.amount,
r.category,
CASE WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa' ELSE r.beneficiary END,
CASE WHEN e.source_ref IS NOT NULL AND r.description IN ('Não identificado','Descrição pendente')
 THEN e.original_description ELSE r.description END,
r.account_source,r.source_table,r.source_ref,r.coverage_mode,r.raw_category,r.raw_reference,r.purchase_date,
CASE WHEN r.coverage_mode='card_detail_workbook_exact' AND EXISTS(SELECT 1 FROM public.lts_card_workbook_evidence_v226 w JOIN public.lts_card_formula_resolution_v237 f ON f.user_id=w.user_id AND f.family=w.family AND f.reference_month=w.reference_month AND f.source_hash=w.source_hash WHERE w.user_id=p_user_id AND w.source_hash||':'||w.source_sheet||':'||w.source_row=r.source_ref AND w.category=r.category AND w.amount=r.amount) THEN 'identified'
 WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 AND r.property_component IS DISTINCT FROM 'A revisar' THEN 'identified' ELSE r.identity_status END,
CASE WHEN r.coverage_mode='card_invoice_aggregate_fallback' THEN 'Faturas sem composição individual'
 WHEN r.management_group IN ('Larissa','Larissa — despesas') THEN 'Larissa'
 WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
 THEN e.original_category ELSE r.management_group END,
r.management_subgroup,r.property_code,r.property_component
FROM r LEFT JOIN e ON e.source_table=r.source_table AND e.source_ref=r.source_ref
 AND e.event_date=r.event_date AND round(e.amount,2)=round(r.amount,2)
 AND pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(e.original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')=pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(r.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_card_history_inventory_v237(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<'2013-10-10'::date OR p_to>current_date OR p_offset IS NULL OR p_offset<0 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'invalid inventory range';
 END IF;
 WITH records AS MATERIALIZED (
  SELECT r.source_table,r.source_ref,r.event_date,r.competence_month,r.amount,
   coalesce(e.bank,'Banco a confirmar') bank,e.family,coalesce(e.card_name,r.account_source) card_name,
   CASE WHEN e.reference_month<b.detail_from AND e.composition_status='aggregate_only' THEN 'historical_total'
    WHEN e.composition_status='partial_source' AND formula.family IS NOT NULL THEN 'formula_reconciled'
    ELSE coalesce(e.composition_status,'audit_pending') END composition_status,
   e.signed_amount<0 AND e.signed_amount<>e.observed_amount sign_corrected,e.verified_at
  FROM public.lts_v229_expense_rows(u,p_from,p_to) r
  LEFT JOIN public.lts_card_history_evidence_v235 e ON e.user_id=u AND e.source_table=r.source_table AND e.source_ref=r.source_ref
   AND e.event_date=r.event_date AND e.reference_month=r.competence_month AND e.signed_amount=round(r.amount,2)
  LEFT JOIN public.lts_card_detail_boundary_v237 b ON b.user_id=u AND b.family=e.family
  LEFT JOIN public.lts_card_formula_resolution_v237 formula ON formula.user_id=u AND formula.family=e.family AND formula.reference_month=e.reference_month
  WHERE r.coverage_mode IN ('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235')
  UNION ALL
  SELECT e.source_table,e.source_ref,e.event_date,e.reference_month,e.signed_amount,e.bank,e.family,e.card_name,
    'formula_reconciled',e.signed_amount<0 AND e.signed_amount<>e.observed_amount,e.verified_at
  FROM public.lts_card_history_evidence_v235 e
  JOIN public.lts_card_formula_resolution_v237 fr ON fr.user_id=u AND fr.family=e.family AND fr.reference_month=e.reference_month AND fr.invoice_amount=e.signed_amount
  JOIN public.lts_expense_effective_read_cache src ON src.user_id=u AND src.source_table=e.source_table AND src.source_ref=e.source_ref AND src.event_date=e.event_date AND round(src.amount,2)=e.signed_amount
  WHERE e.user_id=u AND e.event_date BETWEEN p_from AND p_to
    AND NOT EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,e.reference_month,least(current_date,(e.reference_month+interval '1 month - 1 day')::date)) rr WHERE rr.source_table=e.source_table AND rr.source_ref=e.source_ref)
    AND EXISTS(SELECT 1 FROM public.lts_card_exact_recovery_v226(u,e.reference_month,least(current_date,(e.reference_month+interval '1 month - 1 day')::date)) rr WHERE rr.replaced_source_table=e.source_table AND rr.replaced_source_ref=e.source_ref)
 ), cycles AS MATERIALIZED (
  SELECT bank,family,card_name,competence_month reference_month,round(sum(amount),2) amount,count(*) record_count,
   round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) charges,
   round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) credits,
   (array_agg(source_table ORDER BY event_date,source_ref))[1] source_table,
   (array_agg(source_ref ORDER BY event_date,source_ref))[1] source_ref,
   min(event_date) event_date,
   CASE WHEN bool_or(composition_status='audit_pending') THEN 'audit_pending'
     WHEN bool_or(composition_status='partial_source') THEN 'partial_source'
     WHEN bool_or(composition_status='aggregate_only') THEN 'aggregate_only'
     WHEN bool_or(composition_status='formula_reconciled') THEN 'formula_reconciled' ELSE 'historical_total' END composition_status,
   max(verified_at) verified_at
  FROM records GROUP BY bank,family,card_name,competence_month
 ), page AS MATERIALIZED (SELECT * FROM cycles ORDER BY reference_month DESC,card_name,bank OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','card-history-inventory-v237','from',p_from,'to',p_to,'offset',p_offset,
  'summary',jsonb_build_object('record_count',(SELECT count(*) FROM records),'cycle_count',(SELECT count(*) FROM cycles),
   'total',(SELECT round(coalesce(sum(amount),0),2) FROM records),
   'charges',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount>0),0),2) FROM records),
   'credits',(SELECT round(coalesce(sum(amount) FILTER(WHERE amount<0),0),2) FROM records),
   'sign_corrections',(SELECT count(*) FROM records WHERE sign_corrected),
   'historical_total_cycles',(SELECT count(*) FROM cycles WHERE composition_status='historical_total'),
   'formula_reconciled_cycles',(SELECT count(*) FROM cycles WHERE composition_status='formula_reconciled'),
   'detail_boundaries',coalesce((SELECT jsonb_agg(jsonb_build_object('family',family,'detail_from',detail_from,'evidence',evidence) ORDER BY detail_from) FROM public.lts_card_detail_boundary_v237 WHERE user_id=u),'[]'),
   'aggregate_only_cycles',(SELECT count(*) FROM cycles WHERE composition_status='aggregate_only'),
   'partial_source_cycles',(SELECT count(*) FROM cycles WHERE composition_status='partial_source'),
   'audit_pending_cycles',(SELECT count(*) FROM cycles WHERE composition_status='audit_pending')),
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM cycles) THEN p_offset+p_limit END,
  'cycles',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY reference_month DESC,card_name,bank) FROM page p),'[]'::jsonb)
 ) INTO result;
 RETURN result;
END $function$
;

CREATE FUNCTION public.lts_browser_card_history_record_v237(p_source_table text,p_source_ref text,p_event_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); e public.lts_card_history_evidence_v235%ROWTYPE;
 f public.lts_card_formula_resolution_v237%ROWTYPE; boundary date; result jsonb; applied numeric; items jsonb;
BEGIN
 SELECT * INTO e FROM public.lts_card_history_evidence_v235 WHERE user_id=u AND source_table=p_source_table AND source_ref=p_source_ref AND event_date=p_event_date;
 IF NOT FOUND THEN RAISE EXCEPTION 'record audit unavailable'; END IF;
 SELECT detail_from INTO boundary FROM public.lts_card_detail_boundary_v237 WHERE user_id=u AND family=e.family;
 SELECT * INTO f FROM public.lts_card_formula_resolution_v237 WHERE user_id=u AND family=e.family AND reference_month=e.reference_month AND invoice_amount=e.signed_amount;
 IF FOUND THEN
  IF NOT EXISTS(SELECT 1 FROM public.lts_expense_effective_read_cache c WHERE c.user_id=u AND c.source_table=e.source_table AND c.source_ref=e.source_ref AND c.event_date=e.event_date AND round(c.amount,2)=f.invoice_amount)
   OR NOT EXISTS(SELECT 1 FROM public.lts_card_exact_recovery_v226(u,e.reference_month,least(current_date,(e.reference_month+interval '1 month - 1 day')::date)) rr WHERE rr.replaced_source_table=e.source_table AND rr.replaced_source_ref=e.source_ref)
  THEN RAISE EXCEPTION 'formula source changed after verification'; END IF;
  SELECT sum(l.amount) FILTER(WHERE NOT excluded),jsonb_agg(to_jsonb(l)||jsonb_build_object('included_in_source_total',NOT excluded) ORDER BY l.source_row)
  INTO applied,items FROM (
   SELECT l.*,EXISTS(SELECT 1 FROM jsonb_to_recordset(f.excluded_rows) x(source_row int,category text,amount numeric) WHERE x.source_row=l.source_row AND x.category=l.category AND x.amount=l.amount) excluded
   FROM public.lts_card_history_lines_v235 l WHERE l.user_id=u AND l.family=e.family AND l.reference_month=e.reference_month
  ) l;
  IF round(applied,2)<>f.invoice_amount THEN RAISE EXCEPTION 'formula composition mismatch'; END IF;
  result:=jsonb_build_object('version','card-history-record-v237','bank',e.bank,'card_name',e.card_name,'family',e.family,'reference_month',e.reference_month,
   'composition_status','formula_reconciled','detail_from',boundary,'source_note',f.source_note,
   'record',jsonb_build_object('source_table',e.source_table,'source_ref',e.source_ref,'event_date',e.event_date,'description',e.description,'amount',e.signed_amount,'original_report_amount',e.observed_amount,'sign_corrected',false,'workbook_evidence',e.workbook_evidence,'verified_at',f.verified_at),
   'cycle_total',e.signed_amount,'cycle_records',jsonb_build_array(jsonb_build_object('source_table',e.source_table,'source_ref',e.source_ref,'date',e.event_date,'description',e.description,'amount',e.signed_amount,'kind','payment','workbook_evidence',e.workbook_evidence)),
   'detail_total',round(applied,2),'raw_detail_total',f.raw_detail_total,'detail_difference',round(applied,2)-e.signed_amount,
   'detail_rows',jsonb_array_length(items),'nonzero_detail_rows',(SELECT count(*) FROM jsonb_array_elements(items) x WHERE (x->>'amount')::numeric<>0),
   'items',items,'formula_evidence',f.formula_evidence,'excluded_rows',f.excluded_rows);
 ELSE
  result:=public.lts_browser_card_history_record_v235(p_source_table,p_source_ref,p_event_date);
  result:=result||jsonb_build_object('version','card-history-record-v237','detail_from',boundary);
  IF e.composition_status='aggregate_only' AND e.reference_month<boundary THEN
   result:=result||jsonb_build_object('composition_status','historical_total','source_note','Registro anterior ao início do detalhamento deste cartão na planilha. O total original e seus ajustes estão preservados; não há pendência de composição para esse período.');
  END IF;
 END IF;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_browser_card_history_inventory_v237(date,date,int,int),public.lts_browser_card_history_record_v237(text,text,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_history_inventory_v237(date,date,int,int),public.lts_browser_card_history_record_v237(text,text,date) TO authenticated;
