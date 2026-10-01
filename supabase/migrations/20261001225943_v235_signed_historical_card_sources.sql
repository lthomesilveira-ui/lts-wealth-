-- Verified workbook provenance is private. Imports are separate from schema.
CREATE TABLE public.lts_card_history_source_audit_v235 (
 user_id uuid NOT NULL REFERENCES auth.users(id),source_table text NOT NULL,source_ref text NOT NULL,
 event_date date NOT NULL,competence_month date NOT NULL,origin_name text NOT NULL,
 ledger_amount numeric NOT NULL CHECK(ledger_amount>=0),source_signed_amount numeric NOT NULL,
 source_file text NOT NULL,source_sha256 text NOT NULL CHECK(length(source_sha256)=64),
 source_sheet text NOT NULL,source_rows jsonb NOT NULL CHECK(jsonb_typeof(source_rows)='array' AND jsonb_array_length(source_rows)>0),
 source_description text NOT NULL,composition_status text NOT NULL CHECK(composition_status IN ('total_only','unreconciled_detail')),
 detail_rows integer NOT NULL DEFAULT 0 CHECK(detail_rows>=0),detail_total numeric,detail_difference numeric,
 evidence jsonb NOT NULL DEFAULT '{}',verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref),CHECK(abs(source_signed_amount)=ledger_amount)
);
ALTER TABLE public.lts_card_history_source_audit_v235 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_history_source_audit_v235 FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.lts_card_history_source_audit_v235 TO service_role;
COMMENT ON TABLE public.lts_card_history_source_audit_v235 IS 'Source totals and signed workbook adjustments, not individual purchases or bank credit evidence.';

-- Restore only signed source records with an exact identity, date and amount guard.
CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED(SELECT * FROM public.lts_expense_effective_rows_v225_baseline(p_user_id,p_from,p_to)),
recovery AS MATERIALIZED(
 SELECT r.* FROM public.lts_card_exact_recovery_v226(p_user_id,p_from,p_to) r JOIN base b
 ON b.source_table=r.replaced_source_table AND b.source_ref=r.replaced_source_ref AND b.coverage_mode='card_invoice_aggregate_fallback'
), restored AS MATERIALIZED(
 SELECT b.* FROM base b WHERE NOT EXISTS(SELECT 1 FROM recovery r WHERE b.source_table=r.replaced_source_table AND b.source_ref=r.replaced_source_ref)
 UNION ALL SELECT event_date,transaction_date,competence_month,amount,category,center_cost,counterparty,origin_type,origin_name,source_table,source_ref,coverage_mode,is_property,is_financing FROM recovery
), bank_items AS MATERIALIZED(
 SELECT * FROM public.lts_card_source_rows_v226(p_user_id) WHERE NOT is_payment AND provider_status='POSTED'
 AND reference_month BETWEEN p_from AND p_to
), official AS MATERIALIZED(
 SELECT public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 date_trunc('month',s.posting_date)::date reference_month,
 CASE WHEN count(distinct (s.normalized_payload->>'amount')::numeric)=1 THEN max((s.normalized_payload->>'amount')::numeric) END amount
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='invoice'
 AND s.provider_deleted_at IS NULL AND date_trunc('month',s.posting_date)::date BETWEEN p_from AND p_to
 GROUP BY 1,2
), complete AS MATERIALIZED(
 SELECT c.family,c.reference_month,sum(c.amount) amount
 FROM bank_items c JOIN official o USING(family,reference_month)
 GROUP BY c.family,c.reference_month,o.amount HAVING abs(sum(c.amount)-o.amount)<.005
), scoped AS MATERIALIZED(
 SELECT b.*,CASE WHEN b.origin_type='cartão' AND b.competence_month IN(SELECT reference_month FROM complete)
 THEN public.lts_card_family_v226(b.origin_name,b.origin_name) END family FROM restored b
), replaced AS MATERIALIZED(
 SELECT c.* FROM complete c LEFT JOIN scoped b ON b.competence_month=c.reference_month AND b.family=c.family
 WHERE NOT EXISTS(SELECT 1 FROM scoped workbook WHERE workbook.competence_month=c.reference_month
 AND workbook.coverage_mode='card_category_allocated_workbook_v176')
 GROUP BY c.family,c.reference_month,c.amount HAVING abs(coalesce(sum(b.amount),0)-c.amount)>.005
)
SELECT b.event_date,b.transaction_date,b.competence_month,coalesce(a.source_signed_amount,b.amount),
 CASE WHEN a.source_signed_amount<0 THEN 'Ajustes de fatura conforme planilha' ELSE b.category END,b.center_cost,b.counterparty,
 b.origin_type,b.origin_name,b.source_table,b.source_ref,
 CASE WHEN a.source_signed_amount<0 THEN 'card_workbook_signed_adjustment_v235' ELSE b.coverage_mode END,b.is_property,b.is_financing
