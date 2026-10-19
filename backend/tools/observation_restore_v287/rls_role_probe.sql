BEGIN READ ONLY;
DO $probe$
DECLARE tables text[];t text;test_case text;role_name text;claims text;subject uuid;n bigint;outcome text;results jsonb:='[]';passed boolean:=true;
BEGIN
SELECT array_agg(c.table_name ORDER BY c.table_name) INTO tables
FROM information_schema.columns c JOIN pg_tables t ON t.schemaname=c.table_schema AND t.tablename=c.table_name
WHERE c.table_schema='public' AND c.column_name='user_id' AND c.udt_name='uuid' AND c.table_name NOT LIKE 'health_%';
FOREACH test_case IN ARRAY ARRAY['anon_no_identity','authenticated_no_identity','authenticated_foreign_identity'] LOOP
role_name:=CASE WHEN test_case='anon_no_identity' THEN 'anon' ELSE 'authenticated' END;
subject:=CASE WHEN test_case='authenticated_foreign_identity' THEN '00000000-0000-4000-8000-000000000287'::uuid ELSE NULL END;
claims:=jsonb_build_object('role',role_name,'sub',subject)::text;
FOREACH t IN ARRAY tables LOOP
PERFORM set_config('request.jwt.claim.sub',coalesce(subject::text,''),true);
PERFORM set_config('request.jwt.claims',claims,true);
PERFORM set_config('role',role_name,true);
n:=NULL;
BEGIN
EXECUTE format('SELECT count(*) FROM public.%I WHERE user_id IS DISTINCT FROM $1',t) INTO n USING subject;
outcome:=CASE WHEN n=0 THEN 'zero_foreign_rows' ELSE 'FAIL_visible_foreign_rows' END;
EXCEPTION WHEN insufficient_privilege THEN outcome:='permission_denied';
WHEN OTHERS THEN outcome:='FAIL_'||SQLSTATE;
END;
PERFORM set_config('role','none',true);
IF outcome LIKE 'FAIL%' THEN passed:=false;END IF;
results:=results||jsonb_build_array(jsonb_build_object('case',test_case,'table',t,'outcome',outcome,'foreign_rows',n));
END LOOP;
END LOOP;
PERFORM set_config('request.jwt.claim.sub','',true);
PERFORM set_config('request.jwt.claims','{}',true);
PERFORM set_config('lts.rls_probe_v287',jsonb_build_object('pass',passed,'captured_at',clock_timestamp(),'owner_tables_tested',array_length(tables,1),'cases',jsonb_array_length(results),'results',results,'scope','read-only PostgreSQL role/claims test; no signed HTTP session, Health tables excluded','production_rows_written',false)::text,true);
END $probe$;
SELECT current_setting('lts.rls_probe_v287')::jsonb AS result;
ROLLBACK;
