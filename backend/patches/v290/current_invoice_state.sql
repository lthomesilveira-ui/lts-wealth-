-- Reconcile the current invoice state once, while retaining original snapshots.
CREATE TEMP TABLE invoice_spend_baseline_v290 ON COMMIT DROP AS
SELECT c.user_id,count(*) rows,sum(e.amount) amount,
 md5(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text)::text) digest
FROM public.lts_product_read_cache c CROSS JOIN LATERAL public.lts_v229_expense_rows(c.user_id,date '2013-10-10',current_date)e
GROUP BY c.user_id;

CREATE OR REPLACE FUNCTION public.lts_card_settlement_overlay_v290(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
WITH links AS MATERIALIZED(
 SELECT l.invoice_source_id,l.expected_amount,l.expected_due_date,l.expected_payment_date,
 public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) receipt
 FROM public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 WHERE l.user_id=p_user_id AND l.active)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN jsonb_set(p_payload,'{cards}',(
 SELECT jsonb_agg(c.value||jsonb_build_object('cycles',(
 SELECT coalesce(jsonb_agg(y.value||CASE WHEN l.receipt IS NOT NULL
 AND (y.value->>'amount')::numeric=l.expected_amount AND (y.value->>'due_date')::date=l.expected_due_date THEN
 jsonb_build_object('source_payment_status',y.value->>'payment_status','payment_status','paid',
 'settlement_confirmed',true,'settled_on',l.expected_payment_date,
 'settlement_basis','reviewed_issuer_full_payment_and_exact_posted_checking_debit')
 ELSE '{}'::jsonb END ORDER BY y.ord),'[]')
 FROM jsonb_array_elements(coalesce(c.value->'cycles','[]')) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 )) ORDER BY c.ord)
 FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
),false) ELSE p_payload END
$f$;
REVOKE ALL ON FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb) TO service_role;

DO $cycle$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure) INTO d;
 IF position('RETURN public.lts_card_due_overlay_v290(p_user_id,result);' IN d)=0 THEN RAISE EXCEPTION 'Card cycle source changed'; END IF;
 d:=replace(d,'RETURN public.lts_card_due_overlay_v290(p_user_id,result);',
 'RETURN public.lts_card_settlement_overlay_v290(p_user_id,public.lts_card_due_overlay_v290(p_user_id,result));');
 EXECUTE d;
END $cycle$;

DO $amount$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_card_invoice_amounts_v230(uuid)'::regprocedure) INTO d;
 IF position('b.reference_month,b.due_date,b.status,b.amount,b.source FROM base b' IN d)=0 THEN RAISE EXCEPTION 'Current invoice amount source changed'; END IF;
 d:=replace(d,'b.reference_month,b.due_date,b.status,b.amount,b.source FROM base b',
 'b.reference_month,b.due_date,CASE WHEN b.status IN(''open'',''projected'') AND public.lts_card_invoice_settled_v290(p_user_id,b.card_name,b.reference_month,b.due_date,b.amount) THEN ''paid'' ELSE b.status END,b.amount,b.source FROM base b');
 EXECUTE d;
END $amount$;

DO $effective$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_card_invoices_effective_v226(uuid)'::regprocedure) INTO d;
 IF md5(d)<>'8d61b8fe004133b2e5dfc01f0e14e0ad' THEN RAISE EXCEPTION 'Effective invoice source changed'; END IF;
 d:=replace(d,$a$c.items is not null and i.status='open' and i.due_date>=current_date$a$,
 $b$c.items is not null and i.status IN('open','projected') and i.due_date>=current_date$b$);
 d:=replace(d,$a$ON public.lts_card_family_v226(e.value->>'card_name',e.value->>'card_name')='c6'
 AND public.lts_card_family_v226(a.card_name,a.card_name)='c6'$a$,
 $b$ON public.lts_card_family_v226(e.value->>'card_name',e.value->>'card_name')=public.lts_card_family_v226(a.card_name,a.card_name)$b$);
 d:=replace(d,$a$AND (e.value->>'reference_month')::date=a.reference_month AND (e.value->>'due_date')::date=a.due_date$a$,
 $b$AND (e.value->>'reference_month')::date=a.reference_month$b$);
 d:=replace(d,$a$jsonb_build_object('amount',a.amount,'source',a.source)$a$,
 $b$jsonb_build_object('amount',a.amount,'source',a.source,'due_date',a.due_date,'status',a.status)$b$);
 EXECUTE d;
