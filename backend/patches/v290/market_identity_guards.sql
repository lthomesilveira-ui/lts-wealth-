CREATE OR REPLACE FUNCTION public.lts_market_parse_v290(p_symbol text,p_body jsonb,p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE m jsonb; v numeric; t timestamptz; session_start timestamptz; session_end timestamptz;
BEGIN
 IF p_symbol='OGN' THEN
  m:=p_body#>'{chart,result,0,meta}';
  IF p_body#>>'{chart,error}' IS NOT NULL OR coalesce(m->>'symbol','')<>'OGN' OR coalesce(m->>'currency','')<>'USD'
  OR coalesce(m->>'instrumentType','')<>'EQUITY' OR coalesce(m->>'exchangeTimezoneName','')<>'America/New_York'
  OR coalesce(m->>'exchangeName','') NOT IN('NYQ','NYSE') THEN RETURN NULL; END IF;
  v:=(m->>'regularMarketPrice')::numeric;
  t:=to_timestamp((m->>'regularMarketTime')::double precision);
  session_start:=to_timestamp((m#>>'{currentTradingPeriod,regular,start}')::double precision);
  session_end:=to_timestamp((m#>>'{currentTradingPeriod,regular,end}')::double precision);
  IF v IS NULL OR v<=0 OR v>=10000 OR t IS NULL OR t>p_now+interval '1 minute' OR t<p_now-interval '45 days'
  OR t<'2000-01-01'::timestamptz THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('value',v,'quoted_at',t,'currency','USD','source_name','Yahoo Finance · NYSE',
   'source_url','https://finance.yahoo.com/quote/OGN/',
   'market_state',CASE WHEN p_now BETWEEN session_start AND session_end THEN 'trading' ELSE 'closed' END,
   'details',jsonb_build_object('symbol','OGN','session_start',session_start,'session_end',session_end,
    'timing','latest_regular_trade_may_be_delayed','exchange','NYSE'));
 ELSIF p_symbol='USD/BRL' THEN
  m:=p_body#>'{value,0}'; v:=(m->>'cotacaoVenda')::numeric;
  IF m->>'dataHoraCotacao' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?$'
  THEN RETURN NULL; END IF;
  t:=(m->>'dataHoraCotacao')::timestamp AT TIME ZONE 'America/Sao_Paulo';
  IF v IS NULL OR v<=0 OR v>=100 OR (m->>'cotacaoCompra') IS NULL OR (m->>'cotacaoCompra')::numeric<=0
  OR (m->>'cotacaoCompra')::numeric>v OR t IS NULL OR t>p_now+interval '1 minute'
  OR t<p_now-interval '45 days' THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('value',v,'quoted_at',t,'currency','BRL','source_name','Banco Central · PTAX venda',
   'source_url','https://ptax.bcb.gov.br/ptax_internet/consultarUltimaCotacaoDolar.do',
   'market_state','daily_reference','details',jsonb_build_object('reference','PTAX','side','sell','timing','daily_reference_not_intraday'));
 END IF;
 RETURN NULL;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END $f$;
