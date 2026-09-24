-- Use already-applied, checksum-backed statement evidence for maintenance freshness.
-- Read-only correction: account balances, documents, classifications and ACLs are unchanged.
DO $repair$
DECLARE
  definition text;
  expected_fragment text := $old$max(e.evidence_date) filter(where e.evidence_type='bank_statement' and e.status='documented') last_evidence$old$;
  replacement_fragment text := $new$greatest(max(e.evidence_date) filter(where e.evidence_type='bank_statement' and e.status='documented'),
           max(CASE WHEN pg_input_is_valid(a.metadata->>'balance_as_of','date')
 AND nullif(trim(a.metadata->>'evidence'),'') IS NOT NULL
 AND a.metadata->>'evidence' ~* '(statement|extrato)'
 AND CASE jsonb_typeof(a.metadata->'evidence_sha256')
   WHEN 'string' THEN a.metadata->>'evidence_sha256' ~ '^[0-9a-fA-F]{64}$'
   WHEN 'array' THEN jsonb_array_length(a.metadata->'evidence_sha256')>0
     AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(a.metadata->'evidence_sha256') h(value)
       WHERE h.value IS NULL OR h.value !~ '^[0-9a-fA-F]{64}$')
   ELSE false END
 THEN CASE WHEN (a.metadata->>'balance_as_of')::date<=current_date
   THEN (a.metadata->>'balance_as_of')::date END
 END)) last_evidence$new$;
  invalid_cases integer;
  before_other_checks jsonb;
  after_other_checks jsonb;
  before_accounts text;
  after_accounts text;
BEGIN
  -- Synthetic provenance cases run against exactly the predicate installed below.
  WITH proof AS (
    SELECT jsonb_build_object('balance_as_of',(current_date-2)::text,
      'evidence','Synthetic bank statement','evidence_sha256',repeat('a',64)) m
  ), fixtures AS (
    SELECT m metadata,current_date-2 expected FROM proof
    UNION ALL SELECT m-'evidence_sha256',null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('evidence_sha256','not-a-checksum'),null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('evidence_sha256','[]'::jsonb),null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('evidence_sha256',jsonb_build_array(repeat('b',64))),current_date-2 FROM proof
    UNION ALL SELECT m||jsonb_build_object('evidence_sha256',jsonb_build_array(repeat('b',64),'bad')),null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('balance_as_of','not-a-date'),null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('balance_as_of',(current_date+1)::text),null::date FROM proof
    UNION ALL SELECT m||jsonb_build_object('evidence','Balance estimate only'),null::date FROM proof
  )
  SELECT count(*) INTO invalid_cases FROM fixtures a
   WHERE (CASE WHEN pg_input_is_valid(a.metadata->>'balance_as_of','date')
 AND nullif(trim(a.metadata->>'evidence'),'') IS NOT NULL
 AND a.metadata->>'evidence' ~* '(statement|extrato)'
 AND CASE jsonb_typeof(a.metadata->'evidence_sha256')
   WHEN 'string' THEN a.metadata->>'evidence_sha256' ~ '^[0-9a-fA-F]{64}$'
   WHEN 'array' THEN jsonb_array_length(a.metadata->'evidence_sha256')>0
     AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(a.metadata->'evidence_sha256') h(value)
       WHERE h.value IS NULL OR h.value !~ '^[0-9a-fA-F]{64}$')
   ELSE false END
 THEN CASE WHEN (a.metadata->>'balance_as_of')::date<=current_date
   THEN (a.metadata->>'balance_as_of')::date END
 END) IS DISTINCT FROM expected;
  IF invalid_cases<>0 THEN RAISE EXCEPTION 'Statement provenance fixture failed'; END IF;

  SELECT pg_get_functiondef('public.lts_updates_fix86plus_v8(uuid)'::regprocedure) INTO definition;
  IF strpos(definition,expected_fragment)=0 OR strpos(definition,replacement_fragment)>0
    OR (length(definition)-length(replace(definition,expected_fragment,'')))/length(expected_fragment)<>1 THEN
    RAISE EXCEPTION 'Maintenance reader changed; review migration';
  END IF;
  SELECT md5(string_agg(to_jsonb(a)::text,E'\n' ORDER BY a.id)) INTO before_accounts FROM public.accounts a;
  SELECT jsonb_agg(jsonb_build_object('user',u.user_id,'check',c.x) ORDER BY u.user_id,c.x->>'id')
   INTO before_other_checks
   FROM (SELECT DISTINCT user_id FROM public.accounts) u
   CROSS JOIN LATERAL jsonb_array_elements(public.lts_updates_fix86plus_v8(u.user_id)->'maintenance_checks') c(x)
   WHERE c.x->>'kind'<>'bank_statement';

  EXECUTE replace(definition,expected_fragment,replacement_fragment);

  SELECT md5(string_agg(to_jsonb(a)::text,E'\n' ORDER BY a.id)) INTO after_accounts FROM public.accounts a;
  SELECT jsonb_agg(jsonb_build_object('user',u.user_id,'check',c.x) ORDER BY u.user_id,c.x->>'id')
   INTO after_other_checks
   FROM (SELECT DISTINCT user_id FROM public.accounts) u
   CROSS JOIN LATERAL jsonb_array_elements(public.lts_updates_fix86plus_v8(u.user_id)->'maintenance_checks') c(x)
   WHERE c.x->>'kind'<>'bank_statement';
  IF before_accounts IS DISTINCT FROM after_accounts OR before_other_checks IS DISTINCT FROM after_other_checks THEN
    RAISE EXCEPTION 'Accounts or unrelated maintenance checks changed';
  END IF;
END $repair$;
