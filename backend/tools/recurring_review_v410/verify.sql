CREATE TEMP TABLE v410_results(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass));
DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';j jsonb;b jsonb;s jsonb;entry jsonb;d jsonb;
 target text:='variable household budget';as_of date;date_case date;bad text;failed boolean;
 original_sources text;after_sources text;namespace_backup jsonb;closed_item jsonb;
BEGIN
 SELECT payload INTO b FROM v410_before;
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF j IS DISTINCT FROM b THEN RAISE EXCEPTION 'Absent namespace changed baseline';END IF;
 INSERT INTO v410_results VALUES('absent_namespace_exact_baseline',true);
 SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY source_ref)::text) INTO original_sources FROM public.v410_fixture_flow x;
 SELECT jsonb_build_object('schema','lts-recurring-review-scope-v1','entries',jsonb_agg(
  jsonb_build_object('control_id','SYNTHETIC-'||key,'key',key,'title',title,'direction',direction,'cadence',cadence,
   'opened_on','2026-10-20','opening_evidence',jsonb_build_object('kind','existing_control_review',
    'reference','synthetic-existing-control','content','Synthetic existing unresolved review.',
    'sha256',encode(sha256(convert_to('Synthetic existing unresolved review.','UTF8')),'hex')),'decisions','[]'::jsonb)
  ORDER BY key)) INTO s FROM (
  SELECT x->>'key'key,x->>'title'title,x->>'direction'direction,x->>'cadence'cadence
  FROM jsonb_array_elements(b->'horizon_checks')x WHERE (x->>'gap_count')::integer>0
  UNION ALL SELECT target,'Variable household budget','expense','monthly')entries;
 IF jsonb_array_length(s->'entries')<>13 THEN RAISE EXCEPTION 'Synthetic seed must contain13 existing open reviews';END IF;
 PERFORM public.v410_fixture_put(s);
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF jsonb_array_length(j->'horizon_checks')<>17 OR (j->>'horizon_review_count')::integer<>13 THEN RAISE EXCEPTION 'Wrong scope delta';END IF;
 IF (SELECT jsonb_agg(x) FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'<>target)
   IS DISTINCT FROM b->'horizon_checks' THEN RAISE EXCEPTION 'Existing16 items changed';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target AND x->>'cadence'='monthly' AND x->>'gap_count'='62') THEN RAISE EXCEPTION 'Missing62 review periods';END IF;
 INSERT INTO v410_results VALUES('sixteen_identical_plus_one_sixty_two_period_review',true);
 IF public.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000002','2026-11-04','2031-12-31')
  IS DISTINCT FROM(SELECT payload FROM v410_other_before) THEN RAISE EXCEPTION 'Owner scope leaked';END IF;
 INSERT INTO v410_results VALUES('owner_isolation',true);
 FOREACH date_case IN ARRAY ARRAY[DATE'2026-11-02',DATE'2026-11-03',DATE'2026-11-04',DATE'2027-08-10',DATE'2027-08-11',DATE'2030-08-01'] LOOP
  j:=public.lts_recurring_future_gap_audit_v6(u,date_case,(date_case+interval'5 years')::date);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target AND x->>'cadence'='monthly') THEN RAISE EXCEPTION 'Review lost at %',date_case;END IF;
 END LOOP;
 INSERT INTO v410_results VALUES('ages_119_120_121_400_401_and_beyond36months',true);
 -- Valid namespace/opening data is required. RPC failures use the existing UI warning.
 FOREACH bad IN ARRAY ARRAY['{bad','[]','{"schema":"lts-recurring-review-scope-v1","entries":[]}'] LOOP
  UPDATE public.legacy_namespace SET valor_bruto=bad,sha256=encode(sha256(convert_to(bad,'UTF8')),'hex') WHERE usuario_id=u;
  failed:=false;
  BEGIN PERFORM public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
   EXCEPTION WHEN invalid_parameter_value THEN failed:=true;END;
  IF NOT failed THEN RAISE EXCEPTION 'Malformed scope silently accepted';END IF;
 END LOOP;
 PERFORM public.v410_fixture_put(s);
 UPDATE public.legacy_namespace SET sha256=repeat('0',64) WHERE usuario_id=u;
 failed:=false;BEGIN PERFORM public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');EXCEPTION WHEN invalid_parameter_value THEN failed:=true;END;
 IF NOT failed THEN RAISE EXCEPTION 'Bad digest silently accepted';END IF;
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries}',(s->'entries')||jsonb_build_array(s#>'{entries,0}')));
 failed:=false;BEGIN PERFORM public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');EXCEPTION WHEN invalid_parameter_value THEN failed:=true;END;
 IF NOT failed THEN RAISE EXCEPTION 'Duplicate identity silently accepted';END IF;
 PERFORM public.v410_fixture_put(jsonb_set(jsonb_set(s,'{entries,0,title}',to_jsonb(E'\t'::text)),'{entries,0,key}','" "'));
 failed:=false;BEGIN PERFORM public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');EXCEPTION WHEN invalid_parameter_value THEN failed:=true;END;
 IF NOT failed THEN RAISE EXCEPTION 'Empty identity silently accepted';END IF;
 INSERT INTO v410_results VALUES('invalid_json_digest_shape_and_duplicate_are_visible_rpc_errors',true);
 SELECT x INTO entry FROM jsonb_array_elements(s->'entries')x WHERE x->>'key'=target;
 -- Keep one entry for bounded lifecycle cases; opening never creates a payment.
 s:=jsonb_build_object('schema','lts-recurring-review-scope-v1','entries',jsonb_build_array(entry));
 FOREACH bad IN ARRAY ARRAY['classification','one_original_occurrence','missing_source','wrong_owner','bad_digest','bad_date'] LOOP
  d:=public.v410_fixture_decision('end','2026-11-04');
  IF bad='classification' THEN d:=jsonb_set(d,'{action}','"classification"');
  ELSIF bad='one_original_occurrence' THEN d:=jsonb_set(d,'{scope}','"one_original_occurrence"');
  ELSIF bad='missing_source' THEN d:=d-'evidence';
  ELSIF bad='wrong_owner' THEN d:=jsonb_set(d,'{evidence,owner_id}','"00000000-0000-4000-8000-000000000002"');
  ELSIF bad='bad_digest' THEN d:=jsonb_set(d,'{evidence,sha256}',to_jsonb(repeat('0',64)));
  ELSE d:=jsonb_set(d,'{effective_on}','"2026-02-31"');END IF;
  PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d)));
  j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Invalid closure hid review: %',bad;END IF;
 END LOOP;
 INSERT INTO v410_results VALUES('invalid_or_occurrence_decisions_leave_review_open',true);
 d:=public.v410_fixture_decision('end','2026-11-05');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d)));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Future closure applied early';END IF;
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-05','2031-12-31');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Effective explicit closure not applied';END IF;
 INSERT INTO v410_results VALUES('explicit_closure_effective_date',true);
 -- Close while the dependency still calls it planning_review: no legacy fallback.
 d:=public.v410_fixture_decision('end','2026-11-03');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d)));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-03','2031-12-31');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(j->'items')x WHERE public.lts_forecast_series_key_v1(x->>'description')=target) THEN RAISE EXCEPTION 'Closed series rediscovered through legacy fallback';END IF;
 INSERT INTO v410_results VALUES('closure_blocks_native_and_legacy_fallback',true);
 d:=public.v410_fixture_decision('replace','2026-11-04')||jsonb_build_object('replacement_key','missing budget','replacement_title','Missing budget','replacement_direction','expense');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d)));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Absent replacement hid original';END IF;
 d:=d||jsonb_build_object('replacement_key','rent','replacement_title','rent');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d)));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Proved known replacement not applied';END IF;
 INSERT INTO v410_results VALUES('replacement_requires_existing_canonical_target',true);
 d:=public.v410_fixture_decision('end','2026-11-03');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(d,public.v410_fixture_decision('open','2026-11-04',2))));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Explicit reopen missing';END IF;
 INSERT INTO v410_results VALUES('explicit_reopen_by_later_revision',true);
 INSERT INTO public.v410_fixture_flow VALUES(u,'2026-11-02','Variable household budget','synthetic','overdue-before-closure','documented_expected',-7,'Itaú');
 PERFORM public.v410_fixture_put(jsonb_set(s,'{entries,0,decisions}',jsonb_build_array(public.v410_fixture_decision('end','2026-11-03'))));
 j:=public.lts_recurring_future_gap_audit_v6(u,'2026-11-04','2031-12-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target AND x->>'awaiting_payment_evidence_count'='1') THEN RAISE EXCEPTION 'Closure hid earlier unconfirmed obligation';END IF;
 DELETE FROM public.v410_fixture_flow WHERE source_ref='overdue-before-closure';
 INSERT INTO v410_results VALUES('earlier_unconfirmed_obligation_defers_review_closure',true);
 -- Exact namespace backup/reimport shape, matching the existing unfiltered export.
 PERFORM public.v410_fixture_put(s);
 SELECT jsonb_agg(to_jsonb(x)ORDER BY id) INTO namespace_backup FROM public.legacy_namespace x WHERE usuario_id=u;
 DELETE FROM public.legacy_namespace WHERE usuario_id=u;
 INSERT INTO public.legacy_namespace SELECT * FROM jsonb_populate_recordset(NULL::public.legacy_namespace,namespace_backup);
 j:=public.lts_recurring_future_gap_audit_v6(u,'2030-08-01','2035-12-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x WHERE x->>'key'=target) THEN RAISE EXCEPTION 'Restored scope missing';END IF;
 INSERT INTO v410_results VALUES('namespace_export_restore_preserves_open_scope',true);
 SELECT md5(jsonb_agg(to_jsonb(x) ORDER BY source_ref)::text) INTO after_sources FROM public.v410_fixture_flow x;
 IF original_sources IS DISTINCT FROM after_sources OR EXISTS(SELECT 1 FROM public.financial_events) THEN RAISE EXCEPTION 'Financial fixture data mutated';END IF;
 IF(SELECT attributes FROM v410_attributes)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'-'prolang' FROM pg_proc p WHERE oid='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) THEN RAISE EXCEPTION 'ACL/config/owner changed';END IF;
 INSERT INTO v410_results VALUES('financial_sources_and_function_privileges_preserved',true);
END $test$;
SELECT jsonb_build_object('pass',true,'engine',version(),'checks',(SELECT jsonb_agg(to_jsonb(x)ORDER BY name) FROM v410_results x)) AS v410_synthetic_proof;
