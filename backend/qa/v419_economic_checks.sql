DO $test$ DECLARE o jsonb;a jsonb;x jsonb;e jsonb;BEGIN
 o:='{"current_future":{"days":[{"date":"2030-01-01","fix86_columns":{"saldo_apos_rsu":170,"fgts":500,"posicao_economica_total":99999,"rsus_futuras":200,"cash_awards_futuros":30}}]}}';
 a:='{"current_future":{"days":[{"date":"2030-01-01","fix86_columns":{"fgts":100,"fgts_documental":0,"fgts_aportes_projetados":100}}]}}';
 e:='{"status":"position_after_withdrawal_unavailable","balance_brl":null}';
 x:=lts_fgts_private_v419.merge_flow(o,a,e);
 PERFORM public.v419_assert('economic identity from supplied components',x#>>'{current_future,days,0,fix86_columns,posicao_economica_total}'='500');
 PERFORM public.v419_assert('future awards unchanged',x#>'{current_future,days,0,fix86_columns,rsus_futuras}'=o#>'{current_future,days,0,fix86_columns,rsus_futuras}');
 x:=lts_fgts_private_v419.merge_flow(jsonb_set(o,'{current_future,days,0,fix86_columns,cash_awards_futuros}','null'),a,e);
 PERFORM public.v419_assert('unknown economic component not zero',x#>'{current_future,days,0,fix86_columns,posicao_economica_total}'='null'::jsonb);
END $test$;
