BEGIN;
SET LOCAL lock_timeout='2s';
DO $due_today_install$
DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;
BEGIN
 p:='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('2bced85c7ee1247102de52cfa0c93ea7','271550df3c19df4f3e04ea04cf37c4b8') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'due-today reader changed concurrently: %',p;
 END IF;
 p:='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('10eded9c70b9b7bdaf55702bcf3e72e0','4caa05ad348ad817df9491b451dc87ea') OR actual_acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'due-today reader changed concurrently: %',p;
 END IF;
 p:='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='2bced85c7ee1247102de52cfa0c93ea7' THEN
  next_sql:=pg_get_functiondef(p);
 next_sql:=replace(next_sql,$before_fragment$  END LOOP;
  outdays:=to_jsonb(out_day_rows);
  f:=jsonb_set(f,ARRAY[part],$before_fragment$,$after_fragment$  END LOOP;
  f:=jsonb_set(f,ARRAY[part],$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$   out_day_rows:=array_append(out_day_rows,d);$before_fragment$,$after_fragment$   outdays:=outdays||jsonb_build_array(d);$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$  outdays:='[]';out_day_rows:=ARRAY[]::jsonb[];$before_fragment$,$after_fragment$  outdays:='[]';$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$d jsonb; dt date; c jsonb; outdays jsonb; out_day_rows jsonb[]; part text; dayev jsonb;$before_fragment$,$after_fragment$d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (x->>'source'='card_invoice' AND coalesce((x->>'unposted_current_projection')::boolean,false) AND (x->>'event_date')::date=current_date)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))$before_fragment$,$after_fragment$  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$ WITH due_invoices AS MATERIALIZED (
  SELECT inv.* FROM public.lts_current_received_card_bills_v263(u) inv
  WHERE inv.due_date=current_date AND inv.amount>0
   AND inv.payment_status='payment_not_reported' AND inv.reported_payment_amount=0
 )
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND (x->>'event_date')::date=current_date
  AND ((x->>'source'='current_event'
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
    AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
    AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric))
   OR (x->>'source'='card_invoice' AND (x->>'signed_amount')::numeric<0
    AND 1=(SELECT count(*) FROM due_invoices inv JOIN public.card_invoices ci
     ON ci.user_id=u AND ci.reference_month=inv.reference_month
      AND public.lts_card_family_v226(ci.card_name,ci.card_name)=inv.family
     WHERE x->>'source_ref'=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
      AND ci.status IN('open','projected') AND inv.invoice_source_id IS NOT NULL
      AND x->>'account'=public.lts_card_invoice_account_v181(ci.card_name)
      AND (x->>'signed_amount')::numeric=-inv.amount
      AND NOT public.lts_card_invoice_settled_v290(u,ci.card_name,ci.reference_month,inv.due_date,inv.amount))))
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;$before_fragment$,$after_fragment$ SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;$after_fragment$);
  IF md5(next_sql)<>'271550df3c19df4f3e04ea04cf37c4b8' THEN RAISE EXCEPTION 'due-today patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'271550df3c19df4f3e04ea04cf37c4b8' THEN RAISE EXCEPTION 'due-today installed definition differs';END IF;
 END IF;
 p:='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 IF md5(pg_get_functiondef(p))='10eded9c70b9b7bdaf55702bcf3e72e0' THEN
  next_sql:=pg_get_functiondef(p);
 next_sql:=replace(next_sql,$before_fragment$  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (x->>'source'='card_invoice' AND coalesce((x->>'unposted_current_projection')::boolean,false) AND (x->>'event_date')::date=current_date)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))$before_fragment$,$after_fragment$  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))$after_fragment$);
 next_sql:=replace(next_sql,$before_fragment$ WITH due_invoices AS MATERIALIZED (
  SELECT inv.* FROM public.lts_current_received_card_bills_v263(u) inv
  WHERE inv.due_date=current_date AND inv.amount>0
   AND inv.payment_status='payment_not_reported' AND inv.reported_payment_amount=0
 )
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND (x->>'event_date')::date=current_date
  AND ((x->>'source'='current_event'
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
    AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
    AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric))
   OR (x->>'source'='card_invoice' AND (x->>'signed_amount')::numeric<0
    AND 1=(SELECT count(*) FROM due_invoices inv JOIN public.card_invoices ci
     ON ci.user_id=u AND ci.reference_month=inv.reference_month
      AND public.lts_card_family_v226(ci.card_name,ci.card_name)=inv.family
     WHERE x->>'source_ref'=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
      AND ci.status IN('open','projected') AND inv.invoice_source_id IS NOT NULL
      AND x->>'account'=public.lts_card_invoice_account_v181(ci.card_name)
      AND (x->>'signed_amount')::numeric=-inv.amount
      AND NOT public.lts_card_invoice_settled_v290(u,ci.card_name,ci.reference_month,inv.due_date,inv.amount))))
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;$before_fragment$,$after_fragment$ SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;$after_fragment$);
  IF md5(next_sql)<>'4caa05ad348ad817df9491b451dc87ea' THEN RAISE EXCEPTION 'due-today patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'4caa05ad348ad817df9491b451dc87ea' THEN RAISE EXCEPTION 'due-today installed definition differs';END IF;
 END IF;
END $due_today_install$;
COMMIT;
