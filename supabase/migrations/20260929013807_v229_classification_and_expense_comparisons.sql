-- One identity for newly observed bank expenses, review, detail and the ledger.
CREATE FUNCTION public.lts_v229_new_bank_rows(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(id uuid,event_date date,signed_amount numeric,description text,bank text,category text)
LANGUAGE sql SET search_path='' SET timezone='America/Sao_Paulo' AS $$
WITH anchors AS MATERIALIZED (
 SELECT institution bank,max((metadata->>'balance_as_of')::date) dt FROM public.accounts
 WHERE user_id=p_user_id AND is_active AND metadata->>'evidence_sha256' IS NOT NULL GROUP BY institution
), context AS MATERIALIZED (
 SELECT public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date) events
), candidates AS MATERIALIZED (
 SELECT s.*,a.bank FROM public.lts_open_finance_staging s JOIN anchors a ON a.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.signed_amount<0 AND s.posting_date>a.dt AND s.posting_date BETWEEN p_from AND least(p_to,current_date)
 AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match m WHERE m.user_id=p_user_id AND m.staging_id=s.id)
)
SELECT s.id,s.posting_date,s.signed_amount,s.description_raw,s.bank,coalesce(rule.category,'A classificar')
FROM candidates s CROSS JOIN context c
LEFT JOIN LATERAL (
 SELECT CASE WHEN count(DISTINCT r.category)=1 THEN min(r.category) END category
 FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id AND r.active AND r.confidence IN ('user_confirmed','high','alta')
 AND NOT r.is_internal_transfer AND NOT r.is_asset_movement
 AND ((r.match_type='exact' AND public.lts_v178_norm(r.match_value)=public.lts_v178_norm(s.description_raw))
 OR (r.match_type='prefix' AND starts_with(public.lts_v178_norm(s.description_raw),public.lts_v178_norm(r.match_value))))
) rule ON true
WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.events) e WHERE e->>'account'=s.bank AND (e->>'event_date')::date=s.posting_date
 AND (e->>'signed_amount')::numeric=s.signed_amount
 AND (e->>'open_finance_id'=s.id::text OR public.lts_v178_norm(e->>'description')=public.lts_v178_norm(s.description_raw)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
 WHERE z->>'ref' IN (e->>'source_ref',(e->>'source')||':'||(e->>'source_ref')))));
