-- Restrict unused invoker pending-card helpers to their existing owner/service.
-- Does not execute a reconciler, alter financial rows, or change function bodies.
DO $guard$
DECLARE t record;p regprocedure;identity_before jsonb;
BEGIN
PERFORM pg_catalog.set_config('lock_timeout','3s',true);
FOR t IN SELECT * FROM(VALUES
 ('public.lts_open_finance_card_pending_v1(text)','4405ca2f4b8858d18c675784758f05ed'),
 ('public.lts_open_finance_pending_card_expense_v1(text)','385f181a9cab6e25383fa18965006266')
)x(signature,expected_md5) LOOP
p:=t.signature::regprocedure;
IF pg_catalog.md5(pg_catalog.pg_get_functiondef(p))<>t.expected_md5
THEN RAISE EXCEPTION 'Pending helper definition mismatch: %',t.signature;END IF;
SELECT pg_catalog.to_jsonb(x)-'proacl' INTO identity_before FROM pg_catalog.pg_proc x WHERE x.oid=p;
IF (SELECT prosecdef FROM pg_catalog.pg_proc WHERE oid=p)
OR NOT pg_catalog.has_function_privilege('service_role',p,'EXECUTE')
OR EXISTS(SELECT 1 FROM pg_catalog.pg_proc x CROSS JOIN LATERAL pg_catalog.aclexplode(coalesce(x.proacl,pg_catalog.acldefault('f',x.proowner)))a
 WHERE x.oid=p AND a.grantee NOT IN(0,'postgres'::regrole,'service_role'::regrole))
THEN RAISE EXCEPTION 'Unexpected pending helper security/ACL baseline: %',t.signature;END IF;
EXECUTE pg_catalog.format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',t.signature);
IF pg_catalog.has_function_privilege('anon',p,'EXECUTE')
OR pg_catalog.has_function_privilege('authenticated',p,'EXECUTE')
OR NOT pg_catalog.has_function_privilege('service_role',p,'EXECUTE')
OR identity_before IS DISTINCT FROM(SELECT pg_catalog.to_jsonb(x)-'proacl' FROM pg_catalog.pg_proc x WHERE x.oid=p)
THEN RAISE EXCEPTION 'Pending helper access/identity verification failed: %',t.signature;END IF;
END LOOP;
END $guard$;
