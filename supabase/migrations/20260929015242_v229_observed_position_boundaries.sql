-- An unexplained change in a provider position is not a transaction. Do not
-- back-propagate that change to earlier days or manufacture an income entry.
DO $migration$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_flow_v229(date,date)'::regprocedure);
 definition:=replace(definition,'asset_net numeric;','asset_net numeric; gap_dates jsonb:=''{}''; first_gap date; day_gap numeric;');
 definition:=replace(definition,'gaps:=gaps||jsonb_build_object(b,round(bal-(a->>''balance'')::numeric-net,2));',
 $patch$gaps:=gaps||jsonb_build_object(b,round(bal-(a->>'balance')::numeric-net,2));
  IF abs((gaps->>b)::numeric)>.005 THEN
   SELECT min((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date INTO first_gap
   FROM public.lts_open_finance_observation o JOIN public.lts_open_finance_connection cn ON cn.id=o.connection_id
   WHERE o.user_id=u AND o.resource_type='balance' AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND CASE cn.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END=b
   AND ((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date>(a->>'date')::date
   AND abs((o.normalized_payload->>'amount')::numeric-(a->>'balance')::numeric-
    coalesce((SELECT sum((x->>'signed_amount')::numeric) FROM jsonb_array_elements(recent) x WHERE x->>'account'=b
     AND (x->>'event_date')::date>(a->>'date')::date AND (x->>'event_date')::date<=((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date AND x->>'source'<>'economic_withholding'),0))>.005;
   gap_dates:=gap_dates||jsonb_build_object(b,first_gap);
  END IF;$patch$);
 definition:=replace(definition,'d:=jsonb_set(d,ARRAY[b],',
 $patch$first_gap:=(gap_dates->>b)::date;
     IF first_gap IS NOT NULL AND dt<first_gap THEN
      SELECT (a->>'balance')::numeric+coalesce(sum((x->>'signed_amount')::numeric),0) INTO bal FROM jsonb_array_elements(recent) x
       WHERE x->>'account'=b AND (x->>'event_date')::date>(a->>'date')::date AND (x->>'event_date')::date<=dt AND x->>'source'<>'economic_withholding';
     END IF;
     d:=jsonb_set(d,ARRAY[b],$patch$);
 definition:=replace(definition,'''reconciliation_gap'',(gaps->>b)::numeric',
 '''movements_complete'',dt IS DISTINCT FROM first_gap,''opening_balance'',bal-net-CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,''position_gap'',CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,''reconciliation_gap'',(gaps->>b)::numeric');
 definition:=replace(definition,'outdays:=outdays||jsonb_build_array(d);',
 $patch$day_gap:=coalesce((d#>>'{Itaú,position_gap}')::numeric,0)+coalesce((d#>>'{Bradesco,position_gap}')::numeric,0)+coalesce((d#>>'{C6,position_gap}')::numeric,0);
   IF abs(day_gap)>.005 THEN
    d:=d||jsonb_build_object('movements_complete',false,'position_gap',day_gap,'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
     'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric-day_gap,
     'saldo_anterior_operacional',(d#>>'{fix86_columns,saldo_anterior_operacional}')::numeric-day_gap,'entradas',null,'saidas',null));
   END IF;
   outdays:=outdays||jsonb_build_array(d);$patch$);
 definition:=replace(definition,'''documentary_gaps'',gaps','''documentary_gaps'',gaps,''position_gap_dates'',gap_dates');
 EXECUTE definition;
END $migration$;