$$;
CREATE OR REPLACE FUNCTION public.lts_v229_expense_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with new_bank as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)), b as materialized(
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
CREATE OR REPLACE FUNCTION public.lts_v229_review_rows(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH expense AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(p_user_id,p_from,p_to)), cards AS MATERIALIZED(
 SELECT * FROM public.lts_card_source_rows_v226(p_user_id) WHERE NOT is_payment AND amount>0
 AND purchase_date BETWEEN p_from AND least(p_to,current_date) AND public.lts_v178_norm(category) IN ('a classificar','sem categoria','nao identificado')
)
SELECT * FROM expense
UNION ALL
SELECT 'lts_open_finance_staging:'||c.source_id::text,c.purchase_date,c.posting_date,coalesce(c.reference_month,date_trunc('month',c.purchase_date)::date),
 c.amount,c.category,null,c.description,c.card_name,'lts_open_finance_staging',c.source_id::text,'card_observed_purchase',c.category,null,c.purchase_date,'pending','A classificar',c.category,null,null
FROM cards c WHERE NOT EXISTS(SELECT 1 FROM expense e WHERE e.source_table='lts_open_finance_staging' AND e.source_ref=c.source_id::text)
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_queue_v229(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  ), page as (
    select * from filtered
    order by event_date desc,amount desc,row_key
    offset p_offset limit p_limit
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
      'suggestion',(SELECT CASE WHEN count(DISTINCT category)=1 THEN jsonb_build_object('category',min(category),'basis','confirmed_history') END
        FROM public.financial_events h WHERE h.user_id=v_uid AND NOT h.is_suppressed AND NOT h.is_projection
        AND public.lts_v178_norm(h.description_raw)=public.lts_v178_norm(page.description)
        AND public.lts_v178_norm(h.category) NOT IN ('a classificar','nao identificado','sem categoria'))
    ) order by event_date desc,amount desc,row_key) from page),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_decision_v229(p_source_table text, p_source_ref text, p_beneficiary text DEFAULT NULL::text, p_property_code text DEFAULT NULL::text, p_category_label text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_source_table text:=nullif(trim(coalesce(p_source_table,'')),'');
  v_source_ref text:=nullif(trim(coalesce(p_source_ref,'')),'');
  v_beneficiary text:=nullif(trim(coalesce(p_beneficiary,'')),'');
  v_property text:=nullif(trim(coalesce(p_property_code,'')),'');
  v_category text:=nullif(trim(coalesce(p_category_label,'')),'');
  v_before jsonb;
  v_target record;
  v_resolved boolean;
begin
  if v_source_table is null or v_source_ref is null then raise exception 'source required'; end if;
  if v_beneficiary is null and v_property is null and v_category is null then raise exception 'decision required'; end if;
  if v_beneficiary is not null and v_beneficiary not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'invalid beneficiary'; end if;
  if v_property is not null and v_property not in ('cipo396','other_property','not_property') then raise exception 'invalid property'; end if;
  if v_category is not null and length(v_category)>120 then raise exception 'invalid category'; end if;

  select * into v_target
  from public.lts_v229_review_rows(v_uid,date '2013-10-10',current_date) r
  where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  order by r.event_date desc
  limit 1;
  if not found then raise exception 'pending review item not found'; end if;

  if v_category is not null and not exists (
    select 1
    from public.lts_v229_review_rows(v_uid,date '2013-10-10',current_date) r
    where r.category=v_category or r.management_group=v_category or r.management_subgroup=v_category
  ) and not exists (
    select 1
    from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) then raise exception 'unknown category'; end if;

  select to_jsonb(d) into v_before
  from public.lts_v178_review_decision d
  where d.user_id=v_uid and d.source_table=v_source_table and d.source_ref=v_source_ref;

  insert into public.lts_v178_review_decision(
    user_id,source_table,source_ref,beneficiary,property_code,category_label,decision_basis,decided_at
  ) values (
    v_uid,v_source_table,v_source_ref,v_beneficiary,v_property,v_category,'authenticated_user_v229',now()
  )
  on conflict(user_id,source_table,source_ref) do update set
    beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),
    property_code=coalesce(excluded.property_code,lts_v178_review_decision.property_code),
    category_label=coalesce(excluded.category_label,lts_v178_review_decision.category_label),
    decision_basis=excluded.decision_basis,
    decided_at=excluded.decided_at;

  select not exists(
    select 1 from public.lts_v229_review_rows(v_uid,date '2013-10-10',current_date) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  ) into v_resolved;
  if not v_resolved then raise exception 'A decisão não resolveu a pendência; nenhuma alteração foi mantida.'; end if;

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(v_uid,v_email,'browser_expense_review_decision_v181',jsonb_build_object(
    'source_table',v_source_table,'source_ref',v_source_ref,
    'before',v_before,
    'after',jsonb_build_object('beneficiary',v_beneficiary,'property_code',v_property,'category_label',v_category),
    'resolved',v_resolved
  ));

  return jsonb_build_object(
    'ok',true,'resolved',v_resolved,'source_table',v_source_table,'source_ref',v_source_ref,
    'display_contract',case when v_beneficiary='Lucas' then 'owner_category_without_prefix' else 'named_person_when_explicit' end
  );
