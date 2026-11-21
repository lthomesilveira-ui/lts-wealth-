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
new_bank as materialized(select n.* from new_bank_raw n where not exists(select 1 from settlement_exclusions s where s.id=n.id))
