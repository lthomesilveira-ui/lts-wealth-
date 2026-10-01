-- Preserve the immutable expression inline inside hot readers. Keep public helper search_path locked.
CREATE OR REPLACE FUNCTION public.lts_card_family_v226(p_name text, p_bank text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
select case when n like '%aeternum%' then 'aeternum'
 when n like '%c6%' or n like '%bandeirado%' then 'c6'
 when n like '%visa%' and b like '%itau%' then 'itau_visa'
 when n like '%visa%' and b like '%bradesco%' then 'bradesco_prime'
 when n like '%mastercard%' or n like '%mc black%' or n like '%personnalite%' then 'itau_mastercard'
 end from (select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_name,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') n,pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(p_bank,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') b)x
$function$
;
CREATE OR REPLACE FUNCTION public.lts_card_source_rows_v226(p_user_id uuid)
 RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with installment_decisions as materialized (
 select public.lts_card_installment_key_v231(s) purchase_key,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)<=1 then min(d.category_label) end category,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)=1 then min(d.beneficiary) end person
 from public.lts_open_finance_staging s join public.lts_v178_review_decision d
 on d.user_id=s.user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
 where s.user_id=p_user_id and s.provider_deleted_at is null and d.category_label is not null
 group by public.lts_card_installment_key_v231(s)
), evidence as materialized (
 select public.lts_card_merchant_key_v226(p.description_raw) k,round(p.installment_amount,2) amount,
 coalesce(d.category_label,p.category) category,p.card_final last4,p.installments,
 p.invoice_due_date evidence_date,d.beneficiary person
 from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d
 on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
 where p.user_id=p_user_id
 union all
 select public.lts_card_merchant_key_v226(a.description_norm),round(a.amount,2),a.category,null,null,a.event_date,null
 from public.lts_semantic_amount_signature a where a.user_id=p_user_id and a.source_kind='card'
), exact_categories as materialized (
 select k,amount,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i'))=1
 then min(regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i')) end category
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 and k !~ 'mercado|amazon|shop|pagseguro|merpago' group by k
), rule_keys as materialized (
 select public.lts_card_merchant_key_v226(r.match_value) k,r.category,r.center_cost person,
 case when r.confidence='user_confirmed' then 0 else 1 end priority
 from public.lts_semantic_rule r where r.user_id=p_user_id and r.active and r.match_type='exact'
 and r.confidence in ('high','alta','system_high','user_confirmed')
), rule_categories as materialized (
 select k,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from (select *,dense_rank() over(partition by k order by priority) rank from rule_keys where k !~ '^(mercado|shopee|pagseguro|merpago)')q where rank=1 group by k
), src as materialized (
 select s.*,case s.institution_code when '237' then 'Bradesco' when '341' then 'Itaú' when '336' then 'C6' end bank,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 public.lts_card_merchant_key_v226(s.description_raw) merchant_key,
 public.lts_card_installment_key_v231(s) purchase_key,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 case when s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 then (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date end forecast,
 (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 or coalesce(s.raw_payload->>'category','')='Credit card payment'
 or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.description_raw,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)') payment
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='card_transaction'
 and s.provider_deleted_at is null
), open_cards as materialized (
 select distinct on (family) family,reference_month,due_date from (
  select public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family,i.reference_month,i.due_date
  from public.card_invoices i where i.user_id=p_user_id and i.status='open' and i.due_date>=current_date
 )q order by family,due_date
), dated as materialized (
 select s.*,b.posting_date bill_due,
 case when b.id is not null then date_trunc('month',b.posting_date)::date
 -- C6 reports the purchase month for its current open cycle. The document supplies the due month.
 when s.institution_code='336' and s.normalized_payload->>'status'='PENDING'
 and s.forecast<=date_trunc('month',current_date)::date then coalesce(c.reference_month,s.forecast)
 else s.forecast end cycle,
 c.due_date open_due
 from src s left join public.lts_open_finance_staging b on b.user_id=s.user_id
 and b.institution_code=s.institution_code and b.resource_type='invoice'
 and b.normalized_payload->>'provider_id'=s.raw_bill_id
 left join open_cards c on c.family=s.family
), classified as (
 select s.*,coalesce(d.category_label,ic.category,ec.category,sr.category,nc.category) known_category,coalesce(d.beneficiary,ic.person,ec.person,sr.person) known_person,
 case when d.category_label is not null then case when d.decision_basis like 'workbook_restore_v226%' then 'historical_workbook' else 'user_decision' end
 when ic.category is not null then 'confirmed_same_purchase_installments'
 when ec.category is not null then 'same_merchant_and_amount'
 when sr.category is not null then 'restored_explicit_rule'
 when nc.category is not null then 'historical_merchant_nature' end known_basis
 from dated s left join installment_decisions ic on ic.purchase_key=s.purchase_key
 left join exact_categories ec on ec.k=s.merchant_key and ec.amount=round(-s.signed_amount,2)
 left join nature_categories nc on nc.k=s.merchant_key
 left join rule_categories sr on sr.k=s.merchant_key
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
), provider_classification as (
 select c.*,case
 when c.raw_payload->>'category' in ('Credit card fees','Bank fees') then 'Tarifas bancárias'
 when c.raw_payload->>'category'='Tax on financial operations' then 'IOF'
 when c.merchant_key ~ '^(ifd|ifood)' and c.raw_payload->>'category' in ('Food delivery','Restaurants','Eating out','Groceries') then 'Ifood'
 when c.raw_payload->>'category'='Pharmacy' and c.merchant_key ~ 'drog|pharma|farma' then 'Farmácia'
 when c.raw_payload->>'category'='Groceries' and c.merchant_key ~ 'paodeacucar|obahortifruti|supermercado' then 'Mercado'
 when c.raw_payload->>'category' in ('Restaurants','Eating out') then 'Restaurantes'
 when c.raw_payload#>>'{creditCardMetadata,payeeMCC}'='5812' and c.merchant_key ~ 'bbq|restaur' then 'Restaurantes'
 when c.raw_payload->>'category'='Gas stations' and c.merchant_key ~ 'posto' then 'Combustível'
 when c.raw_payload->>'category'='Parking' and c.merchant_key ~ 'park|vallet|estacion' then 'Estacionamento e Pedágio'
 when c.raw_payload->>'category'='Healthcare' and c.merchant_key ~ '^(dr|clinica)' then 'Saúde'
 when c.raw_payload->>'category'='Clothing' and c.merchant_key ~ 'minimalclub|^ecreise|^paypalfrancagrif' then 'Vestuário'
 when c.raw_payload->>'category'='Tickets' and c.merchant_key ~ '^fevercandlelight' then 'Passeios'
 end provider_category from classified c
)
select s.id,s.bank,s.family,s.normalized_payload->>'card_name',
 coalesce(nullif(s.raw_payload#>>'{creditCardMetadata,cardNumber}',''),s.normalized_payload->>'last4'),
 s.normalized_payload->>'last4',s.posting_date,
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
 then left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date else s.posting_date end,
 s.cycle,coalesce(s.bill_due,case when date_trunc('month',s.open_due)::date=s.cycle then s.open_due end),
 s.normalized_payload->>'status',-s.signed_amount,s.description_raw,
 coalesce(case when s.known_person in ('Lucas','Larissa','Benjamin') and s.known_category is not null and s.known_category !~* '^(Lucas|Larissa|Benjamin)' then s.known_person||' — '||s.known_category else s.known_category end,s.provider_category,'A classificar'),
 coalesce(s.known_basis,case when s.provider_category is null then 'unresolved' when s.raw_payload->>'category' in ('Credit card fees','Bank fees','Tax on financial operations') then 'explicit_fee_type' else 'merchant_and_provider_category' end),
 case when s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer end,
 case when s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer end,
 s.payment,s.raw_bill_id,s.last_seen_at
from provider_classification s
$function$
;
CREATE OR REPLACE FUNCTION public.lts_expense_rows_v230_baseline(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with person_rules as materialized (
 select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(match_value,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') match_key,match_type,center_cost
 from public.lts_semantic_rule where user_id=p_user_id and active
 and center_cost in ('Lucas','Larissa','Benjamin','Rafiki') and confidence in ('high','alta')
), new_bank as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)), b as materialized(
 select x.event_date,x.transaction_date,x.competence_month,x.amount,
 case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(x.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='a classificar' and source.category is not null
 then case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(source.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='financiamento imovel' then 'Financiamento imobiliário' else source.category end
 else x.category end category,
 x.center_cost,x.counterparty,x.origin_type,x.origin_name,x.source_table,x.source_ref,x.coverage_mode,x.is_property,x.is_financing
 from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to) x
 left join lateral (
   select case when count(distinct nullif(trim(e.category),''))=1 then min(nullif(trim(e.category),'')) end category
   from public.financial_events e
   where x.source_table='daily_flow_documentary_bridge' and e.user_id=p_user_id
     and (e.id::text=x.source_ref or e.legacy_id=x.source_ref)
     and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(e.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('a classificar','não identificado','nao identificado')
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
 select distinct on(st,sr) *,pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(descr,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') description_key from src where sr is not null order by st,sr,priority,descr,cat
), enriched as materialized(
 select b.*,coalesce(nullif(s.descr,''),nullif(b.counterparty,'Não identificado'),nullif(b.category,''),'Descrição pendente') descr,
 coalesce(nullif(s.cat,''),b.category) original_category,coalesce(case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^benjamin([[:space:]—-]|$)' then 'Benjamin' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^larissa([[:space:]—-]|$)' then 'Larissa' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^lucas([[:space:]—-]|$)' then 'Lucas' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='rafiki' then 'Rafiki' end,pr.person) person_hint,s.purchased,s.meta,
 d.beneficiary person_decision,d.property_code property_decision,d.category_label category_decision,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(concat_ws(' ',b.category,s.cat),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') category_norm,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(concat_ws(' ',s.descr,b.counterparty),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') desc_norm
 from b left join source_unique s on s.st=b.source_table and s.sr=b.source_ref
 left join lateral (select case when count(distinct sr.center_cost)=1 then min(sr.center_cost) end person from person_rules sr where ((sr.match_type='exact' and sr.match_key=s.description_key) or (sr.match_type='prefix' and s.description_key like sr.match_key||'%'))) pr on true
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table=b.source_table and d.source_ref=b.source_ref
), person_rows as materialized(
 select e.*,
 case
 when person_decision is not null then person_decision
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^benjamin(\s|[-—])' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^benjamin(\s|[-—])' then 'Benjamin'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^larissa(\s|[-—])' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^larissa(\s|[-—])' then 'Larissa'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^lucas(\s|[-—])' then 'Lucas'
 when center_cost in ('Lucas','Larissa','Benjamin','Rafiki') then center_cost
 when person_hint in ('Lucas','Larissa','Benjamin','Rafiki') then person_hint
 when category_norm ~ 'educa' and desc_norm ~ 'english class' then 'Lucas'
 when category_norm ~ 'educa' and desc_norm ~ '(escolinha|escola) das acacias' then 'Benjamin'
 when category_norm ~ 'saude' and desc_norm ~ 'beep saude' and event_date<=date '2026-09-20' then 'Benjamin'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('larissa','familia') and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(counterparty,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='larissa' then 'Larissa'
 when category_norm ~ '^rafiki|^pet$' then 'Rafiki'
 else null end person_final,
 case
 when category_decision is not null then category_decision
 when category_norm ~ 'saude' then 'Saúde'
 when category_norm ~ 'educa' then 'Educação'
 when category_norm ~ 'vestuario' then 'Vestuário'
 else regexp_replace(case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(benjamin|larissa|lucas)\s*[-—]' then category else coalesce(original_category,category) end,'^(Benjamin|Larissa|Lucas)\s*[-—]\s*','','i') end kind,
 public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 coalesce(property_decision,
 case when (public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) in ('Financiamento imobiliário','Investimento no imóvel — aquisição e histórico','Investimentos no imóvel — obra e reforma','Moradia','Condomínio','Energia','Impostos do imóvel') or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('seguro residencial','aluguel')) and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(concat_ws(' ',original_category,descr,counterparty),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '(^|[^[:alnum:]])(o parque|cipo[[:space:]]*396)([^[:alnum:]]|$)' and not (source_table='historico_analitico' and desc_norm !~ '(^|[^[:alnum:]])(o parque|cipo[[:space:]]*396)([^[:alnum:]]|$)') then 'cipo396'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^financiamento imobiliario' then 'cipo396'
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
 when person_final is not null and (category_norm ~ 'saude|educa|vestuario' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(benjamin|larissa|lucas)\s*[-—]' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(benjamin|larissa|lucas)\s*[-—]') then case when person_final='Lucas' then kind else person_final||' — '||kind end
 when person_final='Larissa' and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','larissa') then 'Larissa — despesas'
 when person_final='Benjamin' and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='benjamin' then 'Benjamin — Outros'
 when person_final='Lucas' then case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(kind,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','lucas','larissa','benjamin') then 'Despesas' else kind end
 when person_final in ('Larissa','Benjamin') then person_final||' — '||case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(kind,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','lucas','larissa','benjamin') then 'despesas' else kind end
 when kind in ('Saúde','Educação','Vestuário') then kind
 when old_group='Família — saídas' then 'Outras saídas familiares — a revisar'
 when old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial') and prop is null then 'Moradia — imóvel a confirmar'
 else old_group end group_without_property
 from person_rows p
)
select source_table||':'||source_ref||':'||competence_month::text||':'||coalesce(category,''),event_date,transaction_date,competence_month,amount,
 coalesce(category_decision,category),person_final,descr,origin_name,source_table,source_ref,coverage_mode,original_category,
 concat_ws(' · ',nullif(center_cost,'Não atribuído'),nullif(counterparty,'Não identificado')),purchased,
 case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(coalesce(category_decision,category),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('a classificar','nao identificado','sem categoria') or group_without_property like '%a revisar' or prop_component='A revisar' or (kind in ('Saúde','Educação','Vestuário') and person_final is null) or (prop is null and old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial')) or descr in ('Não identificado','Descrição pendente') then 'pending' else 'identified' end,
 case when prop='cipo396' then 'Apartamento · CIPÓ 396' else group_without_property end,
 case when prop='cipo396' then prop_component
 when old_group='Empréstimos' then public.lts_expense_management_subgroup_v2(category,center_cost,counterparty,origin_name,coverage_mode)
 when person_final is not null then kind else category end,
 prop,prop_component
from labeled
$function$
;
CREATE OR REPLACE FUNCTION public.lts_review_suggestions_v231(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_table text, source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH targets AS MATERIALIZED (
 SELECT t.*,public.lts_card_merchant_key_v226(t.description) merchant_key,
  public.lts_bank_merchant_key_v231(t.description) bank_key,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}' last4,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END installments,
  left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) purchase_date
 FROM jsonb_to_recordset(p_targets) t(source_table text,source_ref text,description text,amount numeric,event_date date,category text,question_kind text)
 LEFT JOIN public.lts_open_finance_staging s ON t.source_table='lts_open_finance_staging' AND s.user_id=p_user_id AND s.id::text=t.source_ref
), raw_history AS MATERIALIZED (
 SELECT 'card_purchase_detail'::text st,p.line_key sr,p.description_raw description,p.category,p.installment_amount amount,
  p.invoice_due_date event_date,p.purchase_date,p.card_final last4,p.installments,null::text person,null::text property_code
 FROM public.lts_card_purchase_detail p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'financial_events',p.id::text,p.description_raw,p.category,abs(p.amount),p.event_date,null,null,null,
  coalesce(p.metadata->>'center_cost',p.metadata->>'cost_center',p.metadata#>>'{user_classification_20260913,beneficiary}'),null
 FROM public.financial_events p WHERE p.user_id=p_user_id AND NOT p.is_suppressed AND NOT p.is_projection
 UNION ALL
 SELECT 'lts_document_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_document_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_manual_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_manual_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_card_history_recovered_purchase',p.source_hash,p.description_raw,coalesce(p.canonical_category,p.category_raw),p.amount,p.invoice_due_date,
  null,p.card_final,null,p.evidence->>'center_cost',null FROM public.lts_card_history_recovered_purchase p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'card_invoice_current_items',p.id::text||':'||(i->>'source_line'),i->>'description',i->>'category',
  CASE WHEN coalesce(i->>'amount','') ~ '^-?[0-9]+([.][0-9]+)?$' THEN (i->>'amount')::numeric END,
  p.due_date,CASE WHEN i->>'purchase_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (i->>'purchase_date')::date END,
  coalesce(i->>'last4',i->>'card_final'),CASE WHEN i->>'total_installments' ~ '^[0-9]+$' THEN (i->>'total_installments')::int END,
  coalesce(i->>'cost_center',i->>'center_cost'),null
 FROM public.card_invoices p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.metadata->'items','[]')) i WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'lts_open_finance_staging',s.id::text,s.description_raw,d.category_label,abs(s.signed_amount),s.posting_date,
  CASE WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date END,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}',CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END,
  d.beneficiary,d.property_code
 FROM public.lts_open_finance_staging s JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 WHERE s.user_id=p_user_id AND s.provider_deleted_at IS NULL
 UNION ALL
 SELECT 'historico_analitico',h.idx::text,h.dados->>'desc',coalesce(h.dados->>'categoria',h.dados->>'cat'),
  abs((h.dados->>'valor')::numeric), (h.dados->>'dia')::date,null,null,null,coalesce(h.dados->>'center_cost',h.dados->>'cost_center'),null
 FROM public.historico_analitico h WHERE h.usuario_id=p_user_id AND h.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$'
  AND h.dados->>'dia' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
), history AS MATERIALIZED (
 SELECT h.*,coalesce(d.category_label,h.category) decided_category,
  coalesce(d.beneficiary,h.person,substring(coalesce(d.category_label,h.category) from '^(Lucas|Larissa|Benjamin)')) decided_person,
  coalesce(d.property_code,h.property_code) decided_property,
  public.lts_card_merchant_key_v226(h.description) merchant_key,public.lts_bank_merchant_key_v231(h.description) bank_key
 FROM raw_history h LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_table=h.st AND d.source_ref=h.sr
 WHERE pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(coalesce(d.category_label,h.category),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') NOT IN ('','a classificar','nao identificado','sem categoria','—')
), candidates AS (
 SELECT t.source_table,t.source_ref,h.decided_category category,h.decided_person person,h.decided_property property_code,
  CASE WHEN h.st='lts_open_finance_staging' AND t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<.005 THEN 10
       WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 15
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 20
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 AND t.last4=h.last4 THEN 25
       ELSE 45 END priority,
  CASE WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 'same_purchase_installments'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 'same_merchant_amount_history'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 THEN 'merchant_card_near_amount_history'
       ELSE 'merchant_history' END basis,
  jsonb_build_object('source_table',h.st,'source_ref',h.sr,'date',h.event_date,'description',h.description,'amount',h.amount,'category',h.decided_category) evidence,
  null::text note,null::text source_url
 FROM targets t JOIN history h ON (t.merchant_key=h.merchant_key OR t.bank_key=h.bank_key)
  AND NOT (h.st=t.source_table AND h.sr=t.source_ref)
 WHERE (t.question_kind='classification'
 OR (t.question_kind='person' AND h.decided_person IS NOT NULL AND abs(t.event_date-h.event_date)<=100)
 OR (t.question_kind IN ('property','property_purpose') AND h.decided_property IS NOT NULL AND abs(t.event_date-h.event_date)<=100))
 AND (t.merchant_key !~ 'mercado|amazon|shopee|pagseguro|merpago' OR abs(t.amount-h.amount)<=.05)
 UNION ALL
 SELECT t.source_table,t.source_ref,r.category,r.center_cost,null,35,'confirmed_rule',
  jsonb_build_object('rule',r.id,'description',r.match_value,'category',r.category),null,null
 FROM targets t JOIN public.lts_semantic_rule r ON r.user_id=p_user_id AND r.active
  AND r.confidence IN ('user_confirmed','high','alta','system_high')
  AND ((r.match_type='exact' AND public.lts_card_merchant_key_v226(r.match_value)=t.merchant_key)
   OR (r.match_type='prefix' AND public.lts_bank_merchant_key_v231(r.match_value)=t.bank_key))
 WHERE t.question_kind='classification'
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,50,s.basis,'{}',s.note,s.source_url
 FROM targets t JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,60,'public_merchant_source','{}',s.note,s.source_url
 FROM targets t JOIN public.lts_merchant_research_v231 s ON s.user_id=p_user_id AND s.merchant_key=t.merchant_key
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
), ranked AS (
 SELECT *,min(priority) OVER(PARTITION BY source_table,source_ref) best FROM candidates
), best AS (
 SELECT source_table,source_ref,count(DISTINCT category) category_count,
  CASE WHEN count(DISTINCT category)=1 THEN min(category) END category,
  CASE WHEN count(DISTINCT person)=1 THEN min(person) END person,
  CASE WHEN count(DISTINCT property_code)=1 THEN min(property_code) END property_code,
  min(basis) basis,min(note) note,min(source_url) source_url,count(*) evidence_count,
  (jsonb_agg(DISTINCT evidence))->0 evidence,
  jsonb_agg(DISTINCT category) alternatives
 FROM ranked WHERE priority=best GROUP BY source_table,source_ref
)
SELECT t.source_table,t.source_ref,
 CASE WHEN b.category IS NOT NULL THEN jsonb_build_object('category',b.category,'beneficiary',b.person,'property_code',b.property_code,
  'basis',b.basis,'source_url',b.source_url,'evidence_count',b.evidence_count,'evidence',b.evidence,'requires_confirmation',true,
  'note',coalesce(b.note,CASE b.basis
   WHEN 'same_purchase_installments' THEN 'Sugestão baseada em parcela da mesma compra. Confira e confirme.'
   WHEN 'same_merchant_amount_history' THEN 'Mesmo estabelecimento e valor no histórico. Confira e confirme.'
   WHEN 'merchant_card_near_amount_history' THEN 'Mesmo estabelecimento e cartão; pequena diferença de centavos entre parcelas. Confira e confirme.'
   WHEN 'confirmed_rule' THEN 'Regra já confirmada no histórico. Confira se vale para esta compra.'
   ELSE 'Sugestão do histórico deste estabelecimento. Confira e confirme.' END))
 ELSE jsonb_build_object('category',null,'requires_confirmation',true,
  'alternatives',coalesce(b.alternatives,'[]'),'basis',CASE WHEN b.category_count>1 THEN 'conflicting_history' ELSE 'insufficient_evidence' END,
  'note',coalesce(r.note,s.note,CASE WHEN b.category_count>1 THEN 'O histórico tem classificações diferentes; confirme a finalidade deste lançamento.'
   WHEN t.question_kind='property' THEN 'A categoria está preservada. Falta somente identificar o imóvel.'
   WHEN t.question_kind='person' THEN 'A categoria está preservada. Falta somente identificar a pessoa.'
   WHEN t.merchant_key ~ 'mercado|amazon|shopee|pagseguro|merpago' THEN 'O nome identifica a plataforma, mas não o produto. A finalidade permanece a confirmar.'
   ELSE 'Não encontrei correspondência suficiente para sugerir com segurança.' END),'source_url',coalesce(r.source_url,s.source_url)) END
FROM targets t LEFT JOIN best b USING(source_table,source_ref)
LEFT JOIN public.lts_merchant_research_v231 r ON r.user_id=p_user_id AND r.merchant_key=t.merchant_key
LEFT JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
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
CASE WHEN e.source_ref IS NOT NULL AND r.management_group IN ('Moradia — imóvel a confirmar','Outras saídas familiares — a revisar')
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
CREATE OR REPLACE FUNCTION public.lts_v178_norm(v text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(v,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') $function$
;
