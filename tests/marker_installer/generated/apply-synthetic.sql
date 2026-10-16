-- SYNTHETIC TEMPLATE. ready=false retained. Use only the isolated test runner.
-- Creating/replacing the baseline invalidates all five global homologation stages.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL search_path TO public,pg_catalog;
SET LOCAL TimeZone TO 'America/Sao_Paulo';
SET LOCAL lock_timeout TO '5s';
SET LOCAL statement_timeout TO '120s';
DO $marker$
DECLARE
 u constant uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid;
 op constant text:='wealth-generic-identity-marker-20261016-v1';
 ready constant boolean:=false;
 before_functions jsonb; after_functions jsonb; actual_relations jsonb;
 before_baseline jsonb; after_baseline jsonb; before_final jsonb; after_final jsonb;
 epoch_before bigint; epoch_after bigint; a jsonb; n bigint; changed_baseline bigint; changed_final bigint;
 before_def text; after_def text; saved record;
BEGIN
 IF NOT ready THEN RAISE EXCEPTION 'marker installer blocked: fresh reviewed lease and PostgreSQL envelope gate required'; END IF;
 IF public.lts_open_finance_pilot_owner_v1() IS DISTINCT FROM u THEN RAISE EXCEPTION 'owner changed'; END IF;
 IF current_date<>DATE '2099-01-01' THEN RAISE EXCEPTION 'dated marker lease expired: recapture and review'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('wealth-exact-classification:'||u::text,0));
 LOCK TABLE public.lts_access_audit,public.lts_read_cache_epoch_v242,public.lts_v178_review_decision,public.lts_v229_read_cache IN SHARE ROW EXCLUSIVE MODE;
 SELECT epoch INTO STRICT epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;
 SELECT jsonb_agg(jsonb_build_object('signature',replace(s.signature,'public.',''),'oid',p.oid::bigint,'owner',p.proowner::regrole::text,'acl',p.proacl::text,'definition_md5',md5(pg_get_functiondef(p.oid)),'result',pg_get_function_result(p.oid),'identity_arguments',pg_get_function_identity_arguments(p.oid),'security_definer',p.prosecdef,'volatility',p.provolatile,'config',p.proconfig) ORDER BY s.signature)
 INTO before_functions FROM unnest(ARRAY['public.lts_bank_description_key_v229(text)','public.lts_bank_known_classification_v231(uuid,uuid)','public.lts_bank_merchant_key_v231(text)','public.lts_bank_posted_rows_v231(uuid)','public.lts_c6_cycle_identity_v269(uuid)','public.lts_c6_paid_identity_v237(uuid)','public.lts_canonical_category_v1(uuid,text)','public.lts_canonical_description_fix86_v1(text)','public.lts_card_bank_monthly_deltas_v1(uuid)','public.lts_card_cycles_v226(uuid)','public.lts_card_document_candidates_v269(uuid)','public.lts_card_document_matches_v234(uuid)','public.lts_card_document_rows_v234(uuid)','public.lts_card_exact_recovery_v226(uuid,date,date)','public.lts_card_family_key_v181(text,text)','public.lts_card_family_v226(text,text)','public.lts_card_installment_key_v231(lts_open_finance_staging)','public.lts_card_invoice_account_v181(text)','public.lts_card_invoice_amounts_v230(uuid)','public.lts_card_invoice_amounts_v230_engine_v243(uuid)','public.lts_card_merchant_key_v226(text)','public.lts_card_observed_expense_eligible_v1(jsonb,date,date)','public.lts_card_settlement_contract_v273(uuid,uuid)','public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)','public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)','public.lts_card_source_rows_pre_v262(uuid)','public.lts_card_source_rows_v226(uuid)','public.lts_card_workbook_bank_rows_v1(uuid)','public.lts_confirmation_key_for_flow_ref_v1(uuid,text)','public.lts_corrected_cashflow_fix86_v1(uuid,date,date)','public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)','public.lts_corrected_cashflow_fix86_v2(uuid,date,date)','public.lts_corrected_cashflow_fix86_v3(uuid,date,date)','public.lts_corrected_cashflow_fix86_v4(uuid,date,date)','public.lts_corrected_cashflow_fix86_v5(uuid,date,date)','public.lts_corrected_cashflow_operational_v1(uuid,date,date)','public.lts_current_evidence_position_v1(uuid)','public.lts_current_evidence_position_v2(uuid)','public.lts_current_received_card_bills_v263(uuid)','public.lts_expense_effective_rows_pre_v268(uuid,date,date)','public.lts_expense_effective_rows_v176(uuid,date,date)','public.lts_expense_effective_rows_v225_baseline(uuid,date,date)','public.lts_expense_management_group_v3(text,text,text,text,text)','public.lts_expense_management_subgroup_v2(text,text,text,text,text)','public.lts_expense_rows_v230_baseline(uuid,date,date)','public.lts_flow_current_effective_v1(uuid,date,date)','public.lts_flow_observed_position_guard_v1(jsonb,date)','public.lts_flow_operational_read_v229(uuid,date,date)','public.lts_flow_past_operational_v2(uuid,date,date)','public.lts_historical_cash_engine_v243(uuid,date,date)','public.lts_historical_effective_cash_pre_v246(uuid,date,date)','public.lts_historical_effective_cash_v2(uuid,date,date)','public.lts_historical_effective_cash_v3(uuid,date,date)','public.lts_historical_effective_cash_v4(uuid,date,date)','public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)','public.lts_historical_effective_cash_v5(uuid,date,date)','public.lts_internal_transfer_legs_fix86_v1(uuid,date,date)','public.lts_open_finance_checking_positions_v1(uuid)','public.lts_open_finance_current_bank_position_v1(uuid)','public.lts_open_finance_pilot_owner_v1()','public.lts_operational_source_key_pre_v242(uuid)','public.lts_operational_source_key_v238(uuid)','public.lts_owner_confirmed_transfer_pairs_v263(uuid)','public.lts_payroll_bank_matches_v231(uuid)','public.lts_payroll_bank_matches_v231_engine_v243(uuid)','public.lts_payroll_withholding_effective_v1(uuid,date,date)','public.lts_realized_bank_sources_v238(uuid)','public.lts_v178_norm(text)','public.lts_v229_expense_rows(uuid,date,date)','public.lts_v229_expense_rows_pre_v238(uuid,date,date)','public.lts_v229_new_bank_rows(uuid,date,date)']::text[]) AS s(signature) LEFT JOIN pg_proc p ON p.oid=to_regprocedure(s.signature);
 SELECT jsonb_agg(jsonb_build_object('relation',s.name,'oid',c.oid::bigint,'owner',c.relowner::regrole::text,'acl',c.relacl::text,'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'options',c.reloptions,'view_md5',CASE WHEN c.relkind IN('v','m') THEN md5(pg_get_viewdef(c.oid,true)) END,
 'columns',(SELECT jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'acl',a.attacl::text,'identity',a.attidentity,'default',pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum) FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
 'triggers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',g.tgname,'enabled',g.tgenabled,'definition',pg_get_triggerdef(g.oid,true),'function_md5',md5(pg_get_functiondef(g.tgfoid))) ORDER BY g.tgname),'[]') FROM pg_trigger g WHERE g.tgrelid=c.oid AND NOT g.tgisinternal)) ORDER BY s.name)
 INTO actual_relations FROM unnest(ARRAY['public.fixture_flow','public.accounts','public.card_invoices','public.compra_parcelada','public.deslocamento','public.evento_base','public.evento_usuario','public.financial_events','public.historico_analitico','public.legacy_namespace','public.lts_access_audit','public.lts_analytics_timeline','public.lts_card_document_supplement_v234','public.lts_card_documentary_payment_link_v272','public.lts_card_formula_resolution_v237','public.lts_card_historical_category_allocation','public.lts_card_historical_validation_registry','public.lts_card_history_recovered_purchase','public.lts_card_history_source_audit_v235','public.lts_card_purchase_detail','public.lts_card_settlement_expense_contract_v273','public.lts_card_workbook_evidence_v226','public.lts_category_alias','public.lts_commitment_documentary_schedule','public.lts_document_card_purchase','public.lts_expense_analytics_candidate','public.lts_expense_effective_read_cache','public.lts_expense_realized','public.lts_external_reference_fact','public.lts_fact_confirmation','public.lts_flow_event_operation','public.lts_liquidity_movement','public.lts_manual_card_purchase','public.lts_open_finance_staging','public.lts_project_checkpoint','public.lts_projection_replacement_rule','public.lts_read_cache_epoch_v242','public.lts_realized_bank_event_v238','public.lts_reconciliation_evidence','public.lts_semantic_amount_signature','public.lts_semantic_rule','public.lts_v175_workbook_monthly_category_source','public.lts_v178_review_decision','public.lts_v229_documentary_match','public.lts_v229_read_cache','public.lts_validated_lock_registry','public.lts_workbook_identity_evidence_v232','public.projecao_op','public.reconciliacao','public.source_documents']::text[]) AS s(name) LEFT JOIN pg_class c ON c.oid=to_regclass(s.name);
 IF actual_relations IS DISTINCT FROM '__RELATIONS__'::jsonb THEN RAISE EXCEPTION 'relation schema ACL RLS view or trigger lease changed'; END IF;
 SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure) INTO before_def;
 IF before_functions IS DISTINCT FROM '__FUNCTIONS_ORIGINAL__'::jsonb OR md5(before_def) IS DISTINCT FROM '__ORIGINAL_MD5__' THEN RAISE EXCEPTION 'function OID owner ACL config or definition lease changed'; END IF;
 IF (SELECT count(*) FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_exact_classifications_20261016' AND meta->>'operation_id'='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')<>1 OR EXISTS(SELECT 1 FROM public.lts_access_audit WHERE user_id=u AND action='agent_restore_exact_classifications_20261016_rollback' AND meta->>'operation_id'='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') THEN RAISE EXCEPTION 'five exact overlays must be applied and retained before marker'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_access_audit WHERE user_id=u AND meta->>'operation_id'=op) THEN RAISE EXCEPTION 'marker operation already recorded: inspect receipt'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') INTO before_baseline FROM public.lts_expense_rows_v230_baseline(u,DATE '2000-01-01',DATE '2099-01-01') e;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') INTO before_final FROM public.lts_v229_expense_rows(u,DATE '2000-01-01',DATE '2099-01-01') e;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_expense_rows_v230_baseline(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with expense_base as materialized(select * from public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to)), person_rules as materialized (
 select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(match_value,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') match_key,match_type,center_cost
 from public.lts_semantic_rule where user_id=p_user_id and active
 and center_cost in ('PersonGamma','PersonBeta','PersonAlpha','SyntheticPet') and confidence in ('high','alta')
), new_bank_raw as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)),
settlement_ids as materialized(select distinct n.id,public.lts_card_settlement_contract_v273(p_user_id,n.id) contract from new_bank_raw n where public.lts_card_settlement_contract_v273(p_user_id,n.id) is not null),
settlement_coverage as materialized(
 select s.id,case when (s.contract->>'competence_month')::date between p_from and p_to then
 (select coalesce(jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,'competence_month',e.competence_month,'coverage_mode',e.coverage_mode)),'[]'::jsonb) from expense_base e
 where e.source_table='lts_open_finance_staging' and e.source_ref in(select m->>'id' from jsonb_array_elements(s.contract->'consumption_manifest')m))
 else (select coalesce(jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,'competence_month',e.competence_month,'coverage_mode',e.coverage_mode)),'[]'::jsonb)
 from public.lts_expense_effective_rows_v176(p_user_id,(s.contract->>'competence_month')::date,((s.contract->>'competence_month')::date+interval '1 month -1 day')::date)e
 where e.source_table='lts_open_finance_staging' and e.source_ref in(select m->>'id' from jsonb_array_elements(s.contract->'consumption_manifest')m)) end coverage
 from settlement_ids s),
