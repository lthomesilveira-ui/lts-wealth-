-- Synthetic regression only. The stub net.http_get never performs network I/O.
SELECT public.qa_assert_v405('migration_preserves_every_original_field',
 NOT EXISTS(SELECT 1 FROM public.qa_history_v405 old LEFT JOIN public.lts_market_request_v290 now
 ON now.request_id=old.request_id WHERE now.request_id IS NULL OR to_jsonb(old) IS DISTINCT FROM to_jsonb(now)-'request_generation'));
SELECT public.qa_assert_v405('unknown_history_not_assigned_a_fictitious_server_generation',
 (SELECT count(*)=4 FROM public.lts_market_request_v290 WHERE request_generation='-infinity'));
SELECT public.qa_assert_v405('current_predecessor_request_has_actual_generation',
 (SELECT request_generation=pg_postmaster_start_time() FROM public.lts_market_request_v290 WHERE request_id=50));
SELECT public.qa_assert_v405('generation_scoped_primary_key',
 (SELECT pg_get_constraintdef(oid)='PRIMARY KEY (request_generation, request_id)' FROM pg_constraint
  WHERE conrelid='public.lts_market_request_v290'::regclass AND contype='p'));
SELECT public.qa_assert_v405('private_request_table_and_workers_remain_private',
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.lts_market_request_v290'::regclass)
 AND NOT has_table_privilege('anon','public.lts_market_request_v290','SELECT')
 AND NOT has_table_privilege('authenticated','public.lts_market_request_v290','SELECT')
 AND NOT has_function_privilege('anon','public.lts_market_request_quotes_v290()','EXECUTE')
 AND NOT has_function_privilege('authenticated','public.lts_market_collect_quotes_v290()','EXECUTE')
 AND has_function_privilege('service_role','public.lts_market_request_quotes_v290()','EXECUTE'));

-- Reproduce the transport's post-crash sequence reset, only in this local fixture.
SELECT setval('net.http_request_queue_id_seq',1,false);
INSERT INTO public.qa_call_v405 VALUES('call_04',public.lts_market_request_quotes_v290());
SELECT public.qa_assert_v405('both_sources_enqueue_after_id_reuse',
 jsonb_array_length((SELECT result FROM public.qa_call_v405 WHERE name='call_04'))=2);
SELECT public.qa_assert_v405('recycled_ids_keep_old_and_new_mappings',
 (SELECT count(*)=4 FROM public.lts_market_request_v290 WHERE request_id IN(1,2))
 AND (SELECT symbol='OGN' FROM public.lts_market_request_v290 WHERE request_id=1 AND request_generation=pg_postmaster_start_time())
 AND (SELECT symbol='USD/BRL' FROM public.lts_market_request_v290 WHERE request_id=2 AND request_generation=pg_postmaster_start_time()));
INSERT INTO public.qa_call_v405 VALUES('call_05',public.lts_market_request_quotes_v290());
SELECT public.qa_assert_v405('pending_same_generation_does_not_enqueue_twice',
 (SELECT result FROM public.qa_call_v405 WHERE name='call_05')='[]'::jsonb
 AND (SELECT count(*)=2 FROM net.http_request_queue));
