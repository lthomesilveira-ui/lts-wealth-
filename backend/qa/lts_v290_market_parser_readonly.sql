-- Public synthetic source fixtures; this script never updates prices or financial data.
WITH fixtures AS(
 SELECT '{"chart":{"result":[{"meta":{"symbol":"OGN","currency":"USD","instrumentType":"EQUITY","exchangeTimezoneName":"America/New_York","exchangeName":"NYQ","regularMarketPrice":13.75,"regularMarketTime":1792440002,"currentTradingPeriod":{"regular":{"start":1792416600,"end":1792440000}}}}],"error":null}}'::jsonb stock,
 '{"value":[{"cotacaoCompra":5.0558,"cotacaoVenda":5.0564,"dataHoraCotacao":"2026-10-19 13:05:47.20983"}]}'::jsonb fx,
 '2026-10-19T22:00:00Z'::timestamptz observed
), cases AS(
 SELECT v.name,v.expected,public.lts_market_parse_v290(v.symbol,v.body,observed) actual
 FROM fixtures CROSS JOIN LATERAL(VALUES
 ('stock_valid',true,'OGN',stock),
 ('fx_valid',true,'USD/BRL',fx),
 ('stock_null',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketPrice}','null')),
 ('stock_zero',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketPrice}','0')),
 ('stock_negative',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketPrice}','-1')),
 ('stock_unbounded',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketPrice}','10000')),
 ('wrong_symbol',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,symbol}','"OTHER"')),
 ('missing_symbol',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,symbol}','null')),
 ('wrong_currency',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,currency}','"BRL"')),
 ('missing_currency',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,currency}','null')),
 ('wrong_instrument',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,instrumentType}','"INDEX"')),
 ('wrong_exchange',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,exchangeName}','"OTHER"')),
 ('stock_no_timestamp',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketTime}','null')),
 ('stock_future',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketTime}',to_jsonb(extract(epoch FROM observed+interval '1 day')))),
 ('stock_stale_input',false,'OGN',jsonb_set(stock,'{chart,result,0,meta,regularMarketTime}',to_jsonb(extract(epoch FROM observed-interval '46 days')))),
 ('fx_null',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoVenda}','null')),
 ('fx_zero',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoVenda}','0')),
 ('fx_negative',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoVenda}','-1')),
 ('fx_unbounded',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoVenda}','100')),
 ('fx_crossed_spread',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoCompra}','6')),
 ('fx_missing_buy',false,'USD/BRL',jsonb_set(fx,'{value,0,cotacaoCompra}','null')),
 ('fx_missing_date',false,'USD/BRL',jsonb_set(fx,'{value,0,dataHoraCotacao}','null')),
 ('fx_future',false,'USD/BRL',jsonb_set(fx,'{value,0,dataHoraCotacao}','"2030-10-20 13:00:00"')),
 ('unknown_source',false,'UNKNOWN',stock),
 ('empty_stock',false,'OGN','{}'::jsonb),
 ('empty_fx',false,'USD/BRL','{}'::jsonb)
 )v(name,expected,symbol,body))
SELECT jsonb_build_object('cases',count(*),'passed',count(*)=26 AND bool_and((actual IS NOT NULL)=expected),
 'failed',coalesce(jsonb_agg(name)FILTER(WHERE (actual IS NOT NULL) IS DISTINCT FROM expected),'[]')) receipt FROM cases;
