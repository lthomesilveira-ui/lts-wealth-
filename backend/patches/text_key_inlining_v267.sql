-- Allow PostgreSQL to inline two pure text expressions. Their expressions,
-- null behavior, volatility, owner and existing ACLs remain unchanged.
-- No source data, reader contracts, cache keys or client grants are changed.
-- Every callable expression is explicitly bound to pg_catalog/public.
DO $patch$
DECLARE target regprocedure; d text; original_acl aclitem[]; original_owner oid;
 expected text; replacement text;
BEGIN
 FOR target IN SELECT unnest(ARRAY[
  'public.lts_v178_norm(text)'::regprocedure,
  'public.lts_bank_merchant_key_v231(text)'::regprocedure
 ]) LOOP
  SELECT pg_get_functiondef(target),proacl,proowner INTO d,original_acl,original_owner
  FROM pg_proc WHERE oid=target;
  expected:=CASE WHEN target='public.lts_v178_norm(text)'::regprocedure
   THEN '8bd38f36cd64245bdf8a84464a298839'
   ELSE 'ef89d710865b5103d08187c39226e53f' END;
  IF md5(d)<>expected THEN RAISE EXCEPTION 'text expression definition lease changed: %',target; END IF;
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=target AND
   (prosecdef OR proisstrict OR provolatile<>'i' OR prolang<>(SELECT oid FROM pg_language WHERE lanname='sql')
    OR proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[]))
  THEN RAISE EXCEPTION 'unexpected text helper execution contract: %',target; END IF;
  IF target='public.lts_bank_merchant_key_v231(text)'::regprocedure THEN
   -- With the prior empty search_path these four calls already resolved to
   -- pg_catalog. Spell that binding explicitly before removing the SET clause.
   replacement:=replace(d,'regexp_replace(', 'pg_catalog.regexp_replace(');
   IF (length(d)-length(replace(d,'regexp_replace(','')))/length('regexp_replace(')<>4
   THEN RAISE EXCEPTION 'merchant expression anchor changed'; END IF;
   EXECUTE replacement;
  END IF;
  EXECUTE format('ALTER FUNCTION public.%I(text) RESET search_path',
   (SELECT proname FROM pg_proc WHERE oid=target));
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=target AND
   (proacl IS DISTINCT FROM original_acl OR proowner IS DISTINCT FROM original_owner
    OR prosecdef OR proisstrict OR provolatile<>'i' OR proconfig IS NOT NULL))
  THEN RAISE EXCEPTION 'text helper privileges or semantics changed: %',target; END IF;
  IF has_function_privilege('anon',target,'EXECUTE') OR has_function_privilege('authenticated',target,'EXECUTE')
  THEN RAISE EXCEPTION 'internal text helper exposed: %',target; END IF;
 END LOOP;
 -- Derived cached responses are identical: no financial or source invalidation
 -- is required for this execution-only optimization. Cold QA uses a rolled-back
 -- epoch increment so no earlier payload can hide a changed expression.
END;
$patch$;
