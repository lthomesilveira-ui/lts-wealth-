CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.expense_review_pending_v450(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE source_guard jsonb; final_guard jsonb; fingerprint text; stored jsonb; result jsonb; old_lock text;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid review range';END IF;
 -- The existing worker warms this snapshot after marking its own request ready.
 -- Do not compete with that worker or certify an old/empty review meanwhile.
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue q
  WHERE q.user_id=p_user_id AND q.state IN('pending','running')
  AND q.request_version>q.completed_version) THEN
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Expense review is waiting for the existing product refresh';
 END IF;
 source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);
 IF source_guard IS NULL THEN
  RETURN QUERY SELECT r.* FROM public.lts_v229_review_rows(p_user_id,p_from,p_to) r WHERE r.identity_status='pending';RETURN;
 END IF;
 fingerprint:='expense-review-v450:'||md5(source_guard::text);
 SELECT c.payload INTO stored FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='expense_review_pending_v450' AND c.as_of=current_date
 AND c.from_date=p_from AND c.to_date=p_to AND c.source_fingerprint=fingerprint;
 IF FOUND AND stored->'guard'=source_guard AND jsonb_typeof(stored->'rows')='array'
 AND stored->>'digest'=md5((stored->'rows')::text) THEN result:=stored->'rows';
 ELSE
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO result
   FROM public.lts_v229_review_rows(p_user_id,p_from,p_to) r WHERE r.identity_status='pending';
  final_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);
  IF final_guard IS DISTINCT FROM source_guard THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
   old_lock:=current_setting('lock_timeout');
   BEGIN
    IF old_lock::interval=interval '0' OR old_lock::interval>interval '100 milliseconds' THEN PERFORM set_config('lock_timeout','100ms',true);END IF;
    INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
    VALUES(p_user_id,'expense_review_pending_v450',current_date,p_from,p_to,
     jsonb_build_object('guard',source_guard,'rows',result,'digest',md5(result::text)),clock_timestamp(),fingerprint)
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
    PERFORM set_config('lock_timeout',old_lock,true);
   EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN NULL;END;
  END IF;
 END IF;
 -- Recheck even cache hits; no crossing to a changed owner/day/source revision.
 IF lts_product_refresh_private_v415.review_guard_v450(p_user_id) IS DISTINCT FROM source_guard THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';END IF;
 RETURN QUERY SELECT r.* FROM jsonb_to_recordset(result) AS r(row_key text, event_date date, transaction_date date, competence_month date, amount numeric, category text, beneficiary text, description text, account_source text, source_table text, source_ref text, coverage_mode text, raw_category text, raw_reference text, purchase_date date, identity_status text, management_group text, management_subgroup text, property_code text, property_component text);
END $function$;
