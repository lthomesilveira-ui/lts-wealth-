-- Reconstruct only the interval affected by newly observed movements, plus today.
-- Earlier validated daily rows remain byte-for-byte owned by the prior reader.
DO $migration$
DECLARE definition text; needle text:='IF dt>lo AND dt<=current_date THEN';
BEGIN
 definition:=pg_get_functiondef('public.lts_browser_flow_v228(date,date)'::regprocedure);
 IF position(needle in definition)=0 THEN RAISE EXCEPTION 'V228 expected adapter revision missing'; END IF;
 definition:=replace(definition,needle,
  'IF dt>lo AND dt<=current_date AND (dt=current_date OR EXISTS(SELECT 1 FROM jsonb_array_elements(added) observed WHERE (observed->>''event_date'')::date<=dt)) THEN');
 EXECUTE definition;
END $migration$;
