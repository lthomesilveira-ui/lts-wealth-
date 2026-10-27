-- Count each source identity once even when a purchase belongs to a future invoice.
DO $patch$
DECLARE target regprocedure:='public.lts_browser_card_review_queue_v312(date,date,integer,integer,text)'::regprocedure;
 definition text;attributes jsonb;restored text;
 old_part text:=$old$ SELECT date_trunc('month',min(created_at))::date INTO first_month FROM public.lts_open_finance_staging
 WHERE user_id=u AND resource_type='card_transaction';
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(pending)x WHERE (x->>'reference_month')::date BETWEEN first_month AND date_trunc('month',current_date)::date) THEN$old$;
 new_part text:=$new$ IF total>0 THEN$new$;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,new_part)>0 THEN
  restored:=replace(definition,new_part,old_part);
  IF md5(restored)<>'62b1929cf0cae01221d8b110791c611b' THEN RAISE EXCEPTION 'V362_REPLAY_SOURCE_CHANGED';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'62b1929cf0cae01221d8b110791c611b' OR (length(definition)-length(replace(definition,old_part,'')))/length(old_part)<>1
 THEN RAISE EXCEPTION 'V362_QUEUE_SOURCE_CHANGED';END IF;
 EXECUTE replace(definition,old_part,new_part);
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)
 THEN RAISE EXCEPTION 'V362_QUEUE_ATTRIBUTES_CHANGED';END IF;
END $patch$;
