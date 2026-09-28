DO $migration$
DECLARE definition text;
BEGIN
 definition:=pg_get_functiondef('public.lts_browser_flow_v228(date,date)'::regprocedure);
 definition:=replace(definition,'jsonb_array_elements(added) observed WHERE (observed->>''event_date'')',
  'jsonb_array_elements(added) observed_entry WHERE (observed_entry->>''event_date'')');
 EXECUTE definition;
END $migration$;
