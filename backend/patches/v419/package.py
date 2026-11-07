from pathlib import Path
P=Path(__file__).resolve().parent
prefix="""BEGIN;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL TimeZone='America/Sao_Paulo';
DO $idle$ DECLARE u uuid; BEGIN
 IF to_regnamespace('lts_fgts_private_v419') IS NOT NULL THEN RAISE EXCEPTION 'V419 already present'; END IF;
 FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue ORDER BY user_id LOOP
  IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'Refresh active; defer installation'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'Refresh claim active; defer installation'; END IF;
END $idle$;
"""
suffix="""DO $request$ DECLARE u uuid; BEGIN
 FOR u IN SELECT user_id FROM public.lts_product_read_cache WHERE lts_product_refresh_private_v415.allowed_owner(user_id) ORDER BY user_id LOOP
  PERFORM lts_product_refresh_private_v415.enqueue(u,'cache_read',false);
 END LOOP;
END $request$;
COMMIT;
"""
def compose():
 return prefix+'\n'.join((P/name).read_text() for name in ['helpers.sql','economic_identity.sql','rewire.sql','ladder.sql','metadata.sql'])+suffix
if __name__=='__main__':print(compose(),end='')