end
$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_expense_detail_v229(p_from date, p_to date, p_group text DEFAULT NULL::text, p_subgroup text DEFAULT NULL::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 500, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 if p_from is null or p_to is null or p_from>p_to or p_to>current_date or p_from<date '2013-10-10' or p_offset<0 or p_limit not between 1 and 500 then raise exception 'invalid detail range'; end if;
 with r as materialized(select * from public.lts_v229_expense_rows(u,p_from,p_to) x where (p_group is null or x.management_group=p_group or (p_group='Identificações pendentes' and x.identity_status='pending')) and(p_subgroup is null or x.management_subgroup=p_subgroup)),
 filtered as materialized(select * from r where nullif(trim(p_query),'') is null or strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,beneficiary,raw_reference,category)),public.lts_v178_norm(trim(p_query)))>0),
 page as(select * from filtered order by event_date desc,amount desc,row_key offset p_offset limit p_limit)
 select jsonb_build_object('version','expense-detail-v178','from',p_from,'to',p_to,'group',p_group,'subgroup',p_subgroup,
 'total',(select round(coalesce(sum(amount),0),2)from r),'row_count',(select count(*)from r),'matched_count',(select count(*)from filtered),'matched_total',(select round(coalesce(sum(amount),0),2)from filtered),'offset',p_offset,
 'next_offset',case when p_offset+p_limit<(select count(*)from filtered)then p_offset+p_limit end,
 'revision',(select md5(coalesce(string_agg(row_key||':'||amount::text||':'||description,'|' order by row_key),''))from r),
 'rows',coalesce((select jsonb_agg(jsonb_build_object('key',row_key,'date',case when source_table like '%card%' or coverage_mode like 'card_%' then purchase_date else event_date end,'period',competence_month,'date_kind',case when (source_table like '%card%' or coverage_mode like 'card_%')and purchase_date is null then 'month' else 'day' end,'description',description,'account_source',account_source,'beneficiary',beneficiary,'reference',raw_reference,'amount',amount,'category',management_group,'component',property_component,'subgroup',management_subgroup,'status',identity_status,'review_question',case when identity_status<>'pending' then null when beneficiary is null and category ~* 'saúde|saude|educa|vestu' then 'De quem é esta despesa?' when management_group='Moradia — imóvel a confirmar' then 'A que imóvel se refere?' when property_component='A revisar' then 'Qual é a finalidade deste gasto no imóvel?' when description in ('Não identificado','Descrição pendente') then 'Qual é a descrição deste lançamento?' else 'Qual é a pessoa ou classificação correta?' end)order by event_date desc,amount desc,row_key)from page),'[]'::jsonb),
 'components',coalesce((select jsonb_agg(x order by total desc,name)from(select management_subgroup as name,round(sum(amount),2)total,count(*)as rows from r group by management_subgroup)x),'[]'::jsonb)
 )into result;
 return result;
