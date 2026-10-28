-- Add source identities for presentation deduplication; preserve every count and financial row.
DO $$
DECLARE definition text;needle text:=' RETURN result;';replacement text:=$expr$ RETURN result||jsonb_build_object('review_source_refs',(SELECT coalesce(jsonb_agg(x->>'source_ref' ORDER BY x->>'source_ref'),'[]'::jsonb)FROM jsonb_array_elements(pending)x));$expr$;
BEGIN
 definition:=pg_get_functiondef('public.lts_browser_card_review_queue_v312(date,date,integer,integer,text)'::regprocedure);
 IF strpos(definition,replacement)>0 THEN RETURN;END IF;
 IF md5(definition)<>'6b6703bd0f5f856825e50a77c076a3c3' THEN RAISE EXCEPTION 'Card queue changed; inspect current definition';END IF;
 IF(length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'Queue return is not unique';END IF;
 EXECUTE replace(definition,needle,replacement);
END $$;
