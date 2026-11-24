-- A quantity-only reference can be reconciled by a full statement later that day.
-- Match the linked source evidence as well as the owner, date and statement totals.
DO $migration$
DECLARE
  target regprocedure := 'public.lts_brokerage_reference_v352(uuid)'::regprocedure;
  original text := pg_get_functiondef(target);
  marker text := 's.as_of_date > coalesce(r.position_as_of, r.received_on)';
  replacement text := $filter$(
         s.as_of_date > coalesce(r.position_as_of, r.received_on)
         OR (s.as_of_date = coalesce(r.position_as_of, r.received_on)
             AND s.metadata->>'quantity_reference_id' = r.id::text
             AND s.metadata->>'quantity_evidence_sha256' = r.source_sha256
             AND s.total_gross_brl = r.total_gross_brl
             AND s.available_total_brl = r.available_total_brl
             AND s.unavailable_total_brl = r.unavailable_total_brl)
       )$filter$;
BEGIN
  IF position(replacement IN original) > 0 THEN RETURN; END IF;
  IF (length(original) - length(replace(original, marker, ''))) <> length(marker) THEN
    RAISE EXCEPTION 'Unexpected brokerage reference reader definition';
  END IF;
  EXECUTE replace(original, marker, replacement);
END
$migration$;
