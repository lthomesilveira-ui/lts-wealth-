-- Retain older brokerage evidence in the audit table. Only unresolved
-- references newer than the current documented position belong in the live view.
DO $migration$
DECLARE
  target regprocedure := 'public.lts_brokerage_reference_v352(uuid)'::regprocedure;
  original text;
  attributes jsonb;
  marker text := 'r.received_on<=current_date';
  replacement text := $filter$r.received_on<=current_date
   AND NOT EXISTS (
     SELECT 1
     FROM public.lts_brokerage_position_snapshots s
     WHERE s.user_id = r.user_id
       AND s.institution = r.institution
       AND s.as_of_date > coalesce(r.position_as_of, r.received_on)
       AND s.as_of_date <= current_date
       AND s.metadata->>'documentary_current_position' = 'true'
   )$filter$;
BEGIN
  SELECT pg_get_functiondef(p.oid), to_jsonb(p)-'prosrc'
    INTO STRICT original, attributes
    FROM pg_proc p WHERE p.oid=target;
  IF position(replacement IN original)>0 THEN
    RETURN;
  END IF;
  IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN
    RAISE EXCEPTION 'Unexpected brokerage reference reader definition';
  END IF;
  EXECUTE replace(original,marker,replacement);
  IF attributes IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target) THEN
    RAISE EXCEPTION 'Brokerage reference reader attributes changed';
  END IF;
END
$migration$;
