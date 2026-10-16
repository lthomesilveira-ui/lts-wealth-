CREATE OR REPLACE FUNCTION public.lts_browser_cash_today_v242()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb:=public.lts_browser_cash_today_v178(); a jsonb:=public.lts_liquidity_adjustments_v242(u,current_date);
 r numeric:=(j->>'brokerage_available')::numeric-(a->>'brokerage_settled_withdrawals')::numeric; fg numeric:=(a->>'fgts_documented')::numeric; c jsonb:=j#>'{day,fix86_columns}'; base numeric:=(j->>'cash')::numeric+(j->>'d0')::numeric;
BEGIN
 IF r<0 THEN RAISE EXCEPTION 'brokerage withdrawal exceeds last known resource'; END IF;
 j:=jsonb_set(j,'{day,fix86_columns}',c||jsonb_build_object('rsus_vested',r,'morgan_available_total_brl',r,'saldo_apos_rsu',base+r,'fgts',fg,'saldo_apos_fgts',base+r+fg,'disponivel_total',base+r,'posicao_curto_prazo',base+r));
 RETURN j||jsonb_build_object('brokerage_available',r,'available_total',base+r,'fgts',fg,'reader_revision','v242-settled-resource-transfers');
END $function$