end $function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_monthly_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); b jsonb; groups jsonb; computed numeric;
begin
 if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10' or p_to>current_date then raise exception 'invalid monthly range'; end if;
 b:=public.lts_browser_monthly_balance_v6(p_from,p_to);
 with r as materialized(select * from public.lts_v229_expense_rows(u,p_from,p_to)),
 months as(select (m#>>'{}')::date as month_key from jsonb_array_elements(b->'months')m),
 a as(select management_group as label,competence_month as month_key,sum(amount) amount,count(*) source_rows from r where coverage_mode<>'card_invoice_aggregate_fallback' group by 1,2),
 labels as(select label,sum(amount)total,sum(source_rows)source_rows from a group by label)
 select coalesce(jsonb_agg(jsonb_build_object('label',l.label,'total',round(l.total,2),'source_rows',l.source_rows,'monthly',(select jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) order by m.month_key)from months m left join a on a.month_key=m.month_key and a.label=l.label))order by l.total desc,l.label),'[]'::jsonb),(select round(coalesce(sum(amount),0),2)from r)
 into groups,computed from labels l;
 if abs(computed-coalesce((b#>>'{totals,expenses}')::numeric,0))>0.01 then raise exception 'monthly source total does not reconcile'; end if;
 return b||jsonb_build_object('version','monthly-v178-person-integrity','expense_groups',groups,'expense_total_verified',computed);
end $function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_expenses_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10' or p_to>current_date then raise exception 'invalid expense range'; end if;
 with all_rows as materialized(select * from public.lts_v229_expense_rows(u,least(p_from,(date_trunc('month',p_to)-interval '11 months')::date),p_to)),
 r as materialized(select * from all_rows where event_date between p_from and p_to),
 comparison as(select
  sum(amount) filter(where event_date>=date_trunc('month',p_to)::date) current_total,
  sum(amount) filter(where event_date between (date_trunc('month',p_to)-interval '1 month')::date
    and least(date_trunc('month',p_to)::date-1,(date_trunc('month',p_to)-interval '1 month')::date+extract(day from p_to)::int-1)) previous_total,
  sum(amount) filter(where event_date>=(date_trunc('month',p_to)-interval '11 months')::date) last_12m from all_rows),
 g as(select management_group as name,round(sum(amount),2) total,count(*) as rows,count(*) filter(where identity_status='pending') pending from r group by 1),
 sg as(select management_group,management_subgroup as name,round(sum(amount),2) total,count(*) as rows from r group by 1,2),
 monthly as(select competence_month as month_key,round(sum(amount),2) total,count(*) as rows from r group by 1)
 select jsonb_build_object(
 'version','expense-executive-v229-consistent-comparisons','as_of',current_date,
 'comparison',(select jsonb_build_object('current_total',current_total,'previous_total',previous_total,
  'variation_pct',case when previous_total<>0 and current_total is not null then round((current_total/previous_total-1)*100,2) end,
  'partial',p_to<(date_trunc('month',p_to)+interval '1 month')::date-1,'basis','same_elapsed_days') from comparison),
 'period',jsonb_build_object('from',p_from,'to',p_to,'label',case when p_from=date '2013-10-10' then 'Desde 2013'
  when p_from=make_date(extract(year from p_to)::int,1,1) then 'Ano '||extract(year from p_to)::int::text
  else to_char(p_from,'DD/MM/YYYY')||' → '||to_char(p_to,'DD/MM/YYYY') end,'last_available',(select max(event_date)from r),'months_in_selection',(extract(year from p_to)::int-extract(year from p_from)::int)*12+extract(month from p_to)::int-extract(month from p_from)::int+1),
 'summary',(select jsonb_build_object('last_12m',(select last_12m from comparison),'selected_total',round(coalesce(sum(amount),0),2),'card_total',round(coalesce(sum(amount) filter(where source_table like '%card%' or coverage_mode like 'card_%'),0),2),'rows',count(*),'pending_identification',count(*) filter(where identity_status='pending'))from r),
 'management_groups',coalesce((select jsonb_agg(jsonb_build_object('name',g.name,'total',g.total,'rows',g.rows,'pending',g.pending,'subgroups',coalesce((select jsonb_agg(jsonb_build_object('name',sg.name,'total',sg.total,'rows',sg.rows)order by sg.total desc,sg.name)from sg where sg.management_group=g.name),'[]'::jsonb)) order by g.total desc,g.name)from g),'[]'::jsonb),
 'monthly_detail',coalesce((select jsonb_agg(jsonb_build_object('month',month_key,'total',total,'rows',rows)order by month_key)from monthly),'[]'::jsonb),
 'coverage_disclosure',(select jsonb_build_object('total',round(coalesce(sum(amount),0),2),'rows',count(*))from r where coverage_mode='card_invoice_aggregate_fallback'),
 'revision',(select md5(coalesce(string_agg(row_key||':'||amount::text||':'||management_group,'|' order by row_key),''))from r)
 ) into result;
 result:=jsonb_set(result,'{summary,account_total}',to_jsonb((result#>>'{summary,selected_total}')::numeric-(result#>>'{summary,card_total}')::numeric),true);
 result:=jsonb_set(result,'{summary,monthly_average}',to_jsonb(round((result#>>'{summary,selected_total}')::numeric/greatest((result#>>'{period,months_in_selection}')::int,1),2)),true);
 return result;
end $function$
;
CREATE FUNCTION public.lts_flow_review_overlay_v229(p_user_id uuid,p_flow jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE part text; ev jsonb;
BEGIN
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  SELECT coalesce(jsonb_agg(e||CASE WHEN d.source_ref IS NULL THEN '{}'::jsonb ELSE jsonb_build_object(
   'category',coalesce(d.category_label,e->>'category'),'center_cost',coalesce(d.beneficiary,e->>'center_cost'),'classification_confirmed',true) END ORDER BY e->>'event_date',e->>'source_ref'),'[]') INTO ev
  FROM jsonb_array_elements(coalesce(p_flow#>ARRAY[part,'events'],'[]')) e
  LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_ref=coalesce(e->>'open_finance_id',e->>'source_ref')
  AND d.source_table=CASE WHEN e->>'source'='open_finance' OR e->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
   WHEN e->>'source'='current_event' THEN 'daily_flow_documentary_bridge' ELSE e->>'source' END;
  p_flow:=jsonb_set(p_flow,ARRAY[part,'events'],ev,true);
 END LOOP;
 RETURN p_flow;
END $$;
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_flow_v229(date,date)'::regprocedure);
 definition:=replace(definition,'RETURN result||jsonb_build_object(''flow'',f,','RETURN result||jsonb_build_object(''flow'',public.lts_flow_review_overlay_v229(u,f),');
 EXECUTE definition;
END $$;
REVOKE ALL ON FUNCTION public.lts_v229_new_bank_rows(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v229_new_bank_rows(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_v229_review_rows(uuid,date,date) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v229_review_rows(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION public.lts_flow_review_overlay_v229(uuid,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_review_overlay_v229(uuid,jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.lts_browser_expense_review_decision_v229(text,text,text,text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_review_decision_v229(text,text,text,text,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.lts_browser_monthly_v229(date,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_monthly_v229(date,date) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.lts_browser_expenses_v229(date,date) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expenses_v229(date,date) TO authenticated,service_role;
