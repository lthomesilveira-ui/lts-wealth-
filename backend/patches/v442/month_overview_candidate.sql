CREATE OR REPLACE FUNCTION public.lts_browser_month_overview_v393(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();revision text;epoch bigint;f jsonb;e jsonb;j jsonb;undated jsonb;cycles jsonb;projected jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to-p_from>12000
 OR p_to>make_date(extract(year from current_date)::int+5,12,31) THEN RAISE EXCEPTION 'Invalid monthly range';END IF;
 revision:=public.lts_card_read_start_v269(u);
 SELECT x.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 x WHERE singleton;
 f:=public.lts_browser_flow_v242(p_from,p_to);
 cycles:=public.lts_prepared_card_cycles_v307(u);
 cycles:=lts_month_private_v393.projection_contract_v442(cycles,p_from,p_to);
 SELECT coalesce(jsonb_agg(jsonb_build_object('family',ca->>'family','card_name',ca->>'name','month',cy->>'month',
  'amount',cy->'amount','due_date',null) ORDER BY ca->>'family',cy->>'month'),'[]') INTO undated
 FROM jsonb_array_elements(cycles->'cards') ca
 CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
 WHERE nullif(cy->>'due_date','') IS NULL AND (nullif(cy->>'amount','') IS NULL OR (cy->>'amount')::numeric<>0)
 AND (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date
 AND coalesce(cy->>'payment_status','') NOT IN('paid','settled');
 projected:=lts_month_private_v393.projected_items(cycles,p_from,p_to);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(cycles->'cards')ca CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles')cy
  WHERE (cy->>'month')::date BETWEEN date_trunc('month',p_from)::date AND date_trunc('month',p_to)::date
  AND abs(coalesce((cy->>'projected_amount')::numeric,0)-coalesce((SELECT sum((i->>'amount')::numeric)
   FROM jsonb_array_elements(projected)i WHERE i->>'family'=ca->>'family' AND i->>'competence_month'=cy->>'month'),0))>.005)
 THEN RAISE EXCEPTION 'Projected card rows do not reconcile to canonical cycles';END IF;
 f:=f||jsonb_build_object('month_undated_card_invoices_v393',undated,'month_projected_card_expenses_v393',projected);
 SELECT coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('institution_code',s.institution_code) ORDER BY r.event_date,r.row_key),'[]') INTO e
 FROM public.lts_v229_expense_rows(u,greatest(date '2013-10-10',date_trunc('month',p_from)::date),
  (date_trunc('month',p_to)+interval '1 month'-interval '1 day')::date)r
 LEFT JOIN public.lts_open_finance_staging s ON r.source_table='lts_open_finance_staging' AND s.user_id=u AND s.id::text=r.source_ref;
 j:=lts_month_private_v393.build(f,e,p_from,p_to,current_date);
 IF epoch IS DISTINCT FROM(SELECT x.epoch FROM public.lts_read_cache_epoch_v242 x WHERE singleton)
 THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Sources changed during monthly read';END IF;
 RETURN public.lts_card_read_finish_v269(u,revision,j);
END $function$