settlement_exclusions as materialized(select s.id from settlement_coverage s where public.lts_card_settlement_expense_excluded_v273(p_user_id,s.id,s.coverage)),
new_bank as materialized(select n.* from new_bank_raw n where not exists(select 1 from settlement_exclusions s where s.id=n.id)), b as materialized(
 select x.event_date,x.transaction_date,x.competence_month,x.amount,
 case when card_source.category is not null then card_source.category
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(x.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='a classificar' and source.category is not null
 then case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(source.category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='financiamento imovel' then 'Financiamento imobiliário' else source.category end
 else x.category end category,
 x.center_cost,x.counterparty,x.origin_type,x.origin_name,x.source_table,x.source_ref,x.coverage_mode,x.is_property,x.is_financing
 from expense_base x
 -- A known category on this exact documentary purchase outranks a broad
 -- merchant heuristic. Explicit per-purchase review decisions still win
 -- downstream; unknown/ambiguous original categories remain fallbacks.
 left join lateral (
   select case when count(distinct nullif(trim(cd.category),''))=1 then min(nullif(trim(cd.category),'')) end category
   from public.lts_card_purchase_detail cd
   where x.source_table='card_purchase_detail' and cd.user_id=p_user_id
   and x.source_ref IN(cd.line_key,cd.purchase_key)
   -- Only this proved collision is overridden. Keep finer approved
   -- purposes (such as Batizado), beneficiary refinements and other
   -- current semantic categories intact; placeholders are never evidence.
   and public.lts_v178_norm(cd.category)='presentes'
   and public.lts_v178_norm(x.category)='vestuario'
   and public.lts_v178_norm(cd.category) not in ('','a classificar','nao identificado','nao atribuida','nao atribuido')
 ) card_source on true
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
 coalesce(e.metadata->>'cost_center',e.metadata->>'center_cost',e.metadata#>>'{synthetic_classification_answers,center_cost}',e.metadata#>>'{synthetic_user_classification,beneficiary}'),
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
 coalesce(nullif(s.cat,''),b.category) original_category,coalesce(case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personalpha([[:space:]—-]|$)' then 'PersonAlpha' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personbeta([[:space:]—-]|$)' then 'PersonBeta' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^persongamma([[:space:]—-]|$)' then 'PersonGamma' when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.person,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='syntheticpet' then 'SyntheticPet' end,pr.person) person_hint,s.purchased,s.meta,
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
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personalpha(\s|[-—])' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personalpha(\s|[-—])' then 'PersonAlpha'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personbeta(\s|[-—])' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^personbeta(\s|[-—])' then 'PersonBeta'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^persongamma(\s|[-—])' then 'PersonGamma'
 when center_cost in ('PersonGamma','PersonBeta','PersonAlpha','SyntheticPet') then center_cost
 when person_hint in ('PersonGamma','PersonBeta','PersonAlpha','SyntheticPet') then person_hint
 when category_norm ~ 'educa' and desc_norm ~ 'synthetic lessons' then 'PersonGamma'
 when category_norm ~ 'educa' and desc_norm ~ 'synthetic school' then 'PersonAlpha'
 when category_norm ~ 'saude' and desc_norm ~ 'synthetic clinic' and event_date<=date '2000-01-01' then 'PersonAlpha'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('personbeta','familia') and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(counterparty,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='personbeta' then 'PersonBeta'
 when category_norm ~ '^syntheticpet|^pet$' then 'SyntheticPet'
 else null end person_final,
 case
 when category_decision is not null then category_decision
 when category_norm ~ 'saude' then 'Saúde'
 when category_norm ~ 'educa' then 'Educação'
 when category_norm ~ 'vestuario' then 'Vestuário'
 else regexp_replace(case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(personalpha|personbeta|persongamma)\s*[-—]' then category else coalesce(original_category,category) end,'^(PersonAlpha|PersonBeta|PersonGamma)\s*[-—]\s*','','i') end kind,
 public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) old_group,
 coalesce(property_decision,
 case when (public.lts_expense_management_group_v3(coalesce(category_decision,category),center_cost,counterparty,origin_name,coverage_mode) in ('Financiamento imobiliário','Investimento no imóvel — aquisição e histórico','Investimentos no imóvel — obra e reforma','Moradia','Condomínio','Energia','Impostos do imóvel') or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('seguro residencial','aluguel')) and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(concat_ws(' ',original_category,descr,counterparty),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '(^|[^[:alnum:]])(synthetic property|synthetic[[:space:]]*property)([^[:alnum:]]|$)' and not (source_table='historico_analitico' and desc_norm !~ '(^|[^[:alnum:]])(synthetic property|synthetic[[:space:]]*property)([^[:alnum:]]|$)') then 'synthetic_property'
 when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^financiamento imobiliario' then 'synthetic_property'
 when coalesce(meta#>>'{classification_recovery,basis}','')='synthetic_recovery_basis' then 'synthetic_property'
 end) prop
 from enriched e
), labeled as materialized(
 select p.*,
 case when prop='synthetic_property' then
   case when old_group in ('Financiamento imobiliário','Investimento no imóvel — aquisição e histórico') or category_norm ~ 'consorcio|corretagem' then 'Aquisição do imóvel'
        when old_group='Investimentos no imóvel — obra e reforma' then 'Obra e reforma'
        when category_norm ~ 'iptu|impostos do imovel' then 'Impostos do imóvel'
        when old_group in ('Moradia','Condomínio','Energia') or category_norm ~ 'enel|energia|seguro residencial' then 'Custos de moradia'
        else 'A revisar' end
 end prop_component,
 case
 when old_group='Empréstimos' then old_group
 when person_final='SyntheticPet' then 'SyntheticPet'
 when person_final is not null and (category_norm ~ 'saude|educa|vestuario' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(original_category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(personalpha|personbeta|persongamma)\s*[-—]' or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(personalpha|personbeta|persongamma)\s*[-—]') then case when person_final='PersonGamma' then kind else person_final||' — '||kind end
 when person_final='PersonBeta' and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','personbeta') then 'PersonBeta — despesas'
 when person_final='PersonAlpha' and pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g')='personalpha' then 'PersonAlpha — Outros'
 when person_final='PersonGamma' then case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(kind,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','persongamma','personbeta','personalpha') then 'Despesas' else kind end
 when person_final in ('PersonBeta','PersonAlpha') then person_final||' — '||case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(kind,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('familia','persongamma','personbeta','personalpha') then 'despesas' else kind end
 when kind in ('Saúde','Educação','Vestuário') then kind
 when old_group='Família — saídas' then 'Outras saídas familiares — a revisar'
 when old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial') and prop is null then 'Moradia — imóvel a confirmar'
 else old_group end group_without_property
 from person_rows p
)
select source_table||':'||source_ref||':'||competence_month::text||':'||coalesce(category,''),event_date,transaction_date,competence_month,amount,
 coalesce(category_decision,category),person_final,descr,origin_name,source_table,source_ref,coverage_mode,original_category,
 concat_ws(' · ',nullif(center_cost,'Não atribuído'),nullif(counterparty,'Não identificado')),purchased,
 case when pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(coalesce(category_decision,category),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') in ('a classificar','nao identificado','sem categoria') or group_without_property like '%a revisar' or prop_component='A revisar' or (kind='Educação' and person_final is null) or (prop is null and old_group in ('Moradia','Condomínio','Energia','Impostos do imóvel','Investimento no imóvel — aquisição e histórico','Seguro Residencial')) or descr in ('Não identificado','Descrição pendente') then 'pending' else 'identified' end,
 case when prop='synthetic_property' then 'Synthetic property display' else group_without_property end,
 case when prop='synthetic_property' then prop_component
 when old_group='Empréstimos' then public.lts_expense_management_subgroup_v2(category,center_cost,counterparty,origin_name,coverage_mode)
 when person_final is not null then kind else category end,
 prop,prop_component
from labeled
$function$
$definition$;
 SELECT pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure) INTO after_def; IF md5(after_def) IS DISTINCT FROM '__CANDIDATE_MD5__' THEN RAISE EXCEPTION 'installed marker definition differs from reviewed body'; END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton AND epoch=epoch_before RETURNING epoch INTO epoch_after; GET DIAGNOSTICS n=ROW_COUNT; IF n<>1 THEN RAISE EXCEPTION 'marker cache epoch CAS failed'; END IF;
 DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') INTO after_baseline FROM public.lts_expense_rows_v230_baseline(u,DATE '2000-01-01',DATE '2099-01-01') e;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY to_jsonb(e)::text),'[]') INTO after_final FROM public.lts_v229_expense_rows(u,DATE '2000-01-01',DATE '2099-01-01') e;
 IF jsonb_array_length(before_baseline) IS DISTINCT FROM jsonb_array_length(after_baseline) THEN RAISE EXCEPTION 'marker row cardinality changed'; END IF;
 IF EXISTS((SELECT e-'identity_status' FROM jsonb_array_elements(before_baseline)e EXCEPT ALL SELECT e-'identity_status' FROM jsonb_array_elements(after_baseline)e) UNION ALL (SELECT e-'identity_status' FROM jsonb_array_elements(after_baseline)e EXCEPT ALL SELECT e-'identity_status' FROM jsonb_array_elements(before_baseline)e)) THEN RAISE EXCEPTION 'marker changed one of nineteen protected fields'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_baseline)e GROUP BY e->>'row_key' HAVING count(*)<>1 OR e->>'row_key' IS NULL) OR EXISTS(SELECT 1 FROM jsonb_array_elements(after_baseline)e GROUP BY e->>'row_key' HAVING count(*)<>1 OR e->>'row_key' IS NULL) THEN RAISE EXCEPTION 'marker comparison requires unique nonnull row keys'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_baseline)b JOIN jsonb_array_elements(after_baseline)c ON b->>'row_key'=c->>'row_key' WHERE b->'identity_status' IS DISTINCT FROM c->'identity_status' AND (b->>'identity_status'='pending' AND c->>'identity_status'='identified' AND b->>'category' IN('Saúde','Vestuário') AND b->'beneficiary'='null'::jsonb AND b-'identity_status'=c-'identity_status') IS NOT TRUE) THEN RAISE EXCEPTION 'marker transition outside generic health clothing scope'; END IF;
 IF jsonb_array_length(before_final) IS DISTINCT FROM jsonb_array_length(after_final) THEN RAISE EXCEPTION 'marker row cardinality changed'; END IF;
 IF EXISTS((SELECT e-'identity_status' FROM jsonb_array_elements(before_final)e EXCEPT ALL SELECT e-'identity_status' FROM jsonb_array_elements(after_final)e) UNION ALL (SELECT e-'identity_status' FROM jsonb_array_elements(after_final)e EXCEPT ALL SELECT e-'identity_status' FROM jsonb_array_elements(before_final)e)) THEN RAISE EXCEPTION 'marker changed one of nineteen protected fields'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_final)e GROUP BY e->>'row_key' HAVING count(*)<>1 OR e->>'row_key' IS NULL) OR EXISTS(SELECT 1 FROM jsonb_array_elements(after_final)e GROUP BY e->>'row_key' HAVING count(*)<>1 OR e->>'row_key' IS NULL) THEN RAISE EXCEPTION 'marker comparison requires unique nonnull row keys'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_final)b JOIN jsonb_array_elements(after_final)c ON b->>'row_key'=c->>'row_key' WHERE b->'identity_status' IS DISTINCT FROM c->'identity_status' AND (b->>'identity_status'='pending' AND c->>'identity_status'='identified' AND b->>'category' IN('Saúde','Vestuário') AND b->'beneficiary'='null'::jsonb AND b-'identity_status'=c-'identity_status') IS NOT TRUE) THEN RAISE EXCEPTION 'marker transition outside generic health clothing scope'; END IF;
 SELECT count(*) INTO changed_baseline FROM jsonb_array_elements(before_baseline)b JOIN jsonb_array_elements(after_baseline)c ON b->>'row_key'=c->>'row_key' WHERE b->'identity_status' IS DISTINCT FROM c->'identity_status';
 SELECT count(*) INTO changed_final FROM jsonb_array_elements(before_final)b JOIN jsonb_array_elements(after_final)c ON b->>'row_key'=c->>'row_key' WHERE b->'identity_status' IS DISTINCT FROM c->'identity_status';
 IF changed_baseline=0 OR changed_final=0 THEN RAISE EXCEPTION 'marker did not exercise an eligible transition'; END IF;
SELECT jsonb_agg(jsonb_build_object('signature',replace(s.signature,'public.',''),'oid',p.oid::bigint,'owner',p.proowner::regrole::text,'acl',p.proacl::text,'definition_md5',md5(pg_get_functiondef(p.oid)),'result',pg_get_function_result(p.oid),'identity_arguments',pg_get_function_identity_arguments(p.oid),'security_definer',p.prosecdef,'volatility',p.provolatile,'config',p.proconfig) ORDER BY s.signature)
 INTO after_functions FROM unnest(ARRAY['public.lts_bank_description_key_v229(text)','public.lts_bank_known_classification_v231(uuid,uuid)','public.lts_bank_merchant_key_v231(text)','public.lts_bank_posted_rows_v231(uuid)','public.lts_c6_cycle_identity_v269(uuid)','public.lts_c6_paid_identity_v237(uuid)','public.lts_canonical_category_v1(uuid,text)','public.lts_canonical_description_fix86_v1(text)','public.lts_card_bank_monthly_deltas_v1(uuid)','public.lts_card_cycles_v226(uuid)','public.lts_card_document_candidates_v269(uuid)','public.lts_card_document_matches_v234(uuid)','public.lts_card_document_rows_v234(uuid)','public.lts_card_exact_recovery_v226(uuid,date,date)','public.lts_card_family_key_v181(text,text)','public.lts_card_family_v226(text,text)','public.lts_card_installment_key_v231(lts_open_finance_staging)','public.lts_card_invoice_account_v181(text)','public.lts_card_invoice_amounts_v230(uuid)','public.lts_card_invoice_amounts_v230_engine_v243(uuid)','public.lts_card_merchant_key_v226(text)','public.lts_card_observed_expense_eligible_v1(jsonb,date,date)','public.lts_card_settlement_contract_v273(uuid,uuid)','public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)','public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)','public.lts_card_source_rows_pre_v262(uuid)','public.lts_card_source_rows_v226(uuid)','public.lts_card_workbook_bank_rows_v1(uuid)','public.lts_confirmation_key_for_flow_ref_v1(uuid,text)','public.lts_corrected_cashflow_fix86_v1(uuid,date,date)','public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)','public.lts_corrected_cashflow_fix86_v2(uuid,date,date)','public.lts_corrected_cashflow_fix86_v3(uuid,date,date)','public.lts_corrected_cashflow_fix86_v4(uuid,date,date)','public.lts_corrected_cashflow_fix86_v5(uuid,date,date)','public.lts_corrected_cashflow_operational_v1(uuid,date,date)','public.lts_current_evidence_position_v1(uuid)','public.lts_current_evidence_position_v2(uuid)','public.lts_current_received_card_bills_v263(uuid)','public.lts_expense_effective_rows_pre_v268(uuid,date,date)','public.lts_expense_effective_rows_v176(uuid,date,date)','public.lts_expense_effective_rows_v225_baseline(uuid,date,date)','public.lts_expense_management_group_v3(text,text,text,text,text)','public.lts_expense_management_subgroup_v2(text,text,text,text,text)','public.lts_expense_rows_v230_baseline(uuid,date,date)','public.lts_flow_current_effective_v1(uuid,date,date)','public.lts_flow_observed_position_guard_v1(jsonb,date)','public.lts_flow_operational_read_v229(uuid,date,date)','public.lts_flow_past_operational_v2(uuid,date,date)','public.lts_historical_cash_engine_v243(uuid,date,date)','public.lts_historical_effective_cash_pre_v246(uuid,date,date)','public.lts_historical_effective_cash_v2(uuid,date,date)','public.lts_historical_effective_cash_v3(uuid,date,date)','public.lts_historical_effective_cash_v4(uuid,date,date)','public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)','public.lts_historical_effective_cash_v5(uuid,date,date)','public.lts_internal_transfer_legs_fix86_v1(uuid,date,date)','public.lts_open_finance_checking_positions_v1(uuid)','public.lts_open_finance_current_bank_position_v1(uuid)','public.lts_open_finance_pilot_owner_v1()','public.lts_operational_source_key_pre_v242(uuid)','public.lts_operational_source_key_v238(uuid)','public.lts_owner_confirmed_transfer_pairs_v263(uuid)','public.lts_payroll_bank_matches_v231(uuid)','public.lts_payroll_bank_matches_v231_engine_v243(uuid)','public.lts_payroll_withholding_effective_v1(uuid,date,date)','public.lts_realized_bank_sources_v238(uuid)','public.lts_v178_norm(text)','public.lts_v229_expense_rows(uuid,date,date)','public.lts_v229_expense_rows_pre_v238(uuid,date,date)','public.lts_v229_new_bank_rows(uuid,date,date)']::text[]) AS s(signature) LEFT JOIN pg_proc p ON p.oid=to_regprocedure(s.signature);
 IF after_functions IS DISTINCT FROM '__FUNCTIONS_INSTALLED__'::jsonb THEN RAISE EXCEPTION 'postinstall function identity ACL or dependency lease changed'; END IF;
SELECT jsonb_agg(jsonb_build_object('relation',s.name,'oid',c.oid::bigint,'owner',c.relowner::regrole::text,'acl',c.relacl::text,'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'options',c.reloptions,'view_md5',CASE WHEN c.relkind IN('v','m') THEN md5(pg_get_viewdef(c.oid,true)) END,
 'columns',(SELECT jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'acl',a.attacl::text,'identity',a.attidentity,'default',pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum) FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),
 'triggers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',g.tgname,'enabled',g.tgenabled,'definition',pg_get_triggerdef(g.oid,true),'function_md5',md5(pg_get_functiondef(g.tgfoid))) ORDER BY g.tgname),'[]') FROM pg_trigger g WHERE g.tgrelid=c.oid AND NOT g.tgisinternal)) ORDER BY s.name)
 INTO actual_relations FROM unnest(ARRAY['public.fixture_flow','public.accounts','public.card_invoices','public.compra_parcelada','public.deslocamento','public.evento_base','public.evento_usuario','public.financial_events','public.historico_analitico','public.legacy_namespace','public.lts_access_audit','public.lts_analytics_timeline','public.lts_card_document_supplement_v234','public.lts_card_documentary_payment_link_v272','public.lts_card_formula_resolution_v237','public.lts_card_historical_category_allocation','public.lts_card_historical_validation_registry','public.lts_card_history_recovered_purchase','public.lts_card_history_source_audit_v235','public.lts_card_purchase_detail','public.lts_card_settlement_expense_contract_v273','public.lts_card_workbook_evidence_v226','public.lts_category_alias','public.lts_commitment_documentary_schedule','public.lts_document_card_purchase','public.lts_expense_analytics_candidate','public.lts_expense_effective_read_cache','public.lts_expense_realized','public.lts_external_reference_fact','public.lts_fact_confirmation','public.lts_flow_event_operation','public.lts_liquidity_movement','public.lts_manual_card_purchase','public.lts_open_finance_staging','public.lts_project_checkpoint','public.lts_projection_replacement_rule','public.lts_read_cache_epoch_v242','public.lts_realized_bank_event_v238','public.lts_reconciliation_evidence','public.lts_semantic_amount_signature','public.lts_semantic_rule','public.lts_v175_workbook_monthly_category_source','public.lts_v178_review_decision','public.lts_v229_documentary_match','public.lts_v229_read_cache','public.lts_validated_lock_registry','public.lts_workbook_identity_evidence_v232','public.projecao_op','public.reconciliacao','public.source_documents']::text[]) AS s(name) LEFT JOIN pg_class c ON c.oid=to_regclass(s.name);
 IF actual_relations IS DISTINCT FROM '__RELATIONS__'::jsonb THEN RAISE EXCEPTION 'postinstall relation schema or permission changed'; END IF;
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) IS DISTINCT FROM epoch_before+1 THEN RAISE EXCEPTION 'unexpected cache invalidation count'; END IF;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,NULL,'agent_generic_identity_marker_apply',jsonb_build_object('operation_id',op,'old_definition_md5','__ORIGINAL_MD5__','new_definition_md5','__CANDIDATE_MD5__','old_definition',before_def,'functions_before',before_functions,'functions_after',after_functions,'baseline_transitions',changed_baseline,'final_transitions',changed_final,'nineteen_fields_unchanged',true,'source_rows_not_written',true,'epoch_before',epoch_before,'epoch_after',epoch_after,'global_homologation_invalidated',true,'required_fresh_stages',jsonb_build_array('fresh_leases_and_static_closure','cold_readonly_consumer','warm_cold_parity','financial_reconciliation','ui_readback')));
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) IS DISTINCT FROM epoch_before+1 THEN RAISE EXCEPTION 'audit caused unexpected cache invalidation'; END IF;
END $marker$;
COMMIT;