FROM scoped b LEFT JOIN public.lts_card_history_source_audit_v235 a
 ON a.user_id=p_user_id AND a.source_table=b.source_table AND a.source_ref=b.source_ref
 AND a.event_date=b.event_date AND a.competence_month=b.competence_month
 AND a.source_signed_amount<0 AND a.ledger_amount=round(b.amount,2)
 AND b.coverage_mode='card_invoice_aggregate_fallback'
WHERE NOT EXISTS(SELECT 1 FROM replaced c WHERE c.reference_month=b.competence_month AND c.family=b.family)
UNION ALL
SELECT c.reference_month,c.posting_date,c.reference_month,c.amount,c.category,'Não atribuído',c.description,
 'cartão',c.card_name,'lts_open_finance_staging',c.source_id::text,'card_bank_closed_complete',false,false
FROM bank_items c JOIN replaced r USING(family,reference_month)
$function$
;
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
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
    and not (eb.dados->>'desc'='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank))
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
    and (eb.dados->>'dia')::date between p_from and p_to and (select onflag from coopharma_nonbank)
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
  from card_amounts ci where ci.user_id=p_user_id and ci.due_date between p_from and p_to and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
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
$function$
;
CREATE OR REPLACE FUNCTION public.lts_flow_history_read_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; hf date; ht date;
BEGIN
 SELECT payload INTO j FROM public.lts_v229_read_cache WHERE user_id=u AND kind='history' AND payload->>'source_revision'='workbook-sign-v235' AND as_of=current_date AND from_date<=p_from AND to_date>=p_to ORDER BY refreshed_at DESC LIMIT 1;
 IF j IS NULL THEN
  hf:=p_from;ht:=p_to;
  j:=(public.lts_browser_flow_v12(hf,ht)->'flow')||jsonb_build_object('source_revision','workbook-sign-v235');
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload) VALUES(u,'history',current_date,hf,ht,j)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=now();
 END IF;
 RETURN j||jsonb_build_object('from',p_from,'to',p_to,'historical',(j->'historical')||jsonb_build_object(
  'days',coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(j#>'{historical,days}') x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'),
  'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date') FROM jsonb_array_elements(j#>'{historical,events}') x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]')));
END $function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_expense_detail_v229(p_from date, p_to date, p_group text DEFAULT NULL::text, p_subgroup text DEFAULT NULL::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 500, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to>current_date OR p_from<date '2013-10-10' OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'invalid detail range'; END IF;
 WITH r AS MATERIALIZED(
  SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to) x
  WHERE (p_group IS NULL OR x.management_group=p_group
    OR (p_group='Faturas conciliadas pelo total' AND x.coverage_mode='card_invoice_aggregate_fallback')
    OR (p_group='Identificações pendentes' AND x.identity_status='pending')
    OR (p_group='__card_total__' AND (x.source_table LIKE '%card%' OR x.coverage_mode LIKE 'card_%'))
    OR (p_group='__account_total__' AND NOT(x.source_table LIKE '%card%' OR x.coverage_mode LIKE 'card_%')))
   AND (p_subgroup IS NULL OR x.management_subgroup=p_subgroup)
 ), filtered AS MATERIALIZED(
  SELECT * FROM r WHERE nullif(trim(p_query),'') IS NULL OR strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,beneficiary,raw_reference,category)),public.lts_v178_norm(trim(p_query)))>0
 ), page AS MATERIALIZED(SELECT * FROM filtered ORDER BY event_date DESC,amount DESC,row_key OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','expense-detail-v178','from',p_from,'to',p_to,'group',p_group,'subgroup',p_subgroup,
  'total',(SELECT round(coalesce(sum(amount),0),2) FROM r),'row_count',(SELECT count(*) FROM r),
  'matched_count',(SELECT count(*) FROM filtered),'matched_total',(SELECT round(coalesce(sum(amount),0),2) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'revision',(SELECT md5(coalesce(string_agg(row_key||':'||amount::text||':'||description||':'||category||':'||management_group||':'||coalesce(beneficiary,''),'|' ORDER BY row_key),'')) FROM r),
  'rows',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'key',p.row_key,'date',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.purchase_date ELSE p.event_date END,
   'event_date',p.event_date,'transaction_date',p.transaction_date,'period',p.competence_month,
   'date_kind',CASE WHEN (p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%') AND p.purchase_date IS NULL THEN 'month' ELSE 'day' END,
   'description',p.description,'account_source',p.account_source,'beneficiary',p.beneficiary,'reference',p.raw_reference,
   'amount',p.amount,'category',p.management_group,'current_category',p.category,'component',p.property_component,
   'subgroup',p.management_subgroup,'status',p.identity_status,'property_code',p.property_code,'source_table',p.source_table,'source_ref',p.source_ref,
   'coverage_mode',p.coverage_mode,'can_classify',p.coverage_mode NOT IN ('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235'),
   'invoice_family',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN coalesce(public.lts_card_family_v226(p.account_source,p.account_source),(SELECT public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND p.source_table='lts_open_finance_staging' AND s.id::text=p.source_ref LIMIT 1)) END,
   'invoice_month',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.competence_month END,
   'document_status',CASE WHEN p.coverage_mode='card_invoice_aggregate_fallback' THEN 'composition_missing' END,
   'source_audit',CASE WHEN a.source_ref IS NOT NULL THEN jsonb_build_object(
    'file',a.source_file,'sheet',a.source_sheet,'rows',a.source_rows,'source_amount',a.source_signed_amount,
    'status',CASE WHEN a.source_signed_amount<0 THEN 'signed_adjustment' ELSE a.composition_status END,
    'detail_rows',a.detail_rows,'detail_total',a.detail_total,'difference',a.detail_difference,
    'note',CASE WHEN a.source_signed_amount<0 THEN 'Ajuste negativo registrado na planilha; não é nova compra nem comprovação de crédito bancário.'
     WHEN a.composition_status='unreconciled_detail' THEN 'A composição já foi recebida na planilha, mas ainda difere do total desta fatura.'
     ELSE 'A planilha registra o total ou parte da fatura. As compras individuais não foram localizadas nas fontes conferidas.' END) END,
   'source_identity',CASE WHEN e.source_ref IS NOT NULL THEN jsonb_build_object('category',e.original_category,'description',e.original_description,'sheet',e.source_sheet,'rows',e.source_rows,'note','Categoria conferida com a planilha original.') END,
   'review_question',CASE WHEN p.identity_status='pending' THEN 'Confirme a classificação deste lançamento.' END
  ) ORDER BY p.event_date DESC,p.amount DESC,p.row_key) FROM page p LEFT JOIN public.lts_card_history_source_audit_v235 a ON a.user_id=u
 AND a.source_table=p.source_table AND a.source_ref=p.source_ref AND a.event_date=p.event_date
 AND a.source_signed_amount=round(p.amount,2)
 LEFT JOIN public.lts_workbook_identity_evidence_v232 e ON e.user_id=u AND e.source_table=p.source_table AND e.source_ref=p.source_ref),'[]'::jsonb),
  'components',coalesce((SELECT jsonb_agg(x ORDER BY total DESC,name) FROM (SELECT management_subgroup name,round(sum(amount),2) total,count(*) rows FROM r GROUP BY 1)x),'[]'::jsonb)
 ) INTO result;
 RETURN result;
END $function$
;
