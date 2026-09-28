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
    s.amount,
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
CREATE OR REPLACE FUNCTION public.lts_expense_effective_rows_v176(p_user_id uuid, p_from date DEFAULT '2013-10-10'::date, p_to date DEFAULT CURRENT_DATE)
 RETURNS TABLE(event_date date, transaction_date date, competence_month date, amount numeric, category text, center_cost text, counterparty text, origin_type text, origin_name text, source_table text, source_ref text, coverage_mode text, is_property boolean, is_financing boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as materialized(select * from public.lts_expense_effective_rows_v225_baseline(p_user_id,p_from,p_to)),
recovery as materialized(
 select r.* from public.lts_card_exact_recovery_v226(p_user_id,p_from,p_to) r join base b
 on b.source_table=r.replaced_source_table and b.source_ref=r.replaced_source_ref
 and b.coverage_mode='card_invoice_aggregate_fallback'
)
select b.* from base b where not exists(select 1 from recovery r where b.source_table=r.replaced_source_table and b.source_ref=r.replaced_source_ref)
union all
select event_date,transaction_date,competence_month,amount,category,center_cost,counterparty,
 origin_type,origin_name,source_table,source_ref,coverage_mode,is_property,is_financing from recovery
$function$;

CREATE OR REPLACE FUNCTION public.lts_v178_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with b as materialized(
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
), source_unique as materialized(
 select distinct on(st,sr) * from src where sr is not null order by st,sr,priority,descr,cat
), enriched as materialized(
 select b.*,coalesce(nullif(s.descr,''),nullif(b.counterparty,'Não identificado'),nullif(b.category,''),'Descrição pendente') descr,
 coalesce(nullif(s.cat,''),b.category) original_category,coalesce(case when public.lts_v178_norm(s.person) ~ '^benjamin([[:space:]—-]|$)' then 'Benjamin' when public.lts_v178_norm(s.person) ~ '^larissa([[:space:]—-]|$)' then 'Larissa' when public.lts_v178_norm(s.person) ~ '^lucas([[:space:]—-]|$)' then 'Lucas' when public.lts_v178_norm(s.person)='rafiki' then 'Rafiki' end,pr.person) person_hint,s.purchased,s.meta,
 d.beneficiary person_decision,d.property_code property_decision,d.category_label category_decision,
 public.lts_v178_norm(concat_ws(' ',b.category,s.cat)) category_norm,
 public.lts_v178_norm(concat_ws(' ',s.descr,b.counterparty)) desc_norm
 from b left join source_unique s on s.st=b.source_table and s.sr=b.source_ref
 left join lateral (select case when count(distinct sr.center_cost)=1 then min(sr.center_cost) end person from public.lts_semantic_rule sr where sr.user_id=p_user_id and sr.active and sr.center_cost in ('Lucas','Larissa','Benjamin','Rafiki') and sr.confidence in ('high','alta') and ((sr.match_type='exact' and public.lts_v178_norm(sr.match_value)=public.lts_v178_norm(s.descr)) or (sr.match_type='prefix' and public.lts_v178_norm(s.descr) like public.lts_v178_norm(sr.match_value)||'%'))) pr on true
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
REVOKE ALL ON FUNCTION public.lts_expense_effective_rows_v225_baseline(uuid,date,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_expense_effective_rows_v225_baseline(uuid,date,date) TO service_role;

