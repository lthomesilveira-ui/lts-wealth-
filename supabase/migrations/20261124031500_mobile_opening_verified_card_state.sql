-- Reuse the existing complete snapshot while the projection worker is busy.
-- Only the compact mobile read opts in. All publication/owner/source checks
-- below the insertion stay identical, including the final independent recheck.
DO $migration$
DECLARE
  reader text:=pg_get_functiondef('public.lts_browser_product_v1()'::regprocedure);
  mobile text:=pg_get_functiondef('public.lts_browser_product_v1(integer)'::regprocedure);
  anchor text:='   card_state:=lts_product_refresh_private_v415.card_state_cached(v_uid);';
  mobile_anchor text:='  response := public.lts_browser_product_v1();';
BEGIN
  IF md5(reader)<>'221a76c43729189fb3efcc06b99e3495' OR md5(mobile)<>'40b1129208e5eba2779083db72a7eb35' THEN
    RAISE EXCEPTION 'Opening readers changed; review before applying';
  END IF;
  EXECUTE replace(reader,anchor,anchor||$fragment$
   IF card_state IS NULL AND current_setting('lts.mobile_opening_cards',true)='on'
      AND refresh->>'state' IN ('pending','running')
      AND public.lts_has_card_presentation_v269()
      AND pg_try_advisory_xact_lock(hashtextextended(v_uid::text,496)) THEN
    BEGIN
     -- A cold card check uses the same canonical source as the full worker.
     -- The existing read below still withholds the product if publication lost
     -- the revision race or optional cache persistence encountered contention.
     card_state:=public.lts_c6_completeness_state_v269(v_uid);
    EXCEPTION WHEN serialization_failure OR lock_not_available THEN
     card_state:=NULL;
    END;
   END IF;$fragment$);
  EXECUTE replace(mobile,mobile_anchor,
    '  perform set_config(''lts.mobile_opening_cards'',''on'',true);'||chr(10)||mobile_anchor||
    chr(10)||'  perform set_config(''lts.mobile_opening_cards'','''',true);');
END $migration$;
