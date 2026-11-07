SELECT qa_v412.install_test_adapters();
DO $tests$
DECLARE result jsonb;captured jsonb;
BEGIN
 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":123}'));
 PERFORM set_config('lts.product_refresh_claim','',true);
 PERFORM set_config('lts.projection_summary_v418','',true);
 result:=lts_projection_private_v412.build(qa_v412.owner(),current_date);
 PERFORM qa_v412.assert('ordinary builds add no worker-local summary',
  nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL);
 PERFORM set_config('lts.product_refresh_claim',jsonb_build_object('user_id',qa_v412.owner())::text,true);
 result:=lts_projection_private_v412.build(qa_v412.owner(),current_date);
 captured:=current_setting('lts.projection_summary_v418')::jsonb;
 PERFORM qa_v412.assert('worker captures identical summary from real builder',
  captured->'summary'=result-'events'-'replacement_refs'
  AND captured->>'user_id'=qa_v412.owner()::text
  AND captured->>'as_of'=current_date::text);
 PERFORM set_config('lts.projection_summary_v418','',true);
 result:=lts_projection_private_v412.build(qa_v412.owner(),current_date+1);
 PERFORM qa_v412.assert('custom-date builds cannot overwrite current premises',
  nullif(current_setting('lts.projection_summary_v418',true),'') IS NULL);
 PERFORM qa_v412.assert('builder execution attributes owner and ACL preserved',
  (SELECT attributes FROM qa_v412.v418_builder_attributes)=
  (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='lts_projection_private_v412.build(uuid,date)'::regprocedure));
END $tests$;
SELECT count(*) checks,bool_and(pass) pass FROM qa_v412.results;
