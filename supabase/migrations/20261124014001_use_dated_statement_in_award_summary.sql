-- Read documented brokerage positions for the statement panel. The scenario
-- assumptions in the owner policy have a separate lifetime from a statement.
DO $migration$
DECLARE
  target regprocedure := 'public.lts_browser_rsu_policy_v411()'::regprocedure;
  original text := pg_get_functiondef(target);
  marker text := 'ref:=p->''morgan_reference'';';
  replacement text := $filter$ref:=p->'morgan_reference';
 -- Prefer the most recent full statement. If the summary cannot express its
 -- available shares, the dated statement panel already shows the full breakdown.
 SELECT CASE WHEN s.vested_shares_available_brl=0 AND s.other_available_brl=0
          AND s.available_total_brl=s.brokerage_cash_available_brl
          AND s.unavailable_total_brl=s.future_rsu_gross_brl+s.future_cash_rsu_gross_brl+s.other_unavailable_brl
          AND s.total_gross_brl=s.available_total_brl+s.unavailable_total_brl
        THEN jsonb_build_object(
          'currency',s.currency,'as_of_date',s.as_of_date,'received_on',s.as_of_date,
          'total_gross_brl',s.total_gross_brl,'available_total_brl',s.available_total_brl,
          'unavailable_gross_brl',s.unavailable_total_brl,'regular_rsu_gross_brl',s.future_rsu_gross_brl,
          'cash_rsu_gross_brl',s.future_cash_rsu_gross_brl,'brokerage_cash_brl',s.brokerage_cash_available_brl,
          'unallocated_gross_brl',s.other_unavailable_brl)
        END INTO ref
 FROM public.lts_brokerage_position_snapshots s
 WHERE s.user_id=u AND s.institution='Morgan Stanley' AND s.as_of_date<=current_date
   AND s.metadata->>'documentary_current_position'='true'
   AND s.as_of_date>=coalesce(nullif(p#>>'{morgan_reference,as_of_date}','')::date,
                             nullif(p#>>'{morgan_reference,received_on}','')::date,'-infinity'::date)
 ORDER BY s.as_of_date DESC,s.updated_at DESC LIMIT 1;
 IF NOT FOUND THEN ref:=p->'morgan_reference'; END IF;$filter$;
BEGIN
  IF position(replacement IN original)>0 THEN RETURN; END IF;
  IF (length(original)-length(replace(original,marker,'')))<>length(marker) THEN
    RAISE EXCEPTION 'Unexpected award policy reader definition';
  END IF;
  EXECUTE replace(original,marker,replacement);
END
$migration$;