INSERT INTO public.qa_call_v405 VALUES('call_06',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('interrupted_attempt_never_consumes_recycled_response',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_06')->>'accepted')::int=0
 AND (SELECT error_code='request_interrupted_by_restart' AND processed_at IS NOT NULL
      FROM public.lts_market_request_v290 WHERE request_id=1 AND request_generation='-infinity'));
SELECT public.qa_assert_v405('older_interruption_does_not_hide_current_attempt',
 (SELECT count(*)=2 FROM public.lts_market_refresh_v290 WHERE status='consulting')
 AND (SELECT count(*)=2 FROM public.lts_market_request_v290 WHERE processed_at IS NULL));

INSERT INTO net._http_response(id,status_code,content,created)
 SELECT request_id,200,public.qa_body_v405(symbol,999)::text,requested_at-interval '1 second'
 FROM public.lts_market_request_v290 WHERE request_id=1 AND request_generation=pg_postmaster_start_time();
INSERT INTO public.qa_call_v405 VALUES('call_07',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('response_before_enqueue_is_ignored',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_07')->>'accepted')::int=0
 AND (SELECT count(*)=2 FROM public.lts_market_request_v290 WHERE processed_at IS NULL)
 AND (SELECT epoch=41 FROM public.lts_read_cache_epoch_v242));
INSERT INTO net._http_response(id,status_code,content,created)
 SELECT request_id,200,public.qa_body_v405(symbol,CASE symbol WHEN 'OGN' THEN 42 ELSE 5.75 END)::text,clock_timestamp()
 FROM public.lts_market_request_v290 WHERE processed_at IS NULL AND request_generation=pg_postmaster_start_time();
INSERT INTO public.qa_call_v405 VALUES('call_08',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('valid_current_generation_responses_accepted_once',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_08')->>'accepted')::int=2);
SELECT public.qa_assert_v405('correct_symbol_quotes_and_revision',
 (SELECT q.value=42 FROM public.lts_market_head_v290 h JOIN public.lts_market_quote_v290 q ON q.id=h.quote_id WHERE h.symbol='OGN')
 AND (SELECT q.value=5.75 FROM public.lts_market_head_v290 h JOIN public.lts_market_quote_v290 q ON q.id=h.quote_id WHERE h.symbol='USD/BRL')
 AND (SELECT epoch=42 FROM public.lts_read_cache_epoch_v242));
SELECT public.qa_assert_v405('processed_historical_requests_unchanged',
 NOT EXISTS(SELECT 1 FROM public.qa_history_v405 old JOIN public.lts_market_request_v290 now
 ON now.request_id=old.request_id AND now.request_generation=CASE WHEN old.requested_at>=pg_postmaster_start_time()
 THEN pg_postmaster_start_time() ELSE '-infinity'::timestamptz END
 WHERE old.processed_at IS NOT NULL AND to_jsonb(old) IS DISTINCT FROM to_jsonb(now)-'request_generation'));
SELECT public.qa_assert_v405('original_quotes_remain_immutable',
 NOT EXISTS(SELECT 1 FROM public.qa_quotes_before_v405 old LEFT JOIN public.lts_market_quote_v290 now
 ON now.id=old.id WHERE to_jsonb(old) IS DISTINCT FROM to_jsonb(now)));
INSERT INTO public.qa_call_v405 VALUES('call_09',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('repeated_collection_is_idempotent',
 (SELECT result FROM public.qa_call_v405 WHERE name='call_09')='{"accepted":0,"valuation_revision_changed":false}'::jsonb
 AND (SELECT count(*)=4 FROM public.lts_market_quote_v290)
 AND (SELECT epoch=42 FROM public.lts_read_cache_epoch_v242));

SELECT public.lts_market_request_quotes_v290();
INSERT INTO net._http_response(id,status_code,error_msg,timed_out,created)
 SELECT request_id,CASE symbol WHEN 'OGN' THEN 503 ELSE NULL END,
 CASE symbol WHEN 'USD/BRL' THEN 'synthetic transport failure' ELSE NULL END,
 symbol='USD/BRL',clock_timestamp() FROM public.lts_market_request_v290 WHERE processed_at IS NULL;
INSERT INTO public.qa_call_v405 VALUES('call_10',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('http_and_transport_errors_do_not_change_quotes',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_10')->>'accepted')::int=0
 AND (SELECT count(*)=4 FROM public.lts_market_quote_v290)
 AND (SELECT epoch=42 FROM public.lts_read_cache_epoch_v242));
SELECT public.qa_assert_v405('error_semantics_preserved',
 (SELECT error_code='http_503' FROM public.lts_market_refresh_v290 WHERE symbol='OGN')
 AND (SELECT error_code='source_unavailable' FROM public.lts_market_refresh_v290 WHERE symbol='USD/BRL'));

SELECT public.lts_market_request_quotes_v290();
INSERT INTO net._http_response(id,status_code,content,created)
 SELECT request_id,200,CASE symbol WHEN 'OGN' THEN public.qa_body_v405('USD/BRL',5.8)::text ELSE 'invalid json' END,
 clock_timestamp() FROM public.lts_market_request_v290 WHERE processed_at IS NULL;
INSERT INTO public.qa_call_v405 VALUES('call_11',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('wrong_source_or_malformed_body_cannot_replace_quotes',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_11')->>'accepted')::int=0
 AND (SELECT count(*)=2 FROM public.lts_market_refresh_v290 WHERE error_code='invalid_or_undated_quote')
 AND (SELECT count(*)=4 FROM public.lts_market_quote_v290));

-- Even a close timestamp cannot make a different server generation the same request.
INSERT INTO public.lts_market_request_v290(request_generation,request_id,symbol,requested_at)
 VALUES(pg_postmaster_start_time()-interval '1 hour',7,'USD/BRL',clock_timestamp());
INSERT INTO public.qa_call_v405 VALUES('call_12',public.lts_market_request_quotes_v290());
SELECT public.qa_assert_v405('different_generation_pending_does_not_suppress_fresh_requests',
 jsonb_array_length((SELECT result FROM public.qa_call_v405 WHERE name='call_12'))=2);
INSERT INTO net._http_response(id,status_code,content,created)
 SELECT request_id,200,public.qa_body_v405(symbol,CASE symbol WHEN 'OGN' THEN 42 ELSE 5.75 END)::text,clock_timestamp()
 FROM public.lts_market_request_v290 WHERE processed_at IS NULL AND request_generation=pg_postmaster_start_time();
INSERT INTO public.qa_call_v405 VALUES('call_13',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('generation_binding_survives_nearby_timestamps',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_13')->>'accepted')::int=2
 AND (SELECT error_code='request_interrupted_by_restart' FROM public.lts_market_request_v290
      WHERE request_generation=pg_postmaster_start_time()-interval '1 hour' AND request_id=7)
 AND (SELECT count(*)=4 FROM public.lts_market_quote_v290)
 AND (SELECT epoch=42 FROM public.lts_read_cache_epoch_v242));

INSERT INTO public.lts_market_request_v290(request_id,symbol,requested_at)
 VALUES(899,'OGN',clock_timestamp()-interval '4 minutes');
INSERT INTO net._http_response(id,status_code,created)VALUES(899,503,clock_timestamp());
SELECT public.lts_market_request_quotes_v290();
INSERT INTO public.qa_call_v405 VALUES('call_14',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('late_failure_cannot_override_newer_consultation',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_14')->>'accepted')::int=0
 AND (SELECT count(*)=2 FROM public.lts_market_refresh_v290 WHERE status='consulting'));

UPDATE public.lts_market_request_v290 SET requested_at=clock_timestamp()-interval '4 minutes'
 WHERE processed_at IS NULL AND request_generation=pg_postmaster_start_time();
INSERT INTO public.qa_call_v405 VALUES('call_15',public.lts_market_collect_quotes_v290());
SELECT public.qa_assert_v405('missing_response_expires_without_new_quote',
 ((SELECT result FROM public.qa_call_v405 WHERE name='call_15')->>'accepted')::int=0
 AND (SELECT count(*)=0 FROM public.lts_market_request_v290 WHERE processed_at IS NULL)
 AND (SELECT count(*)=4 FROM public.lts_market_quote_v290)
 AND (SELECT epoch=42 FROM public.lts_read_cache_epoch_v242));
SELECT count(*) AS checks_passed FROM public.qa_result_v405;
