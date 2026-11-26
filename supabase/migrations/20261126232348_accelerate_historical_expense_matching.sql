SET LOCAL lock_timeout = '2s';
-- Use PostgreSQL's JSONB equality hash for historical workbook evidence.
CREATE INDEX lts_historico_document_payload_hash
  ON public.historico_analitico USING hash ((dados - 'h'::text));

-- Match historical source IDs once per request. Keep the same owner, date and
-- duplicate checks for direct IDs and for financial events with a legacy ID.
DO $patch$
DECLARE
  target regprocedure := 'public.lts_expense_matched_bank_rows_v445(uuid,date,date)'::regprocedure;
  definition text := pg_get_functiondef(target);
  old_refs text := $oldrefs$SELECT * FROM public.lts_expense_effective_rows_v176(p_user_id,date '2013-10-10',greatest(p_to,current_date))
), unmatched AS MATERIALIZED ($oldrefs$;
  new_refs text := $newrefs$SELECT DISTINCT e.source_ref
 FROM public.lts_expense_effective_rows_v176(p_user_id,date '2013-10-10',greatest(p_to,current_date)) e
 WHERE e.source_ref IS NOT NULL
), existing_legacy_refs AS MATERIALIZED (
 SELECT DISTINCT f.legacy_id
 FROM public.financial_events f JOIN existing e ON e.source_ref=f.id::text
 WHERE f.user_id=p_user_id AND f.legacy_id IS NOT NULL
), unmatched AS MATERIALIZED ($newrefs$;
  old_match text := $oldmatch$AND NOT EXISTS(SELECT 1 FROM existing e WHERE e.source_ref IN(s.id::text,s.operational_event->>'source_ref')
   OR EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id=p_user_id
    AND f.legacy_id=s.operational_event->>'source_ref' AND e.source_ref=f.id::text))$oldmatch$;
  new_match text := $newmatch$AND NOT EXISTS(SELECT 1 FROM existing e WHERE e.source_ref IN(s.id::text,s.operational_event->>'source_ref'))
 AND NOT EXISTS(SELECT 1 FROM existing_legacy_refs e WHERE e.legacy_id=s.operational_event->>'source_ref')$newmatch$;
BEGIN
  IF array_length(string_to_array(definition,old_refs),1) IS DISTINCT FROM 2 OR
     array_length(string_to_array(definition,old_match),1) IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Historical bank matching definition changed';
  END IF;
  EXECUTE replace(replace(definition,old_refs,new_refs),old_match,new_match);
END
$patch$;

-- Two published financial readers changed their implementation. The newer cash
-- reader also calls the documented reservation reader. Its five input tables
-- already participate in the review invalidation contract. Pin every reviewed
-- definition, including the new dependency, before reusing a stored review.
DO $profile$
DECLARE
  profile_target regprocedure := 'lts_product_refresh_private_v415.review_profile_v450()'::regprocedure;
  guard_target regprocedure := 'lts_product_refresh_private_v415.review_guard_v450(uuid)'::regprocedure;
  profile jsonb := lts_product_refresh_private_v415.review_profile_v450();
  updated_profile jsonb;
  expected record;
  old_body text;
BEGIN
  PERFORM set_config('search_path','',true);
  IF md5(profile::text) <> 'c4e51592379f1caca088b740531ce940'
     OR md5(pg_get_functiondef(profile_target)) <> 'c260b88201d1f28f30f33a704c074282'
     OR md5(pg_get_functiondef(guard_target)) <> '1980c0b758f19f33625b73375ac9090d' THEN
    RAISE EXCEPTION 'Review version changed';
  END IF;
  WITH reviewed(signature, hash) AS (VALUES
      ('public.lts_bank_known_classification_v231(uuid,uuid)','87ce37857b3061e77d0b4edd3aee6fc3'),
      ('public.lts_corrected_cashflow_fix86_v4(uuid,date,date)','efd433531450039cd5fde3e1b5fe2112'),
      ('public.lts_expense_matched_bank_rows_v445(uuid,date,date)','5bace02c82d64a2a8839195b29f0bfc5'),
      ('public.lts_posted_contract_reservations_v498(uuid,date,date)','12865142725e2b5f638c9446056be945')),
    producers AS (
      SELECT existing.value || jsonb_build_object('md5', coalesce(r.hash,existing.value->>'md5')) AS value, existing.ord
      FROM jsonb_array_elements(profile->'producers') WITH ORDINALITY existing(value,ord)
      LEFT JOIN reviewed r ON r.signature=existing.value->>'signature'
      UNION ALL
      SELECT jsonb_build_object('signature',r.signature,'md5',r.hash),9223372036854775807::bigint
      FROM reviewed r WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(profile->'producers') e WHERE e->>'signature'=r.signature))
    SELECT jsonb_set(profile,'{producers}',jsonb_agg(value ORDER BY ord)) INTO updated_profile FROM producers;
  IF md5(updated_profile::text) <> '8db4746544dd61af702055203b2c9876' THEN RAISE EXCEPTION 'Unexpected review dependency list'; END IF;
  FOR expected IN SELECT value->>'signature' AS signature,value->>'md5' AS hash
    FROM jsonb_array_elements(updated_profile->'producers') LOOP
    IF md5(pg_get_functiondef(to_regprocedure(expected.signature))) IS DISTINCT FROM expected.hash THEN
      RAISE EXCEPTION 'Review dependency changed: %', expected.signature;
    END IF;
  END LOOP;
  SELECT prosrc INTO STRICT old_body FROM pg_proc WHERE oid=profile_target;
  EXECUTE replace(pg_get_functiondef(profile_target),old_body,format(' SELECT %L::jsonb ',updated_profile::text));
  EXECUTE replace(pg_get_functiondef(guard_target),'c4e51592379f1caca088b740531ce940','8db4746544dd61af702055203b2c9876');
END
$profile$;
