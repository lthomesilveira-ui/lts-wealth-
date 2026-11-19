-- The product read can join a confirmed outstanding refresh using its status.
-- Inserting into the queue, even ON CONFLICT DO NOTHING, fires its statement
-- triggers and can wait for the refresh transaction's review revision lock.
DO $migration$
DECLARE
  target regprocedure := 'public.lts_browser_product_v1()'::regprocedure;
  original text;
  old_call text := $old$  refresh:=lts_product_refresh_private_v415.enqueue(v_uid,'cache_read',false);$old$;
  replacement text := $new$  IF NOT coalesce(
    refresh->>'state' IN ('pending','running')
    AND (refresh->>'request_version')::bigint > (refresh->>'completed_version')::bigint, false
  ) THEN
    refresh:=lts_product_refresh_private_v415.enqueue(v_uid,'cache_read',false);
  END IF;$new$;
BEGIN
  PERFORM set_config('search_path','',true);
  original := pg_get_functiondef(target);
  IF md5(original) IS DISTINCT FROM '51ac0b37b9a93a93ccfe29f00b4b82ff'
     OR array_length(string_to_array(original,old_call),1) IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Unexpected product read definition';
  END IF;
  EXECUTE replace(original,old_call,replacement);
END $migration$;
