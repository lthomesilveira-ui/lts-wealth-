-- The Flow metadata used an old candidate list without the canonical documentary links.
-- Reuse the same evidence-based pending obligations as the review queue.
CREATE TEMP TABLE flow_pending_baseline_v291(user_id uuid PRIMARY KEY,financial_parts jsonb) ON COMMIT DROP;
DO $baseline$ DECLARE u uuid; j jsonb; BEGIN
 FOR u IN SELECT user_id FROM public.lts_product_read_cache LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
  j:=public.lts_browser_flow_v242(current_date-5,date '2027-12-31');
  IF jsonb_typeof(j#>'{flow,current_future,days}')<>'array' THEN RAISE EXCEPTION 'Flow baseline unavailable'; END IF;
  INSERT INTO flow_pending_baseline_v291 VALUES(u,jsonb_build_object(
   'historical_days',j#>'{flow,historical,days}','historical_events',j#>'{flow,historical,events}',
   'current_days',j#>'{flow,current_future,days}','current_events',j#>'{flow,current_future,events}'));
 END LOOP;
END $baseline$;
DO $patch$ DECLARE item record; d text; a integer; b integer; old text; BEGIN
 FOR item IN SELECT * FROM(VALUES
 ('public.lts_browser_flow_pre_v238(date,date)','9140e12b87ab6052c5116138e294fda5'),
 ('public.lts_flow_cache_pre_v240(uuid,date,date)','c0f1d581b9c28cbf9bfe4cfbf0b26773'))v(sig,expected_md5) LOOP
  SELECT pg_get_functiondef(item.sig::regprocedure) INTO d;
  IF md5(d)<>item.expected_md5 THEN RAISE EXCEPTION 'Flow pending source changed: %',item.sig; END IF;
  a:=strpos(d,$a$ SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions FROM jsonb_array_elements(recent) x$a$);
  IF a=0 THEN RAISE EXCEPTION 'Flow pending anchor missing'; END IF;
  b:=strpos(substr(d,a),';');IF b=0 THEN RAISE EXCEPTION 'Flow pending boundary missing'; END IF;
  old:=substr(d,a,b);
  d:=replace(d,old,' pending_predictions:=public.lts_pending_projections_v233(u);');
  EXECUTE d;
 END LOOP;
END $patch$;
-- Cold and warm responses must agree immediately; do not falsify refresh timestamps.
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
DO $parity$ DECLARE r record; j jsonb; parts jsonb; BEGIN
 FOR r IN SELECT * FROM flow_pending_baseline_v291 LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=r.user_id),true);
  j:=public.lts_browser_flow_v242(current_date-5,date '2027-12-31');
  parts:=jsonb_build_object('historical_days',j#>'{flow,historical,days}','historical_events',j#>'{flow,historical,events}',
   'current_days',j#>'{flow,current_future,days}','current_events',j#>'{flow,current_future,events}');
  IF parts IS DISTINCT FROM r.financial_parts THEN RAISE EXCEPTION 'Financial Flow rows changed'; END IF;
  IF j#>'{flow,observed_bank_movements,pending_projections}' IS DISTINCT FROM public.lts_pending_projections_v233(r.user_id)
  THEN RAISE EXCEPTION 'Flow pending obligations disagree with canonical evidence'; END IF;
 END LOOP;
END $parity$;
