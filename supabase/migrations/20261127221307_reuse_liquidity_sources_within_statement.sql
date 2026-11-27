-- The same bank, savings and FGTS reads feed multiple fields in the liquidity
-- summary. Evaluate each once within the same statement and caller scope.
DO $migration$
DECLARE
 definition text := pg_get_functiondef('public.lts_current_evidence_position_v2(uuid)'::regprocedure);
BEGIN
 IF md5(definition) <> 'b9d8f8f0db01f7a9a2310398ec5776bc' THEN
  RAISE EXCEPTION 'The live liquidity reader has changed. Review before applying.';
 END IF;
 definition := replace(definition, $before$with b as (select public.lts_open_finance_current_bank_position_v1(p_user_id) j), c as (select (j->>'available_brl')::numeric v,j->>'snapshot_date' dt from
   (select public.lts_cofrinho_composition_v399(p_user_id,current_date)j)p) -- v402-current-daily-cofrinho$before$, $after$with b as materialized (
 select public.lts_open_finance_current_bank_position_v1(p_user_id) j
), cofrinho as materialized (
 select public.lts_cofrinho_composition_v399(p_user_id,current_date) j
), c as (
 select (j->>'available_brl')::numeric v,j->>'snapshot_date' dt from cofrinho
), fgts as materialized (
 select public.lts_fgts_position_evidence_v386(p_user_id,current_date)->>'balance_brl' balance_brl
) -- v402-current-daily-cofrinho$after$);
 definition := replace(definition, $before$(public.lts_fgts_position_evidence_v386(p_user_id,current_date)->>'balance_brl')::numeric$before$, $after$fgts.balance_brl::numeric$after$);
 definition := replace(definition, $before$public.lts_fgts_position_evidence_v386(p_user_id,current_date)->>'balance_brl' IS NOT NULL$before$, $after$fgts.balance_brl IS NOT NULL$after$);
 definition := replace(definition, $before$from b,c $function$$before$, $after$from b,c,fgts $function$$after$);
 EXECUTE definition;
END
$migration$;
