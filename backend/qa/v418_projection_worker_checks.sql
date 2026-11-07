DO $tests$
DECLARE result jsonb; memo jsonb; original jsonb;
BEGIN
 PERFORM qa_v415.reset(true);
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 result:=qa_v415.cycle();
 SELECT payload->'projection_summary_v418' INTO memo FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 PERFORM qa_v415.check('worker prepares missing premises before marking the product ready',
  result->>'published'='true' AND memo#>>'{summary,enabled}'='true'
  AND memo->>'user_id'=qa_v415.owner(1)::text
  AND memo#>>'{guard,request_version}'=(SELECT completed_version::text FROM lts_product_refresh_private_v415.queue WHERE user_id=qa_v415.owner(1)));
 PERFORM qa_v415.check('summary capture preserves canonical payload readiness',
  lts_product_refresh_private_v415.status(qa_v415.owner(1))->>'required'='false');
 SELECT payload INTO original FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1);
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 PERFORM set_config('qa.summary_fail','true',true);
 result:=qa_v415.cycle();
 PERFORM qa_v415.check('failed summary calculation rolls back the entire product publication',
  result->>'published'='false' AND original=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=qa_v415.owner(1)));
 PERFORM set_config('qa.summary_fail','false',true);
 PERFORM qa_v415.check('worker execution attributes owner and ACL preserved',
  (SELECT attributes FROM qa_v415.v418_worker_attributes)=
  (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='lts_product_refresh_private_v415.run_claimed()'::regprocedure));
 PERFORM qa_v415.reset(true);
 PERFORM set_config('qa.capture_in_lower','true',true);
 PERFORM lts_product_refresh_private_v415.enqueue(qa_v415.owner(1),'manual',false);
 result:=qa_v415.cycle();
 PERFORM qa_v415.check('lower-reader capture is reused without a second calculation',
  result->>'published'='true' AND (SELECT count(*)=1 FROM qa_v415.calls WHERE stage='summary_build'));
 PERFORM set_config('qa.capture_in_lower','false',true);
END $tests$;
SELECT count(*) checks,bool_and(pass) pass FROM qa_v415.results;
