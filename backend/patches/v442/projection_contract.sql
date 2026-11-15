-- Pure read-contract adapter. No source records or financial amounts are changed.
CREATE OR REPLACE FUNCTION lts_month_private_v393.projection_contract_v442(p_payload jsonb,p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $fn$
DECLARE ca jsonb; cy jsonb; i jsonb; cards jsonb:='[]'; cycles jsonb;
 projected numeric; total numeric; seen text[]:=ARRAY[]::text[]; k text;
BEGIN
 IF jsonb_typeof(p_payload->'cards') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid cycle cards'; END IF;
 FOR ca IN SELECT value FROM jsonb_array_elements(p_payload->'cards') LOOP
 IF jsonb_typeof(ca->'cycles') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid cycles'; END IF;
 cycles:='[]';
 FOR cy IN SELECT value FROM jsonb_array_elements(ca->'cycles') LOOP
 IF (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date THEN
 k:=(ca->>'family')||':'||(cy->>'month');
 IF k IS NULL OR k=ANY(seen) THEN RAISE EXCEPTION 'Ambiguous family cycle'; END IF;
 seen:=array_append(seen,k);
 IF jsonb_typeof(cy->'items') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Missing cycle details'; END IF;
 projected:=0;total:=0;
 FOR i IN SELECT value FROM jsonb_array_elements(cy->'items') LOOP
 IF NOT coalesce((i->>'is_payment')::boolean,false) THEN
 IF i->>'amount' IS NULL THEN RAISE EXCEPTION 'Missing cycle item amount'; END IF;
 total:=total+(i->>'amount')::numeric;
 IF i->>'provider_status'='PROJECTED' THEN projected:=projected+(i->>'amount')::numeric; END IF;
 END IF;
 END LOOP;
 -- Only repair an absent split when independent canonical total proves full coverage.
 -- Explicit splits, including zero, remain untouched for the existing guard.
 IF cy->>'projected_amount' IS NULL AND projected<>0 THEN
 IF cy->>'amount' IS NULL OR cy->>'complete'='false' OR abs((cy->>'amount')::numeric-total)>.005 THEN
 RAISE EXCEPTION 'Cannot derive projected split from incomplete cycle';
 END IF;
 IF cy->>'received_amount' IS NOT NULL AND abs((cy->>'received_amount')::numeric-(total-projected))>.005 THEN RAISE EXCEPTION 'Received split mismatch'; END IF;
 cy:=cy||jsonb_build_object('projected_amount',projected,'received_amount',total-projected,
 'projection_split_basis','reconciled_cycle_items_v442');
 END IF;
 END IF;
 cycles:=cycles||jsonb_build_array(cy);
 END LOOP;
 cards:=cards||jsonb_build_array(ca||jsonb_build_object('cycles',cycles));
 END LOOP;
 RETURN p_payload||jsonb_build_object('cards',cards);
END $fn$;
REVOKE ALL ON FUNCTION lts_month_private_v393.projection_contract_v442(jsonb,date,date) FROM PUBLIC;
