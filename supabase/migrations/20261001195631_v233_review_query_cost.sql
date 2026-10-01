-- Provider invoice identity, reused by every cycle and current Flow overlay.
CREATE INDEX IF NOT EXISTS lts_of_invoice_identity_v233 ON public.lts_open_finance_staging
 (user_id,institution_code,((normalized_payload->>'provider_id'))) WHERE resource_type='invoice';

CREATE OR REPLACE FUNCTION public.lts_expense_rows_v230_baseline(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with person_rules as materialized (
 select public.lts_v178_norm(match_value) match_key,match_type,center_cost
 from public.lts_semantic_rule where user_id=p_user_id and active
 and center_cost in ('Lucas','Larissa','Benjamin','Rafiki') and confidence in ('high','alta')
), new_bank as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)), b as materialized(
 select x.event_date,x.transaction_date,x.competence_month,x.amount,
 case when public.lts_v178_norm(x.category)='a classificar' and source.category is not null
 then case when public.lts_v178_norm(source.category)='financiamento imovel' then 'Financiamento imobiliário' else source.category end
 else x.category end category,
 x.center_cost,x.counterparty,x.origin_type,x.origin_name,x.source_table,x.source_ref,x.coverage_mode,x.is_property,x.is_financing
 from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x
 left join lateral (
   select case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
   from public.financial_events e
   where x.source_table='daily_flow_documentary_bridge' and e.user_id=p_user_id
     and (e.id::text=x.source_ref or e.legacy_id=x.source_ref)
     and public.lts_v178_norm(e.category) not in ('a classificar','não identificado','nao identificado')
 ) source on true
 union all
 select n.event_date,n.event_date,date_trunc('month',n.event_date)::date,-n.signed_amount,n.category,
 'Não atribuído',n.description,'bank',n.bank,'lts_open_finance_staging',n.id::text,'bank_observed_individual',false,false from new_bank n
), src as materialized(
 select 'evento_base'::text st,e.idx::text sr, e.dados->>'desc' descr,
 coalesce(e.dados->>'categoria',e.dados->>'cat') cat,
 coalesce(e.dados->>'center_cost',e.dados->>'cost_center',e.dados->>'centro_custo') person,
 null::date purchased,e.dados meta,1 priority
 from public.evento_base e where e.usuario_id=p_user_id
 union all
 select 'historico_analitico',e.idx::text,e.dados->>'desc',coalesce(e.dados->>'categoria',e.dados->>'cat'),
 coalesce(e.dados->>'center_cost',e.dados->>'cost_center',e.dados->>'centro_custo'),null,e.dados,1
 from public.historico_analitico e where e.usuario_id=p_user_id
 union all
 select 'evento_usuario',e.id::text,e.dados->>'desc',e.dados->>'categoria',
 coalesce(e.dados->>'center_cost',e.dados->>'cost_center',e.dados->>'centro_custo'),null,e.dados,1
 from public.evento_usuario e where e.usuario_id=p_user_id
 union all
 select 'daily_flow_documentary_bridge',k.ref,e.description_raw,e.category,
 coalesce(e.metadata->>'cost_center',e.metadata->>'center_cost',e.metadata#>>'{classification_h_answers_20260914,center_cost}',e.metadata#>>'{user_classification_20260913,beneficiary}'),
 null,e.metadata,case when k.ref=e.id::text then 1 else 2 end
 from public.financial_events e cross join lateral (select e.id::text ref union select e.legacy_id where e.legacy_id is not null) k where e.user_id=p_user_id
 union all
 select 'card_purchase_detail',k.ref,e.description_raw,e.category,null,e.purchase_date,jsonb_build_object('note',e.note),case when k.ref=e.line_key then 1 else 2 end
 from public.lts_card_purchase_detail e cross join lateral(select e.line_key ref union select e.purchase_key where e.purchase_key is not null)k where e.user_id=p_user_id
 union all
 select 'lts_card_history_recovered_purchase',e.source_hash,e.description_raw,e.category_raw,
 coalesce(e.evidence->>'center_cost',e.evidence->>'cost_center'),null,e.evidence,1
 from public.lts_card_history_recovered_purchase e where e.user_id=p_user_id
 union all
 select 'lts_card_historical_category_allocation',e.ledger_source_ref||':'||e.id::text,e.category_raw,e.category_raw,null,null,e.evidence,1
 from public.lts_card_historical_category_allocation e where e.user_id=p_user_id
 union all
 select 'lts_v175_workbook_monthly_category_source',e.id::text,e.category_raw,e.category_raw,e.parent_group,null,'{}'::jsonb,1
 from public.lts_v175_workbook_monthly_category_source e where e.user_id=p_user_id
 union all
 select 'lts_document_card_purchase',e.id::text,e.description,e.category,e.cost_center,e.purchase_date,e.metadata,1
 from public.lts_document_card_purchase e where e.user_id=p_user_id
 union all
 select 'lts_manual_card_purchase',e.id::text,e.description,e.category,e.cost_center,e.purchase_date,e.metadata,1
 from public.lts_manual_card_purchase e where e.user_id=p_user_id
 union all
 select 'card_invoice_current_items',e.id::text||':'||(i.x->>'source_line'),i.x->>'description',i.x->>'category',
 coalesce(i.x->>'center_cost',i.x->>'cost_center'),case when i.x->>'purchase_date' ~ '^\d{4}-\d{2}-\d{2}$' then (i.x->>'purchase_date')::date end,i.x,1
 from public.card_invoices e cross join lateral jsonb_array_elements(coalesce(e.metadata->'items','[]')) i(x) where e.user_id=p_user_id
 union all
 select 'lts_open_finance_staging',r.source_id::text,r.description,r.category,null,r.purchase_date,
 jsonb_build_object('category_basis',r.category_basis,'last4',r.last4),1
 from public.lts_card_source_rows_v226(p_user_id) r
 union all
 select 'lts_open_finance_staging',n.id::text,n.description,n.category,null,null,'{}'::jsonb,1 from new_bank n
), source_unique as materialized(
 select distinct on(st,sr) *,public.lts_v178_norm(descr) description_key from src where sr is not null order by st,sr,priority,descr,cat
), enriched as materialized(
 select b.*,coalesce(nullif(s.descr,''),nullif(b.counterparty,'Não identificado'),nullif(b.category,''),'Descrição pendente') descr,
 coalesce(nullif(s.cat,''),b.category) original_category,coalesce(case when public.lts_v178_norm(s.person) ~ '^benjamin([[:space:]—-]|$)' then 'Benjamin' when public.lts_v178_norm(s.person) ~ '^larissa([[:space:]—-]|$)' then 'Larissa' when public.lts_v178_norm(s.person) ~ '^lucas([[:space:]—-]|$)' then 'Lucas' when public.lts_v178_norm(s.person)='rafiki' then 'Rafiki' end,pr.person) person_hint,s.purchased,s.meta,
 d.beneficiary person_decision,d.property_code property_decision,d.category_label category_decision,
 public.lts_v178_norm(concat_ws(' ',b.category,s.cat)) category_norm,
 public.lts_v178_norm(concat_ws(' ',s.descr,b.counterparty)) desc_norm
 from b left join source_unique s on s.st=b.source_table and s.sr=b.source_ref
 left join lateral (select case when count(distinct sr.center_cost)=1 then min(sr.center_cost) end person from person_rules sr where ((sr.match_type='exact' and sr.match_key=s.description_key) or (sr.match_type='prefix' and s.description_key like sr.match_key||'%'))) pr on true
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table=b.source_table and d.source_ref=b.source_ref
), person_rows as materialized(
 select e.*,
 case
 when person_decision is not null then person_decision
 when public.lts_v178_norm(original_category) ~ '^benjamin(\s|[-—])' or public.lts_v178_norm(category) ~ '^benjamin(\s|[-—])' then 'Benjamin'
 when public.lts_v178_norm(original_category) ~ '^larissa(\s|[-—])' or public.lts_v178_norm(category) ~ '^larissa(\s|[-—])' then 'Larissa'
 when public.lts_v178_norm(original_category) ~ '^lucas(\s|[-—])' then 'Lucas'
 when center_cost in ('Lucas','Larissa','Benjamin','Rafiki') then center_cost
 when person_hint in ('Lucas','Larissa','Benjamin','Rafiki') then person_hint
 when category_norm ~ 'educa' and desc_norm ~ 'english class' then 'Lucas'
 when category_norm ~ 'educa' and desc_norm ~ '(escolinha|escola) das acacias' then 'Benjamin'
 when category_norm ~ 'saude' and desc_norm ~ 'beep saude' and event_date<=date '2026-09-20' then 'Benjamin'
 when public.lts_v178_norm(category) in ('larissa','familia') and public.lts_v178_norm(counterparty)='larissa' then 'Larissa'
 when category_norm ~ '^rafiki|^pet$' then 'Rafiki'
 else null end person_final,
 case
 when category_decision is not null then category_decision
 when category_norm ~ 'saude' then 'Saúde'
 when category_norm ~ 'educa' then 'Educação'
 when category_norm ~ 'vestuario' then 'Vestuário'
 else regexp_replace(case when public.lts_v178_norm(category) ~ '^(benjamin|larissa|lucas)\s*[-—]' then category else coalesce(original_category,category) end,'^(Benjamin|Larissa|Lucas)\s*[-—]\s*','','i') end kind,
 public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 coalesce(property_decision,
 case when (public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) in ('Financiamento imobiliário','Investimento no imóvel — aquisição e histórico','Investimentos no imóvel — obra e reforma','Moradia','Condomínio','Energia','Impostos do imóvel') or public.lts_v178_norm(category) in ('seguro residencial','aluguel')) and public.lts_v178_norm(concat_ws(' ',original_category,descr,counterparty)) ~ '(^|[^[:alnum:]])(o parque|cipo[[:space:]]*396)([^[:alnum:]]|$)' and not (source_table='historico_analitico' and desc_norm !~ '(^|[^[:alnum:]])(o parque|cipo[[:space:]]*396)([^[:alnum:]]|$)') then 'cipo396'
 when public.lts_v178_norm(category) ~ '^financiamento imobiliario' then 'cipo396'
 when coalesce(meta#>>'{classification_recovery,basis}','')='replace_legacy_condominio_2026_09_05' then 'cipo396'
 end) prop
 from enriched e
), labeled as materialized(
 select p.*,
 case when prop='cipo396' then
   case when old_group in ('Financiamento imobiliário','Investimento no imóvel — aquisição e histórico') or category_norm ~ 'consorcio|corretagem' then 'Aquisição do imóvel'
        when old_group='Investimentos no imóvel — obra e reforma' then 'Obra e reforma'
        when category_norm ~ 'iptu|impostos do imovel' then 'Impostos do imóvel'
        when old_group in ('Moradia','Condomínio','Energia') or category_norm ~ 'enel|energia|seguro residencial' then 'Custos de moradia'
        else 'A revisar' end
 end prop_component,
 case
 when old_group='Empréstimos' then old_group
 when person_final='Rafiki' then 'Rafiki'
 when person_final is not null and (category_norm ~ 'saude|educa|vestuario' or public.lts_v178_norm(original_category) ~ '^(benjamin|larissa|lucas)\s*[-—]' or public.lts_v178_norm(category) ~ '^(benjamin|larissa|lucas)\s*[-—]') then case when person_final='Lucas' then kind else person_final||' — '||kind end
 when person_final='Larissa' and public.lts_v178_norm(category) in ('familia','larissa') then 'Larissa — despesas'
 when person_final='Benjamin' and public.lts_v178_norm(category)='benjamin' then 'Benjamin — Outros'
 when person_final='Lucas' then case when public.lts_v178_norm(kind) in ('familia','lucas','larissa','benjamin') then 'Despesas' else kind end
 when person_final in ('Larissa','Benjamin') then person_final||' — '||case when public.lts_v178_norm(kind) in ('familia','lucas','larissa','benjamin') then 'despesas' else kind end
 when kind in ('Saúde','Educação','Vestuário') then kind
 when old_group='Família — saídas' then 'Outras saídas familiares — a revisar'
 when old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial') and prop is null then 'Moradia — imóvel a confirmar'
 else old_group end group_without_property
 from person_rows p
)
select source_table||':'||source_ref||':'||competence_month::text||':'||coalesce(category,''),event_date,transaction_date,competence_month,amount,
 coalesce(category_decision,category),person_final,descr,origin_name,source_table,source_ref,coverage_mode,original_category,
 concat_ws(' · ',nullif(center_cost,'Não atribuído'),nullif(counterparty,'Não identificado')),purchased,
 case when public.lts_v178_norm(coalesce(category_decision,category)) in ('a classificar','nao identificado','sem categoria') or group_without_property like '%a revisar' or prop_component='A revisar' or (kind in ('Saúde','Educação','Vestuário') and person_final is null) or (prop is null and old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial')) or descr in ('Não identificado','Descrição pendente') then 'pending' else 'identified' end,
 case when prop='cipo396' then 'Apartamento · CIPÓ 396' else group_without_property end,
 case when prop='cipo396' then prop_component
 when old_group='Empréstimos' then public.lts_expense_management_subgroup_v2(category,center_cost,counterparty,origin_name,coverage_mode)
 when person_final is not null then kind else category end,
 prop,prop_component
from labeled
$function$
;

-- Read the outstanding projections from their operational events. The review queue
-- needs no reconstructed balance, wealth ladder, full Flow or card classification.
CREATE FUNCTION public.lts_pending_projections_v233(p_user_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
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
SELECT coalesce(jsonb_agg(c.x ORDER BY c.x->>'event_date',c.x->>'source_ref'),'[]'::jsonb)
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
$function$;
REVOKE ALL ON FUNCTION public.lts_pending_projections_v233(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_queue_v229(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10'
     or p_to>current_date or p_offset<0 or p_limit not between 1 and 100 then
    raise exception 'invalid review queue range';
  end if;

  with pending as materialized (
    select r.*,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'person'
        when r.management_group='Moradia — imóvel a confirmar' then 'property'
        when r.property_component='A revisar' then 'property_purpose'
        else 'classification'
      end question_kind,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'De quem é esta despesa?'
        when r.management_group='Moradia — imóvel a confirmar' then 'A que imóvel se refere?'
        when r.property_component='A revisar' then 'Qual é a finalidade deste gasto no imóvel?'
        else 'Qual é a pessoa ou classificação correta?'
      end review_question
    from public.lts_v229_review_rows(v_uid,p_from,p_to) r
    where r.identity_status='pending'
  ), filtered as materialized (
    select * from pending
    where nullif(trim(p_query),'') is null
       or strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,category,management_group,raw_reference)),public.lts_v178_norm(trim(p_query)))>0
  ), page as materialized (
    select * from filtered
    order by event_date desc,amount desc,row_key
    offset p_offset limit p_limit
  ), suggestions AS MATERIALIZED (
    SELECT * FROM public.lts_review_suggestions_v231(v_uid,coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM page),'[]'))
  ), options as (
    select coalesce(payload#>'{card_classification_review,category_options}','[]'::jsonb) categories
    from public.lts_product_read_cache
    where user_id=v_uid
    order by refreshed_at desc limit 1
  )
  select jsonb_build_object(
    'version','expense-review-queue-v229',
    'from',p_from,'to',p_to,
    'row_count',(select count(*) from pending),
    'pending_projections',public.lts_pending_projections_v233(v_uid),
    'queue_breakdown',jsonb_build_object(
     'historical_context',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) NOT IN ('a classificar','sem categoria','nao identificado')),
     'classification_needed',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) IN ('a classificar','sem categoria','nao identificado')),
     'classification',(SELECT count(*) FROM pending WHERE question_kind='classification'),
     'person',(SELECT count(*) FROM pending WHERE question_kind='person'),
     'property',(SELECT count(*) FROM pending WHERE question_kind IN ('property','property_purpose'))),
    'matched_count',(select count(*) from filtered),
    'offset',p_offset,
    'next_offset',case when p_offset+p_limit<(select count(*) from filtered) then p_offset+p_limit end,
    'category_options',coalesce((select categories from options),'[]'::jsonb),
    'beneficiary_options',jsonb_build_array(
      jsonb_build_object('value','Lucas','label','Minha / sem prefixo'),
      jsonb_build_object('value','Benjamin','label','Benjamin'),
      jsonb_build_object('value','Larissa','label','Larissa'),
      jsonb_build_object('value','Rafiki','label','Rafiki')
    ),
    'property_options',jsonb_build_array(
      jsonb_build_object('value','cipo396','label','Apartamento · CIPÓ 396'),
      jsonb_build_object('value','other_property','label','Outro imóvel'),
      jsonb_build_object('value','not_property','label','Não é gasto de imóvel')
    ),
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'key',row_key,'source_table',source_table,'source_ref',source_ref,
      'date',event_date,'period',competence_month,'description',description,
      'account_source',account_source,'amount',amount,'category',category,
      'beneficiary',beneficiary,'management_group',management_group,
      'question_kind',question_kind,'review_question',review_question,
      'suggestion',(SELECT s.suggestion FROM suggestions s WHERE s.source_table=page.source_table AND s.source_ref=page.source_ref)
    ) order by event_date desc,amount desc,row_key) from page),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$
;
