CREATE OR REPLACE FUNCTION public.lts_flow_classification_decision_v1(p_user_id uuid,p_event jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $function$
SELECT coalesce((
 SELECT p_event||jsonb_build_object(
  'category',coalesce(CASE WHEN d.beneficiary IN('Benjamin','Larissa','Rafiki')
    AND d.category_label IS NOT NULL AND d.category_label !~* '^(Lucas|Benjamin|Larissa|Rafiki)[[:space:]]*[-—]'
   THEN d.beneficiary||' - '||d.category_label ELSE d.category_label END,p_event->>'category'),
  'center_cost',coalesce(d.beneficiary,p_event->>'center_cost'),
  'classification_confirmed',d.category_label IS NOT NULL)
 FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id
 AND d.source_table=CASE
  WHEN p_event->>'source'='open_finance' OR p_event->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
  WHEN p_event->>'source'='current_event' THEN 'daily_flow_documentary_bridge'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$' THEN 'evento_base'
  ELSE p_event->>'source' END
 AND d.source_ref=CASE
  WHEN p_event->>'open_finance_id' IS NOT NULL THEN p_event->>'open_finance_id'
  WHEN p_event->>'source'='legacy_fix86' AND p_event->>'source_ref' ~ '^evento_base:[0-9]+$'
   THEN split_part(p_event->>'source_ref',':',2)
  ELSE p_event->>'source_ref' END
),p_event)
$function$;
REVOKE ALL ON FUNCTION public.lts_flow_classification_decision_v1(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_classification_decision_v1(uuid,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_review_overlay_v229(p_user_id uuid, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE part text; ev jsonb;
BEGIN
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  SELECT coalesce(jsonb_agg(e||CASE WHEN d.source_ref IS NULL AND n.id IS NULL THEN '{}'::jsonb ELSE jsonb_build_object(
   'category',coalesce(d.category_label,n.category,e->>'category'),'center_cost',coalesce(d.beneficiary,e->>'center_cost'),'classification_confirmed',d.source_ref IS NOT NULL OR n.category<>'A classificar') END ORDER BY e->>'event_date',e->>'source_ref'),'[]') INTO ev
  FROM jsonb_array_elements(coalesce(p_flow#>ARRAY[part,'events'],'[]')) original
  CROSS JOIN LATERAL(SELECT public.lts_flow_classification_decision_v1(p_user_id,original) e OFFSET 0) enriched
  LEFT JOIN public.lts_v229_new_bank_rows(p_user_id,current_date-30,current_date) n ON n.id::text=e->>'open_finance_id' LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_ref=coalesce(e->>'open_finance_id',e->>'source_ref')
  AND d.source_table=CASE WHEN e->>'source'='open_finance' OR e->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
   WHEN e->>'source'='current_event' THEN 'daily_flow_documentary_bridge' ELSE e->>'source' END;
  p_flow:=jsonb_set(p_flow,ARRAY[part,'events'],ev,true);
 END LOOP;
 IF jsonb_typeof(p_flow#>'{observed_bank_movements,pending_projections}')='array' THEN
  SELECT coalesce(jsonb_agg(public.lts_flow_classification_decision_v1(p_user_id,x) ORDER BY x->>'event_date',x->>'source_ref'),'[]')
  INTO ev FROM jsonb_array_elements(p_flow#>'{observed_bank_movements,pending_projections}') x;
  p_flow:=jsonb_set(p_flow,'{observed_bank_movements,pending_projections}',ev);
 END IF;
 RETURN p_flow;
END $function$
;
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
 SELECT x FROM jsonb_array_elements(public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date)) x
 JOIN anchors a ON a.bank=x->>'account' AND (x->>'event_date')::date>a.dt
 WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
 AND x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
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
), payroll AS MATERIALIZED (SELECT projection_ref FROM public.lts_payroll_bank_matches_v231(p_user_id))
SELECT coalesce(jsonb_agg(public.lts_flow_classification_decision_v1(p_user_id,c.x) ORDER BY c.x->>'event_date',c.x->>'source_ref'),'[]'::jsonb)
FROM candidates c WHERE NOT EXISTS(SELECT 1 FROM payroll p WHERE p.projection_ref=c.x->>'source_ref')
AND NOT EXISTS (
 SELECT 1 FROM posted s JOIN positions p ON p.institution_code=s.institution_code
 AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 WHERE s.bank=c.x->>'account' AND s.posting_date=(c.x->>'event_date')::date
 AND s.signed_amount=(c.x->>'signed_amount')::numeric
 AND (lower(trim(s.description_raw))=lower(trim(c.x->>'description')) OR s.id::text=c.x->>'open_finance_id'
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
 WHERE z->>'ref' IN (c.x->>'source_ref',(c.x->>'source')||':'||(c.x->>'source_ref'))))
)
$function$
;
CREATE OR REPLACE FUNCTION public.lts_card_document_cycles_v226(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with documents as (
 select r.*,public.lts_card_family_v226(r.card_name,case when r.card_name ~* 'c6' then 'C6' when r.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family,
 x.items,x.n,x.total
 from public.lts_card_invoice_detail_reconciliation r
 cross join lateral (
  select count(*) n,sum(p.installment_amount) total,jsonb_agg(jsonb_build_object(
   'description',p.description_raw,'purchase_date',p.purchase_date,'last4',p.card_final,'amount',p.installment_amount,
   'category',case when d.beneficiary in ('Larissa','Benjamin','Rafiki') and coalesce(d.category_label,p.category) !~* '^(Lucas|Larissa|Benjamin|Rafiki)' then d.beneficiary||' — '||coalesce(d.category_label,p.category) else coalesce(d.category_label,p.category) end,
   'category_basis',coalesce(d.decision_basis,'reconciled_document'),'installment_number',p.installment_number,'total_installments',p.installments)
   order by p.purchase_date,p.row_id) items
  from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
  where p.user_id=r.user_id and p.invoice_id=r.invoice_id
 )x
 where r.user_id=p_user_id and r.reconciled and r.detail_lines>0
 and x.n=r.detail_lines and round(x.total,2)=round(r.invoice_total,2)
)
select coalesce(jsonb_agg(jsonb_build_object('family',family,'reference_month',date_trunc('month',due_date)::date,
 'due_date',due_date,'amount',invoice_total,'detail_total',total,'difference',0,'detail_complete',true,
 'item_count',n,'items',items,'source','document_reconciled')),'[]'::jsonb) from documents where family is not null
$function$
;
