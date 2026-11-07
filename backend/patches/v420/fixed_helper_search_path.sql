-- Metadata-only hardening of two existing, fully qualified pure helpers.
-- No changes to source bodies, results, ownership or execution grants.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
CREATE TEMP TABLE v420_helper_attributes ON COMMIT DROP AS
SELECT p.oid,to_jsonb(p)-'proconfig' AS unchanged_attributes,p.proconfig
FROM pg_catalog.pg_proc p
WHERE p.oid IN('public.lts_v178_norm(text)'::regprocedure,
 'public.lts_bank_merchant_key_v231(text)'::regprocedure);
DO $guard$
DECLARE r record; definition text; settings text[];
BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('public.lts_v178_norm(text)','b1bee691efca2e2aea67c7e2256902c8'),
  ('public.lts_bank_merchant_key_v231(text)','abec6a1431a2548d25be345e167f1000')
 ) x(signature,expected_md5) LOOP
  SELECT pg_catalog.pg_get_functiondef(p.oid),p.proconfig INTO definition,settings
  FROM pg_catalog.pg_proc p WHERE p.oid=pg_catalog.to_regprocedure(r.signature);
  IF settings IS NOT NULL AND settings IS DISTINCT FROM ARRAY['search_path=""']::text[] THEN
   RAISE EXCEPTION 'Unexpected helper execution settings; review before applying';
  END IF;
  IF pg_catalog.md5(pg_catalog.replace(definition,E' SET search_path TO ''''\n','')) IS DISTINCT FROM r.expected_md5 THEN
   RAISE EXCEPTION 'Unexpected helper predecessor: %',r.signature;
  END IF;
 END LOOP;
END $guard$;
ALTER FUNCTION public.lts_v178_norm(text) SET search_path='';
ALTER FUNCTION public.lts_bank_merchant_key_v231(text) SET search_path='';
DO $verify$
BEGIN
 IF (SELECT count(*) FROM v420_helper_attributes)<>2 THEN RAISE EXCEPTION 'Missing helper'; END IF;
 IF EXISTS(SELECT 1 FROM v420_helper_attributes b JOIN pg_catalog.pg_proc p USING(oid)
  WHERE b.unchanged_attributes IS DISTINCT FROM to_jsonb(p)-'proconfig'
   OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[]) THEN
  RAISE EXCEPTION 'Unexpected change beyond the fixed search path';
 END IF;
END $verify$;
COMMIT;