END $effective$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_card_operating_view_v2(uuid,date)'::regprocedure))<>'0a195fe7acb677f0da50d65a2653804c' THEN RAISE EXCEPTION 'Operating invoice source changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_card_operating_view_v2(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with source_invoices AS MATERIALIZED(SELECT * FROM public.lts_card_invoices_effective_v226(p_user_id)),
projection_frontier AS(SELECT public.lts_card_family_v226(card_name,card_name) family,min(reference_month) first_month
 FROM source_invoices WHERE source='received_card_composition_v290' GROUP BY 1),
inv as (
  select ci.id,ci.card_name,ci.reference_month,ci.due_date,ci.status,ci.amount,ci.source,ci.metadata,
         exists(
           select 1 from public.lts_fact_confirmation fc
           where fc.user_id=p_user_id
             and fc.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
             and fc.event_date=ci.due_date
             and (fc.signed_amount is null or abs(fc.signed_amount+abs(ci.amount))<=0.02)
         ) confirmed_payment,
         case
           when lower(coalesce(ci.status,''))='paid' then 'paid'
           when lower(coalesce(ci.status,''))='closed' and exists(
             select 1 from public.lts_fact_confirmation fc
             where fc.user_id=p_user_id
               and fc.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
               and fc.event_date=ci.due_date
               and (fc.signed_amount is null or abs(fc.signed_amount+abs(ci.amount))<=0.02)
           ) then 'paid'
           when lower(coalesce(ci.status,''))='closed' and ci.due_date>=p_as_of then 'closed_unpaid'
           when lower(coalesce(ci.status,''))='closed' and ci.due_date<p_as_of then 'payment_evidence_needed'
           when lower(coalesce(ci.status,''))='open' then 'open_cycle'
           when ci.source='received_card_composition_v290' AND ci.reference_month=pf.first_month then 'open_cycle'
           when ci.source IN('derived_installments','received_card_composition_v290') then 'contracted_installment_floor'
           else 'other_projection'
         end human_state
  from source_invoices ci LEFT JOIN projection_frontier pf ON pf.family=public.lts_card_family_v226(ci.card_name,ci.card_name)
  where ci.user_id=p_user_id
), closed as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state',human_state,'label',case when human_state='closed_unpaid' then 'Fatura fechada · a pagar' else 'Fatura vencida · confirmar pagamento' end,
    'detail_available',exists(select 1 from public.lts_card_invoice_detail_reconciliation r where r.user_id=p_user_id and r.reconciled=true and r.due_date=inv.due_date and trim(r.card_name)=trim(inv.card_name))
  ) order by due_date,card_name),'[]'::jsonb) j,
  coalesce(sum(amount),0) total
  from inv where human_state in ('closed_unpaid','payment_evidence_needed')
), paid_recent as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state','paid','label',case when confirmed_payment then 'Pagamento confirmado' else 'Fatura paga' end,'confirmed',confirmed_payment
  ) order by due_date desc,card_name),'[]'::jsonb) j
  from inv
  where human_state='paid' and due_date>=p_as_of-90
), open_cycles as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state','open_cycle','label','Fatura aberta','source_evidence',case when source in ('app_screenshot','app_statement_open') then 'valor observado no app/extrato' else 'valor registrado' end,
    'detail_preview',coalesce(metadata->'items','[]'::jsonb),
    'detail_preview_count',jsonb_array_length(coalesce(metadata->'items','[]'::jsonb)),
    'detail_preview_total',coalesce((select round(sum((x->>'amount')::numeric),2) from jsonb_array_elements(coalesce(metadata->'items','[]'::jsonb)) x where nullif(x->>'amount','') is not null),0),
    'detail_preview_basis',case when jsonb_array_length(coalesce(metadata->'items','[]'::jsonb))>0 then 'itens documentados da fatura aberta' else null end
  ) order by due_date,card_name),'[]'::jsonb) j,
  coalesce(sum(amount),0) total
  from inv where human_state='open_cycle'
), floors as (
  select reference_month,round(sum(amount)::numeric,2) amount,count(*) cards,
         jsonb_agg(jsonb_build_object('card_name',card_name,'amount',amount,'due_date',due_date) order by due_date,card_name) detail
  from inv where human_state='contracted_installment_floor'
  group by reference_month
), floor_summary as (
  select coalesce(jsonb_agg(jsonb_build_object('reference_month',to_char(reference_month,'YYYY-MM'),'amount',amount,'cards',cards,'detail',detail) order by reference_month),'[]'::jsonb) months,
         coalesce(sum(amount),0) total,min(reference_month) first_month,max(reference_month) last_month
  from floors
), rec as (
  select count(*) reconciled_invoices,coalesce(sum(detail_lines),0) detail_lines,round(coalesce(sum(detail_net),0)::numeric,2) detail_net,
         min(due_date) first_due,max(due_date) last_due,count(*) filter(where abs(delta)<=0.02) zero_delta_invoices
  from public.lts_card_invoice_detail_reconciliation
  where user_id=p_user_id and reconciled=true
), review as (select public.lts_card_classification_review_v1(p_user_id,100) j),
next_due as (
  select card_name,due_date,amount,human_state
  from inv where human_state in ('closed_unpaid','payment_evidence_needed','open_cycle')
  order by due_date,case human_state when 'closed_unpaid' then 0 when 'payment_evidence_needed' then 1 else 2 end
  limit 1
)
select jsonb_build_object(
  'version','card-operating-v2-open-detail-preview','as_of',p_as_of,
  'closed_or_due',(select j from closed),'closed_or_due_total',(select total from closed),
  'paid_recent',(select j from paid_recent),
  'open_cycles',(select j from open_cycles),'open_cycles_total',(select total from open_cycles),
  'contracted_installment_floor_months',(select months from floor_summary),'contracted_installment_floor_total',(select total from floor_summary),
  'contracted_installment_floor_first_month',(select first_month from floor_summary),'contracted_installment_floor_last_month',(select last_month from floor_summary),
  'next_due',coalesce((select jsonb_build_object('card_name',card_name,'due_date',due_date,'amount',amount,'state',human_state) from next_due),'{}'::jsonb),
  'detail_coverage',(select to_jsonb(rec) from rec),
  'classification_review',jsonb_build_object(
    'pending_groups',(select (j->>'pending_groups')::int from review),
    'pending_lines',(select (j->>'pending_lines')::int from review),
    'pending_value',(select (j->>'pending_value')::numeric from review),
    'safe_suggestion_groups',(select (j->>'safe_suggestion_groups')::int from review)
  ),
  'guardrails',jsonb_build_array(
    'Fatura fechada é obrigação de caixa até existir evidência de pagamento.',
    'Confirmação de pagamento muda o estado da obrigação e preserva a saída de caixa uma única vez.',
    'Fatura aberta é valor observado até a data da evidência e pode crescer até o fechamento.',
    'Detalhe de fatura aberta só é exibido quando existem itens documentados; ausência de detalhe não é preenchida por inferência.',
    'Parcelas futuras já contratadas são piso conhecido da fatura futura, não previsão do valor final.',
    'Pagamento da fatura é liquidação de caixa; consumo econômico vem das compras detalhadas quando disponíveis.'
  )
);
$function$;
DO $parity$ DECLARE b record; n bigint; v numeric; h text;
BEGIN FOR b IN SELECT * FROM invoice_spend_baseline_v290 LOOP
 SELECT count(*),sum(e.amount),md5(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text)::text) INTO n,v,h
 FROM public.lts_v229_expense_rows(b.user_id,date '2013-10-10',current_date)e;
 IF n IS DISTINCT FROM b.rows OR v IS DISTINCT FROM b.amount OR h IS DISTINCT FROM b.digest
 THEN RAISE EXCEPTION 'Invoice state change altered canonical consumption'; END IF;
 END LOOP;
END $parity$;

