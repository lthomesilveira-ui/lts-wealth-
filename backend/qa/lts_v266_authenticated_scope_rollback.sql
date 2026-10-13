BEGIN;
SET LOCAL statement_timeout='55s';
SELECT set_config('request.jwt.claims','{}',true);
SET LOCAL ROLE authenticated;
DO $probe$
DECLARE p record; call_args text; total integer:=0; denied integer:=0; accepted text[]:=ARRAY[]::text[]; other_errors jsonb:='[]'::jsonb;
BEGIN
 FOR p IN
  SELECT n.nspname,f.proname,f.proargtypes,f.oid
  FROM pg_proc f JOIN pg_namespace n ON n.oid=f.pronamespace
  WHERE n.nspname='public' AND f.prosecdef AND f.prokind='f'
  AND f.proname LIKE 'lts_%' AND has_function_privilege('authenticated',f.oid,'EXECUTE')
  ORDER BY f.proname,f.oid
 LOOP
  SELECT string_agg('NULL::'||format_type(x,NULL),',' ORDER BY ord) INTO call_args
  FROM unnest(p.proargtypes::oid[]) WITH ORDINALITY t(x,ord);
  total:=total+1;
  BEGIN
   EXECUTE format('SELECT %I.%I(%s)',p.nspname,p.proname,coalesce(call_args,''));
   accepted:=array_append(accepted,p.proname);
  EXCEPTION WHEN insufficient_privilege THEN denied:=denied+1;
  WHEN OTHERS THEN other_errors:=other_errors||jsonb_build_array(jsonb_build_object('name',p.proname,'state',SQLSTATE,'error',SQLERRM));
  END;
 END LOOP;
 PERFORM set_config('lts.v266_access_probe',jsonb_build_object('total',total,'denied_42501',denied,
 'accepted_without_identity',accepted,'other_errors',other_errors,'pass',total>0 AND total=denied,
 'test_identity','authenticated database role without subject/email claims','all_effects','rolled_back')::text,true);
END; $probe$;
SELECT current_setting('lts.v266_access_probe')::jsonb receipt;
ROLLBACK;