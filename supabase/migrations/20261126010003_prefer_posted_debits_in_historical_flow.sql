-- Historical cash flow combines the bank ledger with previously prepared
-- projections. Apply the same source precedence before computing daily sums.
DO $migration$
DECLARE
 definition text:=pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
 anchor text:='WHERE NOT EXISTS(SELECT 1 FROM public.lts_payroll_bank_matches_v231(u) pm WHERE pm.projection_ref=x->>''source_ref'');';
 replacement text:='WHERE NOT EXISTS(SELECT 1 FROM public.lts_payroll_bank_matches_v231(u) pm WHERE pm.projection_ref=x->>''source_ref'')
 AND (x->>''source'' IS DISTINCT FROM ''current_event'' OR NOT EXISTS (
  SELECT 1 FROM public.lts_posted_contract_reservations_v498(u,lo+1,current_date) covered
  WHERE covered.source_ref=x->>''source_ref''));';
BEGIN
 IF strpos(definition,'lts_posted_contract_reservations_v498')>0 THEN RETURN; END IF;
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'Unexpected historical flow filter'; END IF;
 EXECUTE replace(definition,anchor,replacement);
END
$migration$;
WITH owners AS MATERIALIZED (
 SELECT DISTINCT c.user_id FROM public.lts_v229_read_cache c
 WHERE c.kind IN ('flow_v242','flow_v241_exact_v254','operational')
), affected AS MATERIALIZED (
 SELECT DISTINCT o.user_id FROM owners o
 CROSS JOIN LATERAL public.lts_posted_contract_reservations_v498(o.user_id,date '1900-01-01',current_date) r
)
DELETE FROM public.lts_v229_read_cache c USING affected a
WHERE c.user_id=a.user_id AND c.kind IN ('flow_v241_exact_v254','flow_v242','long_flow_raw_v450','flow_source_key_v243','history','operational','historical_cash_v4_v243');
