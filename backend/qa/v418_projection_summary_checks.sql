DO $tests$
DECLARE original jsonb;result jsonb;item text;failed boolean;
BEGIN
 SELECT payload INTO original FROM public.lts_product_read_cache;
 result:=lts_projection_private_v412.read_policy();
 INSERT INTO qa_v418.results VALUES('prepared response preserves all financial fields without full build',
  result-'read_at'=original#>'{projection_summary_v418,summary}');
 FOREACH item IN ARRAY ARRAY['source_epoch','request_version','card_source_key','policy_sha256','reference_sha256'] LOOP
  UPDATE public.lts_product_read_cache SET payload=jsonb_set(original,ARRAY['projection_summary_v418','guard',item],'"changed"');
  failed:=false;
  BEGIN PERFORM lts_projection_private_v412.read_policy(); EXCEPTION WHEN SQLSTATE '55000' THEN failed:=true;END;
  INSERT INTO qa_v418.results VALUES('reject stale guard '||item,failed);
 END LOOP;
 UPDATE public.lts_product_read_cache SET payload=jsonb_set(original,ARRAY['projection_summary_v418','as_of'],to_jsonb((current_date-1)::text));
 failed:=false;
 BEGIN PERFORM lts_projection_private_v412.read_policy(); EXCEPTION WHEN SQLSTATE '55000' THEN failed:=true;END;
 INSERT INTO qa_v418.results VALUES('prior-day summary is never current',failed);
 UPDATE public.lts_product_read_cache SET payload=original;
 UPDATE lts_product_refresh_private_v415.queue SET state='running';
 failed:=false;
 BEGIN PERFORM lts_projection_private_v412.read_policy(); EXCEPTION WHEN SQLSTATE '55000' THEN failed:=true;END;
 INSERT INTO qa_v418.results VALUES('in-progress refresh cannot certify current premises',failed);
 UPDATE lts_product_refresh_private_v415.queue SET state='ready';
 PERFORM set_config('qa.identity','22222222-2222-4222-8222-222222222222',true);
 failed:=false;
 BEGIN PERFORM lts_projection_private_v412.read_policy(); EXCEPTION WHEN SQLSTATE '55000' THEN failed:=true;END;
 INSERT INTO qa_v418.results VALUES('another synthetic identity cannot receive cached owner data',failed);
 PERFORM set_config('qa.identity','denied',true);
 failed:=false;
 BEGIN PERFORM lts_projection_private_v412.read_policy(); EXCEPTION WHEN OTHERS THEN failed:=SQLERRM='denied';END;
 INSERT INTO qa_v418.results VALUES('existing authorization gate runs before cache reads',failed);
 PERFORM set_config('qa.identity','',true);
 PERFORM set_config('qa.disabled','true',true);
 result:=lts_projection_private_v412.read_policy();
 INSERT INTO qa_v418.results VALUES('disabled policy keeps existing contract',result->>'enabled'='false');
END $tests$;
SELECT count(*) checks,bool_and(pass) pass FROM qa_v418.results;
