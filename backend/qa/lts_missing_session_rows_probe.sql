-- Count only owner-scoped financial rows, without creating an identity or claims.
-- Health, shared catalog rows, authentication records and stored file bytes are excluded.
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='8s';
SET LOCAL lock_timeout='1s';
SET LOCAL search_path='pg_catalog','public';
DO $probe$
DECLARE r record;role_name text;n bigint;code text;checks jsonb:='[]'::jsonb;private_buckets boolean;bucket_count integer;
BEGIN
 IF auth.uid() IS NOT NULL THEN RAISE EXCEPTION 'Probe requires an administrative connection without an application identity';END IF;
 FOR r IN
  SELECT DISTINCT c.oid,c.relname,c.relkind,a.attname owner_column,c.relrowsecurity
  FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
  WHERE s.nspname='public' AND c.relkind IN('r','p','v','m') AND a.attnum>0 AND NOT a.attisdropped
   AND a.attname IN('user_id','usuario_id') AND a.atttypid='uuid'::regtype
   AND (c.relname LIKE 'lts_%' OR c.relname IN('accounts','financial_events','source_documents','card_invoices',
    'evento_base','historico_analitico','evento_usuario','liquidez_ativo','liquidez_ajuste','cartao','billing_account',
    'fatura','compra_parcelada','compromisso','contrato','classificacao','categoria_regra','reconciliacao',
    'saldo_snapshot','deslocamento','divergencia','cotacao','fgts','inbox_item','projecao_op','pacote_documental',
    'auditoria_patrimonio','legacy_namespace'))
   AND c.relname NOT LIKE 'lts_health_%'
  ORDER BY c.relname,a.attname
 LOOP
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
   n:=NULL;code:=NULL;
   EXECUTE format('SET LOCAL ROLE %I',role_name);
   BEGIN
    EXECUTE format('SELECT count(*) FROM public.%I WHERE %I IS NOT NULL',r.relname,r.owner_column) INTO n;
   EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE;
   END;
   EXECUTE 'RESET ROLE';
   checks:=checks||jsonb_build_array(jsonb_build_object('relation',r.relname,'kind',r.relkind,
    'owner_column',r.owner_column,'role',role_name,'owner_rows_visible',n,'sql_state',code,
    'pass',(code IS NULL AND n=0) OR code='42501'));
  END LOOP;
 END LOOP;
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  n:=NULL;code:=NULL;
  EXECUTE format('SET LOCAL ROLE %I',role_name);
  BEGIN
   SELECT count(*) INTO n FROM storage.objects WHERE bucket_id IN('lts-documents','lts-web');
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  checks:=checks||jsonb_build_array(jsonb_build_object('relation','storage.objects','scope','financial_buckets',
   'role',role_name,'owner_rows_visible',n,'sql_state',code,'pass',(code IS NULL AND n=0) OR code='42501'));
 END LOOP;
 SELECT count(*),coalesce(bool_and(NOT public),false) INTO bucket_count,private_buckets FROM storage.buckets
 WHERE id IN('lts-documents','lts-web');
 PERFORM set_config('lts.missing_session_rows_probe',jsonb_build_object('pass',jsonb_array_length(checks)>2 AND NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(checks)x WHERE x->>'pass' IS DISTINCT FROM 'true') AND private_buckets AND bucket_count=2,
  'application_identity_missing',true,'claims_modified',false,'relation_role_cases',jsonb_array_length(checks),
  'checks',checks,'financial_bucket_count',bucket_count,'financial_buckets_private',private_buckets,
  'source_mutations',false,'health_excluded',true,'stored_file_bytes_read',false,
  'native_database_role_test',true,'signed_http_identity_test',false,'transaction','ROLLBACK')::text,true);
END $probe$;
SELECT current_setting('lts.missing_session_rows_probe')::jsonb receipt;
ROLLBACK;
