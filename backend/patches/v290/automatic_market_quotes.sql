-- V290: public market references, immutable observations, separate consultation times.
CREATE TABLE public.lts_market_quote_v290(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,symbol text NOT NULL CHECK(symbol IN('OGN','USD/BRL')),
 value numeric NOT NULL CHECK(value>0),currency text NOT NULL,quoted_at timestamptz NOT NULL,
 source_name text NOT NULL,source_url text NOT NULL,market_state text NOT NULL,details jsonb NOT NULL DEFAULT '{}',
 received_at timestamptz NOT NULL, UNIQUE(symbol,source_name,quoted_at,value)
);
CREATE TABLE public.lts_market_head_v290(symbol text PRIMARY KEY,quote_id bigint NOT NULL REFERENCES public.lts_market_quote_v290(id));
CREATE TABLE public.lts_market_request_v290(
 request_id bigint PRIMARY KEY,symbol text NOT NULL,requested_at timestamptz NOT NULL DEFAULT now(),
 processed_at timestamptz,error_code text
);
CREATE INDEX market_pending_v290 ON public.lts_market_request_v290(requested_at) WHERE processed_at IS NULL;
CREATE TABLE public.lts_market_refresh_v290(
 symbol text PRIMARY KEY,last_attempt_at timestamptz,last_response_at timestamptz,status text NOT NULL,error_code text
);
ALTER TABLE public.lts_market_quote_v290 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_market_head_v290 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_market_request_v290 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_market_refresh_v290 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_market_quote_v290,public.lts_market_head_v290,public.lts_market_request_v290,public.lts_market_refresh_v290 FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.lts_market_quote_v290,public.lts_market_head_v290,public.lts_market_request_v290,public.lts_market_refresh_v290 TO service_role;
GRANT USAGE ON SEQUENCE public.lts_market_quote_v290_id_seq TO service_role;

CREATE OR REPLACE FUNCTION public.lts_market_parse_v290(p_symbol text,p_body jsonb,p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE m jsonb; v numeric; t timestamptz; session_start timestamptz; session_end timestamptz;
BEGIN
 IF p_symbol='OGN' THEN
  m:=p_body#>'{chart,result,0,meta}';
  IF p_body#>>'{chart,error}' IS NOT NULL OR m->>'symbol'<>'OGN' OR m->>'currency'<>'USD'
  OR m->>'instrumentType'<>'EQUITY' OR m->>'exchangeTimezoneName'<>'America/New_York'
  OR m->>'exchangeName' NOT IN('NYQ','NYSE') THEN RETURN NULL; END IF;
  v:=(m->>'regularMarketPrice')::numeric;
  t:=to_timestamp((m->>'regularMarketTime')::double precision);
  session_start:=to_timestamp((m#>>'{currentTradingPeriod,regular,start}')::double precision);
  session_end:=to_timestamp((m#>>'{currentTradingPeriod,regular,end}')::double precision);
  IF v<=0 OR v>=10000 OR t IS NULL OR t>p_now+interval '1 minute' OR t<p_now-interval '45 days'
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
  IF v<=0 OR v>=100 OR (m->>'cotacaoCompra')::numeric<=0
  OR (m->>'cotacaoCompra')::numeric>v OR t IS NULL OR t>p_now+interval '1 minute'
  OR t<p_now-interval '45 days' THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('value',v,'quoted_at',t,'currency','BRL','source_name','Banco Central · PTAX venda',
   'source_url','https://ptax.bcb.gov.br/ptax_internet/consultarUltimaCotacaoDolar.do',
   'market_state','daily_reference','details',jsonb_build_object('reference','PTAX','side','sell','timing','daily_reference_not_intraday'));
 END IF;
 RETURN NULL;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END $f$;
REVOKE ALL ON FUNCTION public.lts_market_parse_v290(text,jsonb,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_parse_v290(text,jsonb,timestamptz) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_market_request_quotes_v290()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE symbol text; target text; req bigint; ids jsonb:='[]'; day date:=(clock_timestamp() AT TIME ZONE 'America/Sao_Paulo')::date;
BEGIN
 FOREACH symbol IN ARRAY ARRAY['OGN','USD/BRL'] LOOP
  IF EXISTS(SELECT 1 FROM public.lts_market_request_v290 r WHERE r.symbol=symbol AND r.processed_at IS NULL AND r.requested_at>clock_timestamp()-interval '3 minutes')
  THEN CONTINUE; END IF;
  target:=CASE WHEN symbol='OGN' THEN 'https://query1.finance.yahoo.com/v8/finance/chart/OGN?interval=1d&range=5d'
  ELSE 'https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarPeriodo(dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?@dataInicial=%27'
   ||to_char(day-21,'MM-DD-YYYY')||'%27&@dataFinalCotacao=%27'||to_char(day,'MM-DD-YYYY')||'%27&$format=json&$orderby=dataHoraCotacao%20desc&$top=1' END;
  req:=net.http_get(url:=target,headers:='{"Accept":"application/json","User-Agent":"LTSWealth/1.0"}'::jsonb,timeout_milliseconds:=12000);
  INSERT INTO public.lts_market_request_v290(request_id,symbol) VALUES(req,symbol);
  INSERT INTO public.lts_market_refresh_v290(symbol,last_attempt_at,status) VALUES(symbol,clock_timestamp(),'consulting')
   ON CONFLICT(symbol) DO UPDATE SET last_attempt_at=excluded.last_attempt_at,status=excluded.status,error_code=NULL;
  ids:=ids||jsonb_build_array(jsonb_build_object('symbol',symbol,'request_id',req));
 END LOOP;
 RETURN ids;
END $f$;
REVOKE ALL ON FUNCTION public.lts_market_request_quotes_v290() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_request_quotes_v290() TO service_role;

CREATE OR REPLACE FUNCTION public.lts_market_collect_quotes_v290()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE r record; parsed jsonb; qid bigint; previous_id bigint; previous_time timestamptz; accepted integer:=0;
 changed boolean:=false; err text; body jsonb;
BEGIN
 FOR r IN SELECT req.*,res.status_code,res.content,res.timed_out,res.error_msg,res.created response_at
  FROM public.lts_market_request_v290 req LEFT JOIN net._http_response res ON res.id=req.request_id
  WHERE req.processed_at IS NULL AND (res.id IS NOT NULL OR req.requested_at<clock_timestamp()-interval '3 minutes')
  ORDER BY req.requested_at FOR UPDATE OF req SKIP LOCKED LOOP
  err:=NULL; parsed:=NULL;
  IF r.status_code IS NULL OR r.timed_out OR r.error_msg IS NOT NULL THEN err:='source_unavailable';
  ELSIF r.status_code<>200 THEN err:='http_'||r.status_code;
  ELSE
   BEGIN body:=r.content::jsonb; parsed:=public.lts_market_parse_v290(r.symbol,body,clock_timestamp());
   EXCEPTION WHEN OTHERS THEN parsed:=NULL; END;
   IF parsed IS NULL THEN err:='invalid_or_undated_quote'; END IF;
  END IF;
  IF err IS NULL THEN
   INSERT INTO public.lts_market_quote_v290(symbol,value,currency,quoted_at,source_name,source_url,market_state,details,received_at)
   VALUES(r.symbol,(parsed->>'value')::numeric,parsed->>'currency',(parsed->>'quoted_at')::timestamptz,
    parsed->>'source_name',parsed->>'source_url',parsed->>'market_state',parsed->'details',clock_timestamp())
   ON CONFLICT(symbol,source_name,quoted_at,value) DO NOTHING;
   SELECT id INTO qid FROM public.lts_market_quote_v290 q WHERE q.symbol=r.symbol
    AND q.source_name=parsed->>'source_name' AND q.quoted_at=(parsed->>'quoted_at')::timestamptz AND q.value=(parsed->>'value')::numeric;
   SELECT h.quote_id,q.quoted_at INTO previous_id,previous_time FROM public.lts_market_head_v290 h
    JOIN public.lts_market_quote_v290 q ON q.id=h.quote_id WHERE h.symbol=r.symbol;
   IF previous_time IS NULL OR (parsed->>'quoted_at')::timestamptz>=previous_time THEN
    INSERT INTO public.lts_market_head_v290(symbol,quote_id) VALUES(r.symbol,qid)
     ON CONFLICT(symbol) DO UPDATE SET quote_id=excluded.quote_id;
    changed:=changed OR qid IS DISTINCT FROM previous_id;
   END IF;
   accepted:=accepted+1;
  END IF;
  UPDATE public.lts_market_request_v290 SET processed_at=clock_timestamp(),error_code=err WHERE request_id=r.request_id;
  UPDATE public.lts_market_refresh_v290 SET last_response_at=clock_timestamp(),
   status=CASE WHEN err IS NULL THEN 'available' ELSE 'failed' END,error_code=err WHERE symbol=r.symbol;
 END LOOP;
 IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton; END IF;
 RETURN jsonb_build_object('accepted',accepted,'valuation_revision_changed',changed);
END $f$;
REVOKE ALL ON FUNCTION public.lts_market_collect_quotes_v290() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_collect_quotes_v290() TO service_role;

CREATE OR REPLACE FUNCTION public.lts_market_context_v290()
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
WITH quotes AS(SELECT h.symbol,to_jsonb(q) quote FROM public.lts_market_head_v290 h JOIN public.lts_market_quote_v290 q ON q.id=h.quote_id)
SELECT jsonb_build_object('stock',(SELECT quote FROM quotes WHERE symbol='OGN'),
 'usd_brl',(SELECT quote FROM quotes WHERE symbol='USD/BRL'),
 'complete',(SELECT count(*)=2 FROM quotes),'revision',(SELECT md5(string_agg(quote->>'id','|' ORDER BY symbol)) FROM quotes))
$f$;
REVOKE ALL ON FUNCTION public.lts_market_context_v290() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_context_v290() TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_market_quotes_v290()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); context jsonb:=public.lts_market_context_v290();
BEGIN
 RETURN context||jsonb_build_object('mode',coalesce((SELECT settings->>'market_quote_mode' FROM public.app_settings WHERE user_id=u),'automatic'),
 'refresh',(SELECT jsonb_agg(to_jsonb(s) ORDER BY symbol) FROM public.lts_market_refresh_v290 s),
 'consulted_at',clock_timestamp(),'request_frequency','hourly','financial_effect','valuation_only');
END $f$;
CREATE OR REPLACE FUNCTION public.lts_browser_market_mode_v290(p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 IF p_mode NOT IN('automatic','manual') OR p_mode IS NULL THEN RAISE EXCEPTION 'Modo inválido.'; END IF;
 INSERT INTO public.app_settings(user_id,settings) VALUES(u,jsonb_build_object('market_quote_mode',p_mode))
 ON CONFLICT(user_id) DO UPDATE SET settings=coalesce(app_settings.settings,'{}')||excluded.settings,updated_at=now();
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),
 'market_mode_v290',jsonb_build_object('mode',p_mode,'financial_effect','valuation_only'));
 RETURN jsonb_build_object('ok',true,'mode',p_mode);
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_market_quotes_v290(),public.lts_browser_market_mode_v290(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_market_quotes_v290(),public.lts_browser_market_mode_v290(text) TO authenticated,service_role;

CREATE VIEW public.lts_future_liquidity_effective_v290 WITH(security_invoker=true) AS
WITH quotes AS MATERIALIZED(SELECT public.lts_market_context_v290() context)
SELECT e.* FROM public.lts_future_liquidity_schedule s
CROSS JOIN quotes q LEFT JOIN public.app_settings a ON a.user_id=s.user_id
CROSS JOIN LATERAL jsonb_populate_record(NULL::public.lts_future_liquidity_schedule,to_jsonb(s)||CASE
 WHEN s.active AND s.eligibility_date>=(now() AT TIME ZONE 'America/Sao_Paulo')::date
 AND (upper(trim(s.asset_type))='RSU' OR lower(s.asset_type) LIKE '%cash%')
 AND q.context->>'complete'='true' AND coalesce(a.settings->>'market_quote_mode','automatic')='automatic'
 THEN jsonb_build_object('unit_price_assumption',(q.context#>>'{stock,value}')::numeric,
  'fx_assumption',(q.context#>>'{usd_brl,value}')::numeric,
  'gross_value_brl',round(s.quantity*(q.context#>>'{stock,value}')::numeric*(q.context#>>'{usd_brl,value}')::numeric,2),
  'net_value_brl',round(s.quantity*(q.context#>>'{stock,value}')::numeric*(q.context#>>'{usd_brl,value}')::numeric*
   CASE WHEN lower(s.asset_type) LIKE '%cash%' THEN 0.70 ELSE 1 END,2),
  'metadata',coalesce(s.metadata,'{}')||jsonb_build_object('valuation_basis','automatic_market_reference','market_quotes',q.context))
 ELSE '{}'::jsonb END)e;
REVOKE ALL ON public.lts_future_liquidity_effective_v290 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_future_liquidity_effective_v290 TO service_role;

-- Source leases are populated from the inspected live reader graph below.
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v6(uuid,date,date)'::regprocedure))<>'ae6a32d508a72b05b338055d9ceb75ce' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v6(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v6(p_user_id uuid, p_from date DEFAULT '2026-08-18'::date, p_to date DEFAULT '2026-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (select public.lts_current_evidence_position_v1(p_user_id) j),
start_acct as (
  select case when institution='Itau' then 'Itaú' else institution end account,
         coalesce((metadata->>'balance')::numeric,0) balance
  from public.accounts where user_id=p_user_id and is_active=true and institution in ('Itaú','Itau','Bradesco','C6')
), corrected as (
  select event_date,
         case when account='Itau' then 'Itaú' else account end account,
         description,signed_amount,source,source_ref,confidence,account_assignment,legacy_index,original_date,displaced
  from public.lts_corrected_cashflow_fix86_v3(p_user_id,p_from,p_to)
), own_transfer as (
  select fe.event_date,case when a.institution='Itau' then 'Itaú' else a.institution end account,
         coalesce(fe.description_normalized,fe.description_raw,'Transferência própria') description,
         fe.amount signed_amount,'internal_transfer'::text source,coalesce(fe.legacy_id,fe.id::text) source_ref,
         'documented_transfer_source'::text confidence,'assigned'::text account_assignment,
         fe.legacy_index,fe.event_date original_date,false displaced
  from public.financial_events fe left join public.accounts a on a.id=fe.account_id
  where fe.user_id=p_user_id and fe.event_date between p_from and p_to and coalesce(fe.is_suppressed,false)=false
    and (coalesce(fe.is_internal_transfer,false)=true or coalesce(fe.nature,'')='transfer')
), events as (
  select *,false internal_transfer from corrected
  union all select *,true from own_transfer
), days as (select generate_series(p_from,p_to,interval '1 day')::date dt),
daily as (
  select d.dt,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and not e.internal_transfer),0) itau_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and not e.internal_transfer),0) bradesco_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and not e.internal_transfer),0) c6_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and e.internal_transfer),0) itau_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and e.internal_transfer),0) bradesco_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and e.internal_transfer),0) c6_transfer,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account not in ('Itaú','Bradesco','C6')),0) nonbank_economic,
    coalesce(sum(-e.signed_amount) filter(where e.signed_amount<0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_exits,
    coalesce(sum(e.signed_amount) filter(where e.signed_amount>0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_entries,
    count(*) filter(where not e.internal_transfer) event_count,
    count(*) filter(where e.internal_transfer) transfer_count
  from days d left join events e on e.event_date=d.dt group by d.dt
), run as (
  select x.*,
    coalesce((select balance from start_acct where account='Itaú'),0)+sum(itau_operating+itau_transfer) over(order by dt) itau_balance,
    coalesce((select balance from start_acct where account='Bradesco'),0)+sum(bradesco_operating+bradesco_transfer) over(order by dt) bradesco_balance,
    coalesce((select balance from start_acct where account='C6'),0)+sum(c6_operating+c6_transfer) over(order by dt) c6_balance,
    coalesce((select sum(balance) from start_acct),0)+sum(bank_operating) over(order by dt) consolidated_bank,
    -sum(itau_transfer+bradesco_transfer+c6_transfer) over(order by dt) clearing_balance,
    ((select j->>'liquidity_now_d0' from pos)::numeric)+sum(bank_operating+nonbank_economic) over(order by dt) d0_economic
  from daily x
), constants as (
  select coalesce((select (j->>'liquid_d1_d3_assets')::numeric from pos),0) vested_now,
         coalesce((select (j->>'restricted_assets')::numeric from pos),0) fgts,
         coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true),0) future_total
), future_schedule as (
  select (eligibility_date+settlement_days)::date available_date,sum(coalesce(net_value_brl,gross_value_brl)) value_brl
  from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true group by 1
), enrich as (
  select r.*,c.vested_now+coalesce((select sum(value_brl) from future_schedule f where f.available_date<=r.dt),0) vested_total,
         c.fgts,coalesce((select sum(value_brl) from future_schedule f where f.available_date>r.dt),0) future_remaining,
         coalesce((select sum(f.signed_amount) from public.lts_corrected_cashflow_fix86_v3(p_user_id,r.dt+1,least(r.dt+30,p_to)) f),0) next30_net,
         lag(r.consolidated_bank) over(order by r.dt) previous_bank
  from run r cross join constants c
), day_json as (
  select jsonb_agg(jsonb_build_object(
    'date',dt,'is_today',dt=current_date,
    'Itaú',jsonb_build_object('net',itau_operating+itau_transfer,'balance',itau_balance),
    'Bradesco',jsonb_build_object('net',bradesco_operating+bradesco_transfer,'balance',bradesco_balance),
    'C6',jsonb_build_object('net',c6_operating+c6_transfer,'balance',c6_balance),
    'Transferências em trânsito',jsonb_build_object('balance',clearing_balance),
    'Consolidado',jsonb_build_object('bank_balance',consolidated_bank,'economic_d0_balance',d0_economic,'economic_net',bank_operating+nonbank_economic,'nonbank_economic_net',nonbank_economic),
    'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',bank_entries,'exits',bank_exits),'events',event_count,'transfers',transfer_count),
    'fix86_columns',jsonb_build_object(
      'saldo_anterior',coalesce(previous_bank,consolidated_bank-bank_operating),
      'entradas',bank_entries,'saidas',bank_exits,'saldo_final',consolidated_bank,
      'liq_d0_1',d0_economic,'posicao_antes_rsus',d0_economic,'rsus_vested',vested_total,
      'posicao_curto_prazo',d0_economic+vested_total,'liq_d30',d0_economic+next30_net,
      'fgts',fgts,'rsus_futuras',future_remaining,'posicao_economica_total',d0_economic+vested_total+fgts+future_remaining
    )
  ) order by dt) j from enrich
), ev_json as (
  select coalesce(jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'description',description,'signed_amount',signed_amount,
    'source',source,'source_ref',source_ref,'confidence',confidence,'account_assignment',account_assignment,'legacy_index',legacy_index,
    'original_date',original_date,'displaced',displaced,'internal_transfer',internal_transfer) order by event_date,source,description),'[]'::jsonb) j from events
)
select jsonb_build_object(
 'version','daily-flow-fix86-v6','from',p_from,'to',p_to,'days',(select j from day_json),'events',(select j from ev_json),
 'display_contract',jsonb_build_object('bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'columns',jsonb_build_array('Data','Saldo anterior','Entradas','Saídas','Saldo final','Liq. D+0/1','Posição antes de RSUs','RSUs vested','Posição curto prazo','Liq. D+30','FGTS','RSUs futuras','Posição econômica total'),'show_today',true,'show_drilldown',true),
 'semantic_contract',jsonb_build_object('projection_ops',true,'temporal_displacement',true,'scenario_off',true,'explicit_reconciliation',true,'coopharma_nonbank',true,'historical_2013_2017_cash',false,'internal_transfer_clearing',true),
 'guardrails',jsonb_build_array('Scenario-off descriptions do not contribute anywhere.','Projection operations replace the original occurrence.','Temporal displacement changes the date and preserves the obligation.','Coopharma is economic withholding and never a second bank debit.','Own transfers are neutral consolidated; unresolved destinations remain explicit in clearing.')
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v7(uuid,date,date)'::regprocedure))<>'2364d5e7ba95d1bc1a917e38c1684b83' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v7(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v7(p_user_id uuid, p_from date DEFAULT '2026-08-18'::date, p_to date DEFAULT '2026-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (select public.lts_current_evidence_position_v1(p_user_id) j),
start_acct as (
  select case when institution='Itau' then 'Itaú' else institution end account,
         coalesce((metadata->>'balance')::numeric,0) balance
  from public.accounts where user_id=p_user_id and is_active=true and institution in ('Itaú','Itau','Bradesco','C6')
), corrected as (
  select event_date,case when account='Itau' then 'Itaú' else account end account,description,signed_amount,source,source_ref,confidence,account_assignment,legacy_index,original_date,displaced
  from public.lts_corrected_cashflow_fix86_v4(p_user_id,p_from,p_to)
), own_transfer as (
  select event_date,account,description,signed_amount,'internal_transfer'::text source,source_ref,confidence,'assigned'::text account_assignment,null::integer legacy_index,event_date original_date,false displaced
  from public.lts_internal_transfer_legs_fix86_v1(p_user_id,p_from,p_to)
), events as (
  select *,false internal_transfer from corrected
  union all select *,true from own_transfer
), days as (select generate_series(p_from,p_to,interval '1 day')::date dt),
daily as (
  select d.dt,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and not e.internal_transfer),0) itau_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and not e.internal_transfer),0) bradesco_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and not e.internal_transfer),0) c6_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and e.internal_transfer),0) itau_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and e.internal_transfer),0) bradesco_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and e.internal_transfer),0) c6_transfer,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account not in ('Itaú','Bradesco','C6')),0) nonbank_economic,
    coalesce(sum(-e.signed_amount) filter(where e.signed_amount<0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_exits,
    coalesce(sum(e.signed_amount) filter(where e.signed_amount>0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_entries,
    count(*) filter(where not e.internal_transfer) event_count,
    count(*) filter(where e.internal_transfer) transfer_count
  from days d left join events e on e.event_date=d.dt group by d.dt
), run as (
  select x.*,
    coalesce((select balance from start_acct where account='Itaú'),0)+sum(itau_operating+itau_transfer) over(order by dt) itau_balance,
    coalesce((select balance from start_acct where account='Bradesco'),0)+sum(bradesco_operating+bradesco_transfer) over(order by dt) bradesco_balance,
    coalesce((select balance from start_acct where account='C6'),0)+sum(c6_operating+c6_transfer) over(order by dt) c6_balance,
    coalesce((select sum(balance) from start_acct),0)+sum(bank_operating) over(order by dt) consolidated_bank,
    -sum(itau_transfer+bradesco_transfer+c6_transfer) over(order by dt) clearing_balance,
    ((select j->>'liquidity_now_d0' from pos)::numeric)+sum(bank_operating+nonbank_economic) over(order by dt) d0_economic
  from daily x
), constants as (
  select coalesce((select (j->>'liquid_d1_d3_assets')::numeric from pos),0) vested_now,
         coalesce((select (j->>'restricted_assets')::numeric from pos),0) fgts
), future_schedule as (
  select (eligibility_date+settlement_days)::date available_date,sum(coalesce(net_value_brl,gross_value_brl)) value_brl
  from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true group by 1
), enrich as (
  select r.*,c.vested_now+coalesce((select sum(value_brl) from future_schedule f where f.available_date<=r.dt),0) vested_total,
         c.fgts,coalesce((select sum(value_brl) from future_schedule f where f.available_date>r.dt),0) future_remaining,
         coalesce((select sum(f.signed_amount) from public.lts_corrected_cashflow_fix86_v4(p_user_id,r.dt+1,least(r.dt+30,p_to)) f),0) next30_net,
         lag(r.consolidated_bank) over(order by r.dt) previous_bank
  from run r cross join constants c
), day_json as (
  select jsonb_agg(jsonb_build_object(
    'date',dt,'is_today',dt=current_date,
    'Itaú',jsonb_build_object('net',itau_operating+itau_transfer,'balance',itau_balance),
    'Bradesco',jsonb_build_object('net',bradesco_operating+bradesco_transfer,'balance',bradesco_balance),
    'C6',jsonb_build_object('net',c6_operating+c6_transfer,'balance',c6_balance),
    'Transferências em trânsito',jsonb_build_object('balance',clearing_balance),
    'Consolidado',jsonb_build_object('bank_balance',consolidated_bank,'economic_d0_balance',d0_economic,'economic_net',bank_operating+nonbank_economic,'nonbank_economic_net',nonbank_economic),
    'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',bank_entries,'exits',bank_exits),'events',event_count,'transfers',transfer_count),
    'fix86_columns',jsonb_build_object('saldo_anterior',coalesce(previous_bank,consolidated_bank-bank_operating),'entradas',bank_entries,'saidas',bank_exits,'saldo_final',consolidated_bank,'liq_d0_1',d0_economic,'posicao_antes_rsus',d0_economic,'rsus_vested',vested_total,'posicao_curto_prazo',d0_economic+vested_total,'liq_d30',d0_economic+next30_net,'fgts',fgts,'rsus_futuras',future_remaining,'posicao_economica_total',d0_economic+vested_total+fgts+future_remaining)
  ) order by dt) j from enrich
), ev_json as (
  select coalesce(jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'description',description,'signed_amount',signed_amount,'source',source,'source_ref',source_ref,'confidence',confidence,'account_assignment',account_assignment,'legacy_index',legacy_index,'original_date',original_date,'displaced',displaced,'internal_transfer',internal_transfer) order by event_date,source,description),'[]'::jsonb) j from events
)
select jsonb_build_object('version','daily-flow-fix86-v7','from',p_from,'to',p_to,'days',(select j from day_json),'events',(select j from ev_json),
 'display_contract',jsonb_build_object('bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'columns',jsonb_build_array('Data','Saldo anterior','Entradas','Saídas','Saldo final','Liq. D+0/1','Posição antes de RSUs','RSUs vested','Posição curto prazo','Liq. D+30','FGTS','RSUs futuras','Posição econômica total'),'show_today',true,'show_drilldown',true),
 'semantic_contract',jsonb_build_object('projection_ops',true,'temporal_displacement',true,'scenario_off',true,'explicit_reconciliation',true,'coopharma_nonbank',true,'historical_2013_2017_cash',false,'internal_transfer_clearing',true,'evento_usuario_transfer_legs',true,'confirmed_fact_override',true),
 'guardrails',jsonb_build_array('Scenario-off descriptions do not contribute anywhere.','Projection operations replace the original occurrence.','Temporal displacement changes the date and preserves the obligation.','Coopharma is economic withholding and never a second bank debit.','Own transfers are neutral consolidated and both documented legs change only their individual bank accounts.'));
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_cashflow_scenarios_v2(uuid,date,date)'::regprocedure))<>'dc3b66597d6b0b2f3396201ed64301db' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_cashflow_scenarios_v2(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_cashflow_scenarios_v2(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with ladder as materialized (
  select * from public.lts_dashboard_cash_ladder_v1(p_user_id,p_from,p_to)
), first_row as (
  select * from ladder order by flow_date limit 1
), last_row as (
  select * from ladder where flow_date=p_to limit 1
), vals as (
  select
    (select operational_cash from first_row) starting_operational_cash,
    (select d01_resource from first_row) starting_d01_resource,
    (select rsu_vested_today from first_row) starting_rsu_vested,
    (select fgts_projected from first_row) starting_fgts,
    (select balance_after_d01 from last_row) d0_end,
    (select balance_no_new_vesting from last_row) d3_end,
    (select balance_with_scheduled_vesting from last_row) conditional_end,
    (select min(flow_date) from ladder where balance_after_d01<0) d0_negative,
    (select min(flow_date) from ladder where balance_no_new_vesting<0) d3_negative,
    (select min(flow_date) from ladder where balance_with_scheduled_vesting<0) conditional_negative,
    (select max(rsu_vested_scheduled)-max(rsu_vested_today) from ladder) future_rsu_delta
), neg as (
  select
    (select balance_after_d01 from ladder where flow_date=(select d0_negative from vals)) d0_negative_balance,
    (select balance_no_new_vesting from ladder where flow_date=(select d3_negative from vals)) d3_negative_balance,
    (select balance_with_scheduled_vesting from ladder where flow_date=(select conditional_negative from vals)) conditional_negative_balance
), rsu as (
  select (eligibility_date+settlement_days)::date available_date,
         sum(gross_value_brl) gross_value
  from public.lts_future_liquidity_effective_v290
  where user_id=p_user_id and active=true
    and cash_treatment='conditional_future_liquidity'
    and gross_value_brl is not null
    and (eligibility_date+settlement_days)::date between p_from and p_to
  group by 1
)
select jsonb_build_object(
  'version','cashflow-scenarios-v3-first-negative-amount',
  'from',p_from,'to',p_to,
  'starting_bank_cash',(select starting_operational_cash from vals),
  'starting_d0_assets',(select starting_d01_resource from vals),
  'starting_d1_d3_assets',(select starting_rsu_vested from vals),
  'starting_fgts_restricted',(select starting_fgts from vals),
  'starting_semantics','operational cash after known events on the first day + D0/D1 resource + already vested D3; not documentary snapshot arithmetic',
  'conditional_rsu_gross_in_horizon',greatest(coalesce((select future_rsu_delta from vals),0),0),
  'scenarios',jsonb_build_array(
    jsonb_build_object('id','d0_only','label','Caixa + D+0/D1','treatment','operational_cash_plus_d01','ending_balance',(select d0_end from vals),'first_negative_date',(select d0_negative from vals),'first_negative_balance',(select d0_negative_balance from neg)),
    jsonb_build_object('id','current_d3','label','Caixa + D+0/D1 + ativos já disponíveis D+3','treatment','current_realizable_liquidity','ending_balance',(select d3_end from vals),'first_negative_date',(select d3_negative from vals),'first_negative_balance',(select d3_negative_balance from neg)),
    jsonb_build_object('id','conditional_rsu_gross','label','Inclui vestings programados apenas após vesting + liquidação','treatment','conditional_not_guaranteed_cash','ending_balance',(select conditional_end from vals),'first_negative_date',(select conditional_negative from vals),'first_negative_balance',(select conditional_negative_balance from neg),'warning','Vestings futuros são condicionais; preço, câmbio, tributação e efetiva liquidação podem alterar o valor realizado.')
  ),
  'conditional_liquidity',coalesce((select jsonb_agg(jsonb_build_object('available_date',available_date,'gross_value_brl',gross_value) order by available_date) from rsu),'[]'::jsonb),
  'guardrails',jsonb_build_array('Planejamento e Dashboard usam a mesma escada operacional do Fluxo Diário.','FGTS não entra em nenhum cenário de caixa.','RSUs já vested hoje entram apenas no cenário D+3; awards futuros não são caixa atual.','Vestings futuros entram somente no cenário condicionado e apenas após vesting + settlement.','Valor bruto de vesting futuro não é tratado como líquido garantido.')
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_bridge_v1(uuid,date,date)'::regprocedure))<>'3740ad828c757719152a59816102090d' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_bridge_v1(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_bridge_v1(p_user_id uuid, p_from date DEFAULT '2026-08-18'::date, p_to date DEFAULT '2026-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with flow as (
  select public.lts_daily_flow_v69plus_v1(p_user_id,p_from,p_to) j
), pos as (
  select public.lts_current_evidence_position_v1(p_user_id) j
), constants as (
  select
    coalesce(((select j->>'liquid_d0_assets' from pos))::numeric,0) d0_assets,
    coalesce(((select j->>'liquid_d1_d3_assets' from pos))::numeric,0) vested_now,
    coalesce(((select j->>'restricted_assets' from pos))::numeric,0) fgts,
    coalesce((select sum(coalesce(net_value_brl,gross_value_brl))
              from public.lts_future_liquidity_effective_v290
              where user_id=p_user_id and active=true),0) future_schedule_total
), schedule as (
  select (eligibility_date + settlement_days)::date available_date,
         sum(coalesce(net_value_brl,gross_value_brl)) value_brl
  from public.lts_future_liquidity_effective_v290
  where user_id=p_user_id and active=true
  group by 1
), days as (
  select d obj,(d->>'date')::date dt
  from flow,jsonb_array_elements(j->'days') d
), econ_future as (
  select d.dt,
         coalesce(sum(f.signed_amount),0) next30_net
  from days d
  left join lateral public.lts_corrected_cashflow_v1(p_user_id,d.dt+1,least(d.dt+30,p_to)) f on true
  group by d.dt
), enriched0 as (
  select d.dt,
         d.obj,
         c.d0_assets,
         c.vested_now + coalesce((select sum(value_brl) from schedule s where s.available_date<=d.dt),0) vested_total,
         c.fgts,
         coalesce((select sum(value_brl) from schedule s where s.available_date>d.dt),0) future_remaining,
         ef.next30_net,
         (d.obj#>>'{Consolidado,bank_balance}')::numeric bank_balance,
         (d.obj#>>'{Consolidado,economic_d0_balance}')::numeric d0_balance
  from days d cross join constants c join econ_future ef on ef.dt=d.dt
), enriched as (
  select e.*,lag(bank_balance) over(order by dt) prev_bank_balance
  from enriched0 e
), rows as (
  select jsonb_agg(
    obj || jsonb_build_object(
      'fix86_columns',jsonb_build_object(
        'saldo_anterior', coalesce(prev_bank_balance,bank_balance - coalesce((obj#>>'{summary,Consolidado,entries}')::numeric,0) + coalesce((obj#>>'{summary,Consolidado,exits}')::numeric,0)),
        'entradas', coalesce((obj#>>'{summary,Consolidado,entries}')::numeric,0),
        'saidas', coalesce((obj#>>'{summary,Consolidado,exits}')::numeric,0),
        'saldo_final', bank_balance,
        'liq_d0_1', d0_balance,
        'posicao_antes_rsus', d0_balance,
        'rsus_vested', vested_total,
        'posicao_curto_prazo', d0_balance + vested_total,
        'liq_d30', d0_balance + next30_net,
        'fgts', fgts,
        'rsus_futuras', future_remaining,
        'posicao_economica_total', d0_balance + vested_total + fgts + future_remaining
      ),
      'fix86_semantics',jsonb_build_object(
        'future_assets_basis','sum(net_value_brl when available, else gross_value_brl) from certified future schedule',
        'future_assets_total_at_start',(select future_schedule_total from constants),
        'funding_mode','recommendation_only_pending_exact_FIX86_port',
        'fgts_current_cash',false,
        'future_rsu_current_cash',false
      )
    ) order by dt
  ) j
  from enriched
)
select (select j from flow) || jsonb_build_object(
  'version','daily-flow-fix86-bridge-v1',
  'days',(select j from rows),
  'legacy_reference_contract',jsonb_build_object(
    'columns',jsonb_build_array(
      'Data','Saldo anterior','Entradas','Saídas','Saldo final','Liq. D+0/1',
      'Posição antes de RSUs','RSUs vested','Posição curto prazo','Liq. D+30',
      'FGTS','RSUs futuras','Posição econômica total'
    ),
    'bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),
    'source','FIX86 Legacy Reference Release / document 04',
    'funding_exact_parity',false
  ),
  'guardrails',coalesce((select j->'guardrails' from flow),'[]'::jsonb) || jsonb_build_array(
    'Bridge exposes FIX86 financial layers without treating FGTS or unvested awards as current cash.',
    'Future schedule uses net estimated values for Cash Awards where available and gross values for RSUs, matching the certified Legacy future-assets total.',
    'Exact derived-funding behavior is intentionally not claimed until the FIX86 algorithm is ported and cross-screen tested.'
  )
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_dashboard_executive_v2(uuid,date)'::regprocedure))<>'bd0a1b02954ec504aebd77f07971056c' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_dashboard_executive_v2(uuid,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_dashboard_executive_v2(p_user_id uuid, p_as_of date DEFAULT '2026-08-19'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (
  select public.lts_current_evidence_position_v1(p_user_id) j
), scen as (
  select public.lts_cashflow_scenarios_v1(p_user_id,p_as_of,make_date(extract(year from p_as_of)::int,12,31)) j
), s as (
  select
    (select x from jsonb_array_elements((select j->'scenarios' from scen)) x where x->>'id'='d0_only') d0,
    (select x from jsonb_array_elements((select j->'scenarios' from scen)) x where x->>'id'='current_d3') d3,
    (select x from jsonb_array_elements((select j->'scenarios' from scen)) x where x->>'id'='conditional_rsu_gross') cond
), flow as (
  select public.lts_daily_flow_v69plus_v1(p_user_id,p_as_of,make_date(extract(year from p_as_of)::int,12,31)) j
), account_risk as (
  select jsonb_agg(jsonb_build_object(
    'account',account_name,
    'first_negative_date',first_negative,
    'minimum_projected_balance',min_balance,
    'risk_type',case when first_negative is null then 'none' else 'funding_or_redistribution_need' end,
    'interpretation',case when first_negative is null then 'No negative projected bank balance in horizon.' else 'Account-specific negative balance. This can require redistribution between own accounts and does not by itself mean consolidated resource shortage.' end
  ) order by account_name) j
  from (
    select account_name,min(dt) filter(where bal<0) first_negative,min(bal) min_balance
    from (
      select (d->>'date')::date dt,'Itaú' account_name,(d#>>'{Itaú,balance}')::numeric bal from flow,jsonb_array_elements(j->'days') d
      union all
      select (d->>'date')::date,'Bradesco',(d#>>'{Bradesco,balance}')::numeric from flow,jsonb_array_elements(j->'days') d
      union all
      select (d->>'date')::date,'C6',(d#>>'{C6,balance}')::numeric from flow,jsonb_array_elements(j->'days') d
    ) z group by account_name
  ) q
), horizons as (
  select jsonb_agg(jsonb_build_object(
    'id',id,'label',label,'date',dt,
    'current_liquidity_balance',current_balance,
    'conditional_rsu_balance',conditional_balance,
    'current_liquidity_status',case when current_balance<0 then 'negative' when current_balance<20000 then 'attention' else 'covered' end,
    'conditional_status',case when conditional_balance<0 then 'negative' when conditional_balance<20000 then 'attention' else 'covered' end
  ) order by ord) j
  from (
    select 1 ord,'30d' id,'30 dias' label,p_as_of+30 dt
    union all select 2,'90d','90 dias',p_as_of+90
    union all select 3,'year_end','Fim de 2026',make_date(extract(year from p_as_of)::int,12,31)
  ) h
  cross join lateral (
    select
      coalesce(((select j->>'liquidity_through_d3' from pos))::numeric,0)
        +coalesce((select sum(signed_amount) from public.lts_corrected_cashflow_v1(p_user_id,p_as_of,h.dt)),0) current_balance,
      coalesce(((select j->>'liquidity_through_d3' from pos))::numeric,0)
        +coalesce((select sum(signed_amount) from public.lts_corrected_cashflow_v1(p_user_id,p_as_of,h.dt)),0)
        +coalesce((select sum(gross_value_brl) from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true and cash_treatment='conditional_future_liquidity' and gross_value_brl is not null and (eligibility_date+settlement_days)::date between p_as_of and h.dt),0) conditional_balance
  ) b
), audit as (select public.lts_projection_year_audit_v1(p_user_id,extract(year from p_as_of)::int,extract(year from p_as_of)::int+5) j),
comm as (select public.lts_commitments_summary_v1(p_user_id,p_as_of) j),
comm_tot as (
  select coalesce(sum(coalesce((x->>'remaining_scheduled_outflow')::numeric,(x->>'remaining_economic_outflow')::numeric,0)),0) total
  from comm,jsonb_array_elements(j->'commitments') x
), vals as (
 select
   nullif((select d3->>'first_negative_date' from s),'')::date current_rupture,
   nullif((select cond->>'first_negative_date' from s),'')::date patrimonial_rupture,
   (select (d3->>'ending_balance')::numeric from s) current_end,
   (select (cond->>'ending_balance')::numeric from s) conditional_end,
   (select (scen.j->>'conditional_rsu_gross_in_horizon')::numeric from scen) future_rsu_gross
)
select jsonb_build_object(
 'version','dashboard-executive-v2',
 'as_of',p_as_of,
 'health_status',case when (select patrimonial_rupture from vals) is not null then 'critical' when (select current_rupture from vals) is not null then 'attention' else 'ok' end,
 'headline',case
   when (select patrimonial_rupture from vals) is not null then 'Risco de insuficiência de recursos após considerar liquidez futura elegível'
   when (select current_rupture from vals) is not null then 'Liquidez atual exige planejamento, mas recursos futuros condicionais cobrem o horizonte de 2026'
   else 'Liquidez coberta no horizonte de 2026'
 end,
 'executive_message',case
   when (select patrimonial_rupture from vals) is not null then 'Mesmo após recursos futuros elegíveis, o cenário cruza zero em '||(select patrimonial_rupture from vals)::text||'.'
   when (select current_rupture from vals) is not null then 'Sem monetizar novas RSUs, a liquidez atualmente realizável cruza zero em '||(select current_rupture from vals)::text||'. Considerando RSUs previstas somente após vesting + liquidação, o cenário permanece positivo até 31/12/2026. Isso é necessidade de planejamento de liquidez, não falta patrimonial de recursos.'
   else 'A liquidez realizável permanece coberta até 31/12/2026 no cenário atual.'
 end,
 'risk_layers',jsonb_build_object(
   'account_level',jsonb_build_object('label','Necessidade por conta','items',(select j from account_risk),'meaning','Saldo negativo em uma conta específica pode ser resolvido por redistribuição entre contas próprias; não equivale automaticamente a falta consolidada de recursos.'),
   'current_liquidity',jsonb_build_object('label','Liquidez já realizável hoje','first_negative_date',(select current_rupture from vals),'ending_balance_2026',(select current_end from vals),'meaning','Caixa + D+0 + ativos já vested/realizáveis. Não inclui RSUs que ainda precisam vesting.'),
   'conditional_future_liquidity',jsonb_build_object('label','Liquidez futura condicionada','first_negative_date',(select patrimonial_rupture from vals),'ending_balance_2026',(select conditional_end from vals),'future_rsu_gross',(select future_rsu_gross from vals),'meaning','Inclui RSUs somente após vesting + D+3, em valor bruto sujeito a preço, câmbio, impostos e efetiva liquidação.'),
   'restricted_wealth',jsonb_build_object('label','Patrimônio restrito','fgts',(select (j->>'restricted_assets')::numeric from pos),'meaning','FGTS e outros ativos restritos não cobrem fluxo automaticamente.')
 ),
 'position',(select j from pos),
 'horizons',(select j from horizons),
 'future_liquidity_calendar',(select j->'conditional_liquidity' from scen),
 'projection_audit',(select j from audit),
 'commitments_total_remaining',(select total from comm_tot),
 'actions',jsonb_build_array(
   case when (select current_rupture from vals) is not null and (select patrimonial_rupture from vals) is null then jsonb_build_object('priority',1,'type','liquidity_planning','status','attention','title','Planejar monetização/redistribuição antes de '||(select current_rupture from vals)::text,'detail','Não é uma ruptura patrimonial no cenário condicionado; é um ponto de gestão de liquidez.')
        when (select patrimonial_rupture from vals) is not null then jsonb_build_object('priority',1,'type','resource_gap','status','action','title','Cobrir insuficiência projetada','detail','Há ruptura mesmo após liquidez futura elegível.')
        else jsonb_build_object('priority',1,'type','liquidity','status','ok','title','Liquidez coberta','detail','Nenhuma ruptura no horizonte de 2026.') end,
   jsonb_build_object('priority',2,'type','bank_funding','status','attention','title','Antecipar saldos negativos por conta','detail','Tratar como redistribuição/funding entre contas antes de chamar de falta de recursos.'),
   jsonb_build_object('priority',3,'type','projection_quality','status','attention','title','Manter confiança do horizonte explícita','detail','2030/2031 não podem gerar alerta decisório enquanto séries recorrentes estiverem incompletas.')
 ),
 'guardrails',jsonb_build_array(
   'Conta negativa não significa automaticamente falta consolidada de recursos.',
   'FGTS é restrito e não entra em cobertura de caixa.',
   'RSUs futuras não são caixa atual e só entram após vesting + settlement.',
   'RSU futura é mostrada em valor bruto e continua condicionada a preço, câmbio, impostos e liquidação.',
   'Alerta grave de falta de recursos deve usar a camada patrimonial/condicionada apropriada, não apenas o cenário conservador.'
 )
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v17(uuid,date,date)'::regprocedure))<>'1fee6d308d298f28409ab034dd1eca26' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v17(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v17(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  base jsonb;
  d jsonb;
  dt date;
  rsu_remaining numeric;
  cash_remaining numeric;
  rsu_matured numeric;
  cash_matured numeric;
  rsu_documented numeric;
  rsu_projected numeric;
  bank_close numeric;
  d0_resource numeric;
  fgts_value numeric;
  position_before_rsu numeric;
  position_short numeric;
  economic_total numeric;
  out_days jsonb := '[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid range';
  end if;

  base := public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);

  for d in select value from jsonb_array_elements(coalesce(base->'days','[]'::jsonb))
  loop
    dt := (d->>'date')::date;

    select
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU'
          and (s.eligibility_date+s.settlement_days)::date > dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH'
          and (s.eligibility_date+s.settlement_days)::date > dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU'
          and (s.eligibility_date+s.settlement_days)::date > current_date
          and (s.eligibility_date+s.settlement_days)::date <= dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH'
          and (s.eligibility_date+s.settlement_days)::date > current_date
          and (s.eligibility_date+s.settlement_days)::date <= dt
      ),0)
    into rsu_remaining,cash_remaining,rsu_matured,cash_matured
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id and s.active=true;

    bank_close := coalesce(
      nullif(d#>>'{fix86_columns,saldo_final_operacional}','')::numeric,
      nullif(d#>>'{fix86_columns,saldo_final}','')::numeric,
      nullif(d#>>'{Consolidado,bank_balance}','')::numeric,
      0
    );
    d0_resource := coalesce(nullif(d#>>'{fix86_columns,liq_d0_1_recurso}','')::numeric,0);
    fgts_value := coalesce(nullif(d#>>'{fix86_columns,fgts}','')::numeric,0);
    rsu_documented := coalesce(nullif(d#>>'{fix86_columns,rsus_vested}','')::numeric,0);
    rsu_projected := rsu_documented + rsu_matured;
    position_before_rsu := bank_close + d0_resource;
    position_short := position_before_rsu + rsu_projected;
    economic_total := position_short + fgts_value + rsu_remaining + cash_remaining + cash_matured;

    d := jsonb_set(d,'{fix86_columns,rsus_vested_documentadas}',to_jsonb(rsu_documented),true);
    d := jsonb_set(d,'{fix86_columns,rsus_vestidas_programadas_no_horizonte}',to_jsonb(rsu_matured),true);
    d := jsonb_set(d,'{fix86_columns,rsus_vested}',to_jsonb(rsu_projected),true);
    d := jsonb_set(d,'{fix86_columns,posicao_antes_rsus}',to_jsonb(position_before_rsu),true);
    d := jsonb_set(d,'{fix86_columns,saldo_apos_rsu}',to_jsonb(position_short),true);
    d := jsonb_set(d,'{fix86_columns,posicao_curto_prazo}',to_jsonb(position_short),true);
    d := jsonb_set(d,'{fix86_columns,disponivel_total}',to_jsonb(position_short),true);
    d := jsonb_set(d,'{fix86_columns,rsus_futuras}',to_jsonb(rsu_remaining),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_futuros}',to_jsonb(cash_remaining),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_disponiveis_no_horizonte}',to_jsonb(cash_matured),true);
    d := jsonb_set(d,'{fix86_columns,saldo_apos_fgts}',to_jsonb(position_short+fgts_value),true);
    d := jsonb_set(d,'{fix86_columns,posicao_economica_total}',to_jsonb(economic_total),true);
    out_days := out_days || jsonb_build_array(d);
  end loop;

  return (base-'days') || jsonb_build_object(
    'days',out_days,
    'version','daily-flow-fix86-v17-rsu-transition-cash-separated',
    'future_awards_contract',jsonb_build_object(
      'source','lts_future_liquidity_schedule',
      'availability_rule','eligibility_date_plus_settlement_days',
      'rsu_future_moves_to_projected_vested_after_availability',true,
      'cash_awards_remain_separate_from_rsu',true,
      'cash_awards_not_assumed_into_bank_cash',true,
      'future_awards_excluded_from_current_cash_before_availability',true,
      'documentary_current_rsu_preserved',true
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v4(uuid,date,date)'::regprocedure))<>'d901e21901f6b20d83b19733d3baca7b' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v4(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v4(p_user_id uuid, p_from date DEFAULT '2026-08-18'::date, p_to date DEFAULT '2026-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (select public.lts_current_evidence_position_v1(p_user_id) j),
start_acct as (
  select case when institution='Itau' then 'Itaú' else institution end account,
         coalesce((metadata->>'balance')::numeric,0) balance
  from public.accounts where user_id=p_user_id and is_active=true and institution in ('Itaú','Itau','Bradesco','C6')
), corrected as (
  select event_date,
         case when account='Itau' then 'Itaú' else account end account,
         description,signed_amount,source,source_ref,confidence,account_assignment,legacy_index,original_date,displaced
  from public.lts_corrected_cashflow_fix86_v1(p_user_id,p_from,p_to)
), own_transfer as (
  select fe.event_date,case when a.institution='Itau' then 'Itaú' else a.institution end account,
         coalesce(fe.description_normalized,fe.description_raw,'Transferência própria') description,
         fe.amount signed_amount,'internal_transfer'::text source,coalesce(fe.legacy_id,fe.id::text) source_ref,
         'documented_transfer_source'::text confidence,'assigned'::text account_assignment,
         fe.legacy_index,fe.event_date original_date,false displaced
  from public.financial_events fe left join public.accounts a on a.id=fe.account_id
  where fe.user_id=p_user_id and fe.event_date between p_from and p_to and coalesce(fe.is_suppressed,false)=false
    and (coalesce(fe.is_internal_transfer,false)=true or coalesce(fe.nature,'')='transfer')
), events as (
  select *,false internal_transfer from corrected
  union all select *,true from own_transfer
), days as (select generate_series(p_from,p_to,interval '1 day')::date dt),
daily as (
  select d.dt,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and not e.internal_transfer),0) itau_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and not e.internal_transfer),0) bradesco_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and not e.internal_transfer),0) c6_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and e.internal_transfer),0) itau_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and e.internal_transfer),0) bradesco_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and e.internal_transfer),0) c6_transfer,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account not in ('Itaú','Bradesco','C6')),0) nonbank_economic,
    coalesce(sum(-e.signed_amount) filter(where e.signed_amount<0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_exits,
    coalesce(sum(e.signed_amount) filter(where e.signed_amount>0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_entries,
    count(*) filter(where not e.internal_transfer) event_count,
    count(*) filter(where e.internal_transfer) transfer_count
  from days d left join events e on e.event_date=d.dt group by d.dt
), run as (
  select x.*,
    coalesce((select balance from start_acct where account='Itaú'),0)+sum(itau_operating+itau_transfer) over(order by dt) itau_balance,
    coalesce((select balance from start_acct where account='Bradesco'),0)+sum(bradesco_operating+bradesco_transfer) over(order by dt) bradesco_balance,
    coalesce((select balance from start_acct where account='C6'),0)+sum(c6_operating+c6_transfer) over(order by dt) c6_balance,
    coalesce((select sum(balance) from start_acct),0)+sum(bank_operating) over(order by dt) consolidated_bank,
    -sum(itau_transfer+bradesco_transfer+c6_transfer) over(order by dt) clearing_balance,
    ((select j->>'liquidity_now_d0' from pos)::numeric)+sum(bank_operating+nonbank_economic) over(order by dt) d0_economic
  from daily x
), constants as (
  select coalesce((select (j->>'liquid_d1_d3_assets')::numeric from pos),0) vested_now,
         coalesce((select (j->>'restricted_assets')::numeric from pos),0) fgts,
         coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true),0) future_total
), future_schedule as (
  select (eligibility_date+settlement_days)::date available_date,sum(coalesce(net_value_brl,gross_value_brl)) value_brl
  from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true group by 1
), enrich as (
  select r.*,c.vested_now+coalesce((select sum(value_brl) from future_schedule f where f.available_date<=r.dt),0) vested_total,
         c.fgts,coalesce((select sum(value_brl) from future_schedule f where f.available_date>r.dt),0) future_remaining,
         coalesce((select sum(f.signed_amount) from public.lts_corrected_cashflow_fix86_v1(p_user_id,r.dt+1,least(r.dt+30,p_to)) f),0) next30_net,
         lag(r.consolidated_bank) over(order by r.dt) previous_bank
  from run r cross join constants c
), day_json as (
  select jsonb_agg(jsonb_build_object(
    'date',dt,'is_today',dt=current_date,
    'Itaú',jsonb_build_object('net',itau_operating+itau_transfer,'balance',itau_balance),
    'Bradesco',jsonb_build_object('net',bradesco_operating+bradesco_transfer,'balance',bradesco_balance),
    'C6',jsonb_build_object('net',c6_operating+c6_transfer,'balance',c6_balance),
    'Transferências em trânsito',jsonb_build_object('balance',clearing_balance),
    'Consolidado',jsonb_build_object('bank_balance',consolidated_bank,'economic_d0_balance',d0_economic,'economic_net',bank_operating+nonbank_economic,'nonbank_economic_net',nonbank_economic),
    'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',bank_entries,'exits',bank_exits),'events',event_count,'transfers',transfer_count),
    'fix86_columns',jsonb_build_object(
      'saldo_anterior',coalesce(previous_bank,consolidated_bank-bank_operating),
      'entradas',bank_entries,'saidas',bank_exits,'saldo_final',consolidated_bank,
      'liq_d0_1',d0_economic,'posicao_antes_rsus',d0_economic,'rsus_vested',vested_total,
      'posicao_curto_prazo',d0_economic+vested_total,'liq_d30',d0_economic+next30_net,
      'fgts',fgts,'rsus_futuras',future_remaining,'posicao_economica_total',d0_economic+vested_total+fgts+future_remaining
    )
  ) order by dt) j from enrich
), ev_json as (
  select coalesce(jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'description',description,'signed_amount',signed_amount,
    'source',source,'source_ref',source_ref,'confidence',confidence,'account_assignment',account_assignment,'legacy_index',legacy_index,
    'original_date',original_date,'displaced',displaced,'internal_transfer',internal_transfer) order by event_date,source,description),'[]'::jsonb) j from events
)
select jsonb_build_object(
 'version','daily-flow-fix86-v4','from',p_from,'to',p_to,'days',(select j from day_json),'events',(select j from ev_json),
 'display_contract',jsonb_build_object('bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'columns',jsonb_build_array('Data','Saldo anterior','Entradas','Saídas','Saldo final','Liq. D+0/1','Posição antes de RSUs','RSUs vested','Posição curto prazo','Liq. D+30','FGTS','RSUs futuras','Posição econômica total'),'show_today',true,'show_drilldown',true),
 'semantic_contract',jsonb_build_object('projection_ops',true,'temporal_displacement',true,'scenario_off',true,'explicit_reconciliation',true,'coopharma_nonbank',true,'historical_2013_2017_cash',false,'internal_transfer_clearing',true),
 'guardrails',jsonb_build_array('Scenario-off descriptions do not contribute anywhere.','Projection operations replace the original occurrence.','Temporal displacement changes the date and preserves the obligation.','Coopharma is economic withholding and never a second bank debit.','Own transfers are neutral consolidated; unresolved destinations remain explicit in clearing.')
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_cashflow_scenarios_from_flow_v1(uuid,date,date,jsonb)'::regprocedure))<>'7a211ee54f927d670f3c18fda1f2c8b5' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_cashflow_scenarios_from_flow_v1(uuid,date,date,jsonb)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_cashflow_scenarios_from_flow_v1(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with ladder as materialized (
  select * from public.lts_dashboard_cash_ladder_from_flow_v1(p_user_id,p_from,p_to,p_flow)
), first_row as (
  select * from ladder order by flow_date limit 1
), last_row as (
  select * from ladder where flow_date=p_to limit 1
), vals as (
  select
    (select operational_cash from first_row) starting_operational_cash,
    (select d01_resource from first_row) starting_d01_resource,
    (select rsu_vested_today from first_row) starting_rsu_vested,
    (select fgts_projected from first_row) starting_fgts,
    (select balance_after_d01 from last_row) d0_end,
    (select balance_no_new_vesting from last_row) d3_end,
    (select balance_with_scheduled_vesting from last_row) conditional_end,
    (select min(flow_date) from ladder where balance_after_d01<0) d0_negative,
    (select min(flow_date) from ladder where balance_no_new_vesting<0) d3_negative,
    (select min(flow_date) from ladder where balance_with_scheduled_vesting<0) conditional_negative,
    (select max(rsu_vested_scheduled)-max(rsu_vested_today) from ladder) future_rsu_delta
), neg as (
  select
    (select balance_after_d01 from ladder where flow_date=(select d0_negative from vals)) d0_negative_balance,
    (select balance_no_new_vesting from ladder where flow_date=(select d3_negative from vals)) d3_negative_balance,
    (select balance_with_scheduled_vesting from ladder where flow_date=(select conditional_negative from vals)) conditional_negative_balance
), rsu as (
  select (eligibility_date+settlement_days)::date available_date,sum(gross_value_brl) gross_value
  from public.lts_future_liquidity_effective_v290
  where user_id=p_user_id and active=true and cash_treatment='conditional_future_liquidity' and gross_value_brl is not null
    and (eligibility_date+settlement_days)::date between p_from and p_to
  group by 1
)
select jsonb_build_object(
  'version','cashflow-scenarios-v3-first-negative-amount','from',p_from,'to',p_to,
  'starting_bank_cash',(select starting_operational_cash from vals),'starting_d0_assets',(select starting_d01_resource from vals),
  'starting_d1_d3_assets',(select starting_rsu_vested from vals),'starting_fgts_restricted',(select starting_fgts from vals),
  'starting_semantics','operational cash after known events on the first day + D0/D1 resource + already vested D3; not documentary snapshot arithmetic',
  'conditional_rsu_gross_in_horizon',greatest(coalesce((select future_rsu_delta from vals),0),0),
  'scenarios',jsonb_build_array(
    jsonb_build_object('id','d0_only','label','Caixa + D+0/D1','treatment','operational_cash_plus_d01','ending_balance',(select d0_end from vals),'first_negative_date',(select d0_negative from vals),'first_negative_balance',(select d0_negative_balance from neg)),
    jsonb_build_object('id','current_d3','label','Caixa + D+0/D1 + ativos já disponíveis D+3','treatment','current_realizable_liquidity','ending_balance',(select d3_end from vals),'first_negative_date',(select d3_negative from vals),'first_negative_balance',(select d3_negative_balance from neg)),
    jsonb_build_object('id','conditional_rsu_gross','label','Inclui vestings programados apenas após vesting + liquidação','treatment','conditional_not_guaranteed_cash','ending_balance',(select conditional_end from vals),'first_negative_date',(select conditional_negative from vals),'first_negative_balance',(select conditional_negative_balance from neg),'warning','Vestings futuros são condicionais; preço, câmbio, tributação e efetiva liquidação podem alterar o valor realizado.')
  ),
  'conditional_liquidity',coalesce((select jsonb_agg(jsonb_build_object('available_date',available_date,'gross_value_brl',gross_value) order by available_date) from rsu),'[]'::jsonb),
  'guardrails',jsonb_build_array('Planejamento e Dashboard usam a mesma escada operacional do Fluxo Diário.','FGTS não entra em nenhum cenário de caixa.','RSUs já vested hoje entram apenas no cenário D+3; awards futuros não são caixa atual.','Vestings futuros entram somente no cenário condicionado e apenas após vesting + settlement.','Valor bruto de vesting futuro não é tratado como líquido garantido.'));
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v18(uuid,date,date)'::regprocedure))<>'34d19c3a7049ac2cb5f117efb35f9fb1' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v18(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v18(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  base jsonb;
  d jsonb;
  dt date;
  rsu_remaining numeric;
  cash_remaining numeric;
  rsu_matured numeric;
  cash_matured numeric;
  base_after_fgts numeric;
  economic_total numeric;
  out_days jsonb := '[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from > p_to then raise exception 'invalid range'; end if;
  base := public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);

  for d in select value from jsonb_array_elements(coalesce(base->'days','[]'::jsonb))
  loop
    dt := (d->>'date')::date;
    select
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU' and (s.eligibility_date+s.settlement_days)::date > dt),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH' and (s.eligibility_date+s.settlement_days)::date > dt),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU'
          and (s.eligibility_date+s.settlement_days)::date > current_date
          and (s.eligibility_date+s.settlement_days)::date <= dt),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH'
          and (s.eligibility_date+s.settlement_days)::date > current_date
          and (s.eligibility_date+s.settlement_days)::date <= dt),0)
    into rsu_remaining,cash_remaining,rsu_matured,cash_matured
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id and s.active=true;

    base_after_fgts := coalesce(
      nullif(d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,
      coalesce(nullif(d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,
               nullif(d#>>'{fix86_columns,posicao_curto_prazo}','')::numeric,
               0)
      + coalesce(nullif(d#>>'{fix86_columns,fgts}','')::numeric,0)
    );

    -- v14 already moves scheduled RSUs into projected vested liquidity through lts_flow_dynamic_layers_v1.
    -- Therefore matured RSU is an audit marker only and is NOT added again to economic total.
    -- Cash awards remain separate and are not assumed into bank cash; matured cash remains economic-only.
    economic_total := base_after_fgts + rsu_remaining + cash_remaining + cash_matured;

    d := jsonb_set(d,'{fix86_columns,rsus_futuras}',to_jsonb(rsu_remaining),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_futuros}',to_jsonb(cash_remaining),true);
    d := jsonb_set(d,'{fix86_columns,rsus_futuras_disponiveis_no_horizonte}',to_jsonb(rsu_matured),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_disponiveis_no_horizonte}',to_jsonb(cash_matured),true);
    d := jsonb_set(d,'{fix86_columns,posicao_economica_total}',to_jsonb(economic_total),true);
    out_days := out_days || jsonb_build_array(d);
  end loop;

  return (base-'days') || jsonb_build_object(
    'days',out_days,
    'version','daily-flow-fix86-v18-future-award-economic-parity',
    'future_awards_contract',jsonb_build_object(
      'source','lts_future_liquidity_schedule',
      'availability_rule','eligibility_date_plus_settlement_days',
      'rsu_projected_vesting_owned_by_v14_dynamic_layers',true,
      'rsu_remaining_shown_separately',true,
      'cash_awards_shown_separately',true,
      'cash_awards_not_assumed_into_bank_cash',true,
      'matured_cash_economic_only_until_documented',true,
      'no_rsu_double_count',true
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v15(uuid,date,date)'::regprocedure))<>'fd21e6517f1672018bdbc94d32ef471b' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v15(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v15(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  base jsonb;
  d jsonb;
  dt date;
  remaining numeric;
  matured numeric;
  base_economic numeric;
  economic_total numeric;
  out_days jsonb := '[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid range';
  end if;

  base := public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);

  for d in
    select value from jsonb_array_elements(coalesce(base->'days','[]'::jsonb))
  loop
    dt := (d->>'date')::date;

    select
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where (s.eligibility_date + s.settlement_days)::date > dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where (s.eligibility_date + s.settlement_days)::date > current_date
          and (s.eligibility_date + s.settlement_days)::date <= dt
      ),0)
    into remaining,matured
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id
      and s.active=true;

    base_economic := coalesce(
      nullif(d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,
      coalesce(nullif(d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,
               nullif(d#>>'{fix86_columns,posicao_curto_prazo}','')::numeric,
               nullif(d#>>'{fix86_columns,liq_d0_1}','')::numeric,
               0)
      + coalesce(nullif(d#>>'{fix86_columns,fgts}','')::numeric,0)
    );
    economic_total := base_economic + remaining + matured;

    d := jsonb_set(d,'{fix86_columns,rsus_futuras}',to_jsonb(remaining),true);
    d := jsonb_set(d,'{fix86_columns,rsus_futuras_vestidas_no_horizonte}',to_jsonb(matured),true);
    d := jsonb_set(d,'{fix86_columns,rsus_futuras_total_evidenciado}',to_jsonb(remaining+matured),true);
    d := jsonb_set(d,'{fix86_columns,posicao_economica_total}',to_jsonb(economic_total),true);
    out_days := out_days || jsonb_build_array(d);
  end loop;

  return (base-'days') || jsonb_build_object(
    'days',out_days,
    'version','daily-flow-fix86-v15-future-rsu-economic-layer',
    'future_rsu_contract',jsonb_build_object(
      'source','lts_future_liquidity_schedule',
      'availability_rule','eligibility_date_plus_settlement_days',
      'remaining_only_in_rsus_futuras',true,
      'excluded_from_current_cash_and_d3',true,
      'documentary_vested_preserved',true,
      'economic_total_keeps_horizon_matured_awards',true
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v16(uuid,date,date)'::regprocedure))<>'3d574eb07d31d7f78d391a6262f54400' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v16(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v16(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  base jsonb;
  d jsonb;
  dt date;
  rsu_remaining numeric;
  cash_remaining numeric;
  rsu_matured numeric;
  cash_matured numeric;
  base_economic numeric;
  economic_total numeric;
  out_days jsonb := '[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid range';
  end if;

  base := public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);

  for d in
    select value from jsonb_array_elements(coalesce(base->'days','[]'::jsonb))
  loop
    dt := (d->>'date')::date;

    select
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU'
          and (s.eligibility_date + s.settlement_days)::date > dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH'
          and (s.eligibility_date + s.settlement_days)::date > dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='RSU'
          and (s.eligibility_date + s.settlement_days)::date > current_date
          and (s.eligibility_date + s.settlement_days)::date <= dt
      ),0),
      coalesce(sum(coalesce(s.net_value_brl,s.gross_value_brl)) filter (
        where upper(coalesce(s.asset_type,''))='CASH'
          and (s.eligibility_date + s.settlement_days)::date > current_date
          and (s.eligibility_date + s.settlement_days)::date <= dt
      ),0)
    into rsu_remaining,cash_remaining,rsu_matured,cash_matured
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id and s.active=true;

    base_economic := coalesce(
      nullif(d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,
      coalesce(nullif(d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,
               nullif(d#>>'{fix86_columns,posicao_curto_prazo}','')::numeric,
               nullif(d#>>'{fix86_columns,liq_d0_1}','')::numeric,
               0)
      + coalesce(nullif(d#>>'{fix86_columns,fgts}','')::numeric,0)
    );

    economic_total := base_economic + rsu_remaining + cash_remaining + rsu_matured + cash_matured;

    d := jsonb_set(d,'{fix86_columns,rsus_futuras}',to_jsonb(rsu_remaining),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_futuros}',to_jsonb(cash_remaining),true);
    d := jsonb_set(d,'{fix86_columns,rsus_futuras_disponiveis_no_horizonte}',to_jsonb(rsu_matured),true);
    d := jsonb_set(d,'{fix86_columns,cash_awards_disponiveis_no_horizonte}',to_jsonb(cash_matured),true);
    d := jsonb_set(d,'{fix86_columns,posicao_economica_total}',to_jsonb(economic_total),true);
    out_days := out_days || jsonb_build_array(d);
  end loop;

  return (base-'days') || jsonb_build_object(
    'days',out_days,
    'version','daily-flow-fix86-v16-rsu-cash-awards-separated',
    'future_awards_contract',jsonb_build_object(
      'source','lts_future_liquidity_schedule',
      'availability_rule','eligibility_date_plus_settlement_days',
      'rsu_and_cash_separate',true,
      'excluded_from_current_cash_and_d3_before_availability',true,
      'documentary_vested_preserved',true,
      'economic_total_keeps_horizon_awards',true
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_cashflow_scenarios_v1(uuid,date,date)'::regprocedure))<>'ec395f8e00fb028e5cf67425a65420cd' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_cashflow_scenarios_v1(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_cashflow_scenarios_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
with acct as (
  select coalesce(sum((metadata->>'balance')::numeric),0) bank_cash
  from public.accounts where user_id=p_user_id and is_active=true
), assets as (
  select
    coalesce(sum(value_brl) filter (where is_available_now=true and liquidity_class='D+0'),0) d0,
    coalesce(sum(value_brl) filter (where is_available_now=true and liquidity_class in ('D+1','D+2','D+3')),0) d1d3
  from public.asset_positions where user_id=p_user_id
), cf as (
  select event_date,sum(signed_amount) net_day
  from public.lts_corrected_cashflow_v1(p_user_id,p_from,p_to)
  group by event_date
), rsu as (
  select (eligibility_date + settlement_days)::date available_date,
         sum(gross_value_brl) gross_value
  from public.lts_future_liquidity_effective_v290
  where user_id=p_user_id and active=true
    and cash_treatment='conditional_future_liquidity'
    and gross_value_brl is not null
    and (eligibility_date + settlement_days)::date between p_from and p_to
  group by 1
), dates as (
  select event_date d from cf
  union
  select available_date from rsu
  union
  select p_to
), daily as (
  select d,
         coalesce((select net_day from cf where event_date=d),0) operating_net,
         coalesce((select gross_value from rsu where available_date=d),0) conditional_rsu_gross
  from dates
), run as (
  select d,operating_net,conditional_rsu_gross,
    (select bank_cash from acct)+(select d0 from assets)
      +sum(operating_net) over(order by d rows unbounded preceding) as balance_d0,
    (select bank_cash from acct)+(select d0+d1d3 from assets)
      +sum(operating_net) over(order by d rows unbounded preceding) as balance_current_liquidity,
    (select bank_cash from acct)+(select d0+d1d3 from assets)
      +sum(operating_net+conditional_rsu_gross) over(order by d rows unbounded preceding) as balance_with_conditional_rsu_gross
  from daily
), totals as (
  select
    (select bank_cash from acct) bank_cash,
    (select d0 from assets) d0,
    (select d1d3 from assets) d1d3,
    coalesce((select sum(net_day) from cf),0) corrected_net,
    coalesce((select sum(gross_value) from rsu),0) conditional_rsu_gross
)
select jsonb_build_object(
 'version','cashflow-scenarios-v1',
 'from',p_from,'to',p_to,
 'starting_bank_cash',(select bank_cash from totals),
 'starting_d0_assets',(select d0 from totals),
 'starting_d1_d3_assets',(select d1d3 from totals),
 'corrected_operating_net',(select corrected_net from totals),
 'conditional_rsu_gross_in_horizon',(select conditional_rsu_gross from totals),
 'scenarios',jsonb_build_array(
   jsonb_build_object(
     'id','d0_only','label','Caixa + D+0','treatment','conservative_current_liquidity',
     'ending_balance',(select balance_d0 from run where d=p_to),
     'first_negative_date',(select min(d) from run where balance_d0<0)
   ),
   jsonb_build_object(
     'id','current_d3','label','Caixa + D+0 + ativos já disponíveis D+3','treatment','current_realizable_liquidity',
     'ending_balance',(select balance_current_liquidity from run where d=p_to),
     'first_negative_date',(select min(d) from run where balance_current_liquidity<0)
   ),
   jsonb_build_object(
     'id','conditional_rsu_gross','label','Inclui RSUs 2026 após vesting + D+3, a valor bruto','treatment','conditional_not_guaranteed_cash',
     'ending_balance',(select balance_with_conditional_rsu_gross from run where d=p_to),
     'first_negative_date',(select min(d) from run where balance_with_conditional_rsu_gross<0),
     'warning','Valor bruto: preço, câmbio, tributação e efetiva liquidação podem alterar o valor disponível.'
   )
 ),
 'conditional_liquidity',coalesce((select jsonb_agg(jsonb_build_object('available_date',available_date,'gross_value_brl',gross_value) order by available_date) from rsu),'[]'::jsonb),
 'guardrails',jsonb_build_array(
   'FGTS não entra em nenhum cenário de caixa.',
   'RSUs futuras só entram no cenário condicionado após data de vesting + prazo de liquidação.',
   'Valor bruto de RSU não é tratado como líquido garantido.',
   'O fluxo operacional usa somente o candidato corrigido e permanece sujeito ao runtime gate.'
 )
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_asset_layers_fix86_v1(uuid,date)'::regprocedure))<>'09348da3333d422dfe88f0f00f2eea80' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_asset_layers_fix86_v1(uuid,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_asset_layers_fix86_v1(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with snapshots as (
  select jsonb_agg(jsonb_build_object(
    'id',id,'asset_name',asset_name,'asset_type',asset_type,'as_of_date',as_of_date,'value_brl',value_brl,
    'liquidity_class',liquidity_class,'available_now',is_available_now,'evidence_sha256',metadata->>'evidence_sha256',
    'role','documentary_snapshot') order by asset_name) j,
    coalesce(sum(value_brl) filter(where liquidity_class='D+0'),0) d0,
    coalesce(sum(value_brl) filter(where liquidity_class='D+3' and is_available_now),0) d3,
    coalesce(sum(value_brl) filter(where liquidity_class='restricted'),0) restricted
  from public.asset_positions where user_id=p_user_id and as_of_date<=p_as_of
), schedule as (
  select jsonb_agg(jsonb_build_object(
    'id',id,'asset_type',asset_type,'eligibility_date',eligibility_date,'available_date',(eligibility_date+settlement_days)::date,
    'gross_value_brl',gross_value_brl,'net_value_brl',net_value_brl,'tax_status',tax_status,'confidence',confidence,
    'role','derived_future_schedule') order by eligibility_date,id) j,
    coalesce(sum(coalesce(net_value_brl,gross_value_brl)) filter(where (eligibility_date+settlement_days)::date<=p_as_of),0) available_by_date,
    coalesce(sum(coalesce(net_value_brl,gross_value_brl)) filter(where (eligibility_date+settlement_days)::date>p_as_of),0) future_after_date
  from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true
)
select jsonb_build_object(
 'version','asset-layers-fix86-v1','as_of',p_as_of,
 'documentary_snapshots',coalesce((select j from snapshots),'[]'::jsonb),
 'derived_future_schedule',coalesce((select j from schedule),'[]'::jsonb),
 'totals',jsonb_build_object('d0_snapshot',(select d0 from snapshots),'d3_snapshot',(select d3 from snapshots),'restricted_snapshot',(select restricted from snapshots),'schedule_available_by_date',(select available_by_date from schedule),'schedule_future_after_date',(select future_after_date from schedule)),
 'guardrails',jsonb_build_array('Persisted asset_positions are documentary snapshots/evidence, not rolling calculated positions.','Future vesting/settlement is derived at read time from lts_future_liquidity_schedule.','Derived schedule values are never written back into documentary snapshots.','FGTS/restricted assets never become current cash automatically.')
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v5(uuid,date,date)'::regprocedure))<>'25fbd24cc17aafc955f3a11ccd8f4a7e' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v5(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v5(p_user_id uuid, p_from date DEFAULT '2026-08-18'::date, p_to date DEFAULT '2026-12-31'::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with pos as (select public.lts_current_evidence_position_v1(p_user_id) j),
start_acct as (
  select case when institution='Itau' then 'Itaú' else institution end account,
         coalesce((metadata->>'balance')::numeric,0) balance
  from public.accounts where user_id=p_user_id and is_active=true and institution in ('Itaú','Itau','Bradesco','C6')
), corrected as (
  select event_date,
         case when account='Itau' then 'Itaú' else account end account,
         description,signed_amount,source,source_ref,confidence,account_assignment,legacy_index,original_date,displaced
  from public.lts_corrected_cashflow_fix86_v2(p_user_id,p_from,p_to)
), own_transfer as (
  select fe.event_date,case when a.institution='Itau' then 'Itaú' else a.institution end account,
         coalesce(fe.description_normalized,fe.description_raw,'Transferência própria') description,
         fe.amount signed_amount,'internal_transfer'::text source,coalesce(fe.legacy_id,fe.id::text) source_ref,
         'documented_transfer_source'::text confidence,'assigned'::text account_assignment,
         fe.legacy_index,fe.event_date original_date,false displaced
  from public.financial_events fe left join public.accounts a on a.id=fe.account_id
  where fe.user_id=p_user_id and fe.event_date between p_from and p_to and coalesce(fe.is_suppressed,false)=false
    and (coalesce(fe.is_internal_transfer,false)=true or coalesce(fe.nature,'')='transfer')
), events as (
  select *,false internal_transfer from corrected
  union all select *,true from own_transfer
), days as (select generate_series(p_from,p_to,interval '1 day')::date dt),
daily as (
  select d.dt,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and not e.internal_transfer),0) itau_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and not e.internal_transfer),0) bradesco_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and not e.internal_transfer),0) c6_operating,
    coalesce(sum(e.signed_amount) filter(where e.account='Itaú' and e.internal_transfer),0) itau_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='Bradesco' and e.internal_transfer),0) bradesco_transfer,
    coalesce(sum(e.signed_amount) filter(where e.account='C6' and e.internal_transfer),0) c6_transfer,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_operating,
    coalesce(sum(e.signed_amount) filter(where not e.internal_transfer and e.account not in ('Itaú','Bradesco','C6')),0) nonbank_economic,
    coalesce(sum(-e.signed_amount) filter(where e.signed_amount<0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_exits,
    coalesce(sum(e.signed_amount) filter(where e.signed_amount>0 and not e.internal_transfer and e.account in ('Itaú','Bradesco','C6')),0) bank_entries,
    count(*) filter(where not e.internal_transfer) event_count,
    count(*) filter(where e.internal_transfer) transfer_count
  from days d left join events e on e.event_date=d.dt group by d.dt
), run as (
  select x.*,
    coalesce((select balance from start_acct where account='Itaú'),0)+sum(itau_operating+itau_transfer) over(order by dt) itau_balance,
    coalesce((select balance from start_acct where account='Bradesco'),0)+sum(bradesco_operating+bradesco_transfer) over(order by dt) bradesco_balance,
    coalesce((select balance from start_acct where account='C6'),0)+sum(c6_operating+c6_transfer) over(order by dt) c6_balance,
    coalesce((select sum(balance) from start_acct),0)+sum(bank_operating) over(order by dt) consolidated_bank,
    -sum(itau_transfer+bradesco_transfer+c6_transfer) over(order by dt) clearing_balance,
    ((select j->>'liquidity_now_d0' from pos)::numeric)+sum(bank_operating+nonbank_economic) over(order by dt) d0_economic
  from daily x
), constants as (
  select coalesce((select (j->>'liquid_d1_d3_assets')::numeric from pos),0) vested_now,
         coalesce((select (j->>'restricted_assets')::numeric from pos),0) fgts,
         coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true),0) future_total
), future_schedule as (
  select (eligibility_date+settlement_days)::date available_date,sum(coalesce(net_value_brl,gross_value_brl)) value_brl
  from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true group by 1
), enrich as (
  select r.*,c.vested_now+coalesce((select sum(value_brl) from future_schedule f where f.available_date<=r.dt),0) vested_total,
         c.fgts,coalesce((select sum(value_brl) from future_schedule f where f.available_date>r.dt),0) future_remaining,
         coalesce((select sum(f.signed_amount) from public.lts_corrected_cashflow_fix86_v2(p_user_id,r.dt+1,least(r.dt+30,p_to)) f),0) next30_net,
         lag(r.consolidated_bank) over(order by r.dt) previous_bank
  from run r cross join constants c
), day_json as (
  select jsonb_agg(jsonb_build_object(
    'date',dt,'is_today',dt=current_date,
    'Itaú',jsonb_build_object('net',itau_operating+itau_transfer,'balance',itau_balance),
    'Bradesco',jsonb_build_object('net',bradesco_operating+bradesco_transfer,'balance',bradesco_balance),
    'C6',jsonb_build_object('net',c6_operating+c6_transfer,'balance',c6_balance),
    'Transferências em trânsito',jsonb_build_object('balance',clearing_balance),
    'Consolidado',jsonb_build_object('bank_balance',consolidated_bank,'economic_d0_balance',d0_economic,'economic_net',bank_operating+nonbank_economic,'nonbank_economic_net',nonbank_economic),
    'summary',jsonb_build_object('Consolidado',jsonb_build_object('entries',bank_entries,'exits',bank_exits),'events',event_count,'transfers',transfer_count),
    'fix86_columns',jsonb_build_object(
      'saldo_anterior',coalesce(previous_bank,consolidated_bank-bank_operating),
      'entradas',bank_entries,'saidas',bank_exits,'saldo_final',consolidated_bank,
      'liq_d0_1',d0_economic,'posicao_antes_rsus',d0_economic,'rsus_vested',vested_total,
      'posicao_curto_prazo',d0_economic+vested_total,'liq_d30',d0_economic+next30_net,
      'fgts',fgts,'rsus_futuras',future_remaining,'posicao_economica_total',d0_economic+vested_total+fgts+future_remaining
    )
  ) order by dt) j from enrich
), ev_json as (
  select coalesce(jsonb_agg(jsonb_build_object('event_date',event_date,'account',account,'description',description,'signed_amount',signed_amount,
    'source',source,'source_ref',source_ref,'confidence',confidence,'account_assignment',account_assignment,'legacy_index',legacy_index,
    'original_date',original_date,'displaced',displaced,'internal_transfer',internal_transfer) order by event_date,source,description),'[]'::jsonb) j from events
)
select jsonb_build_object(
 'version','daily-flow-fix86-v5','from',p_from,'to',p_to,'days',(select j from day_json),'events',(select j from ev_json),
 'display_contract',jsonb_build_object('bank_tabs',jsonb_build_array('Consolidado','Itaú','Bradesco','C6'),'columns',jsonb_build_array('Data','Saldo anterior','Entradas','Saídas','Saldo final','Liq. D+0/1','Posição antes de RSUs','RSUs vested','Posição curto prazo','Liq. D+30','FGTS','RSUs futuras','Posição econômica total'),'show_today',true,'show_drilldown',true),
 'semantic_contract',jsonb_build_object('projection_ops',true,'temporal_displacement',true,'scenario_off',true,'explicit_reconciliation',true,'coopharma_nonbank',true,'historical_2013_2017_cash',false,'internal_transfer_clearing',true),
 'guardrails',jsonb_build_array('Scenario-off descriptions do not contribute anywhere.','Projection operations replace the original occurrence.','Temporal displacement changes the date and preserves the obligation.','Coopharma is economic withholding and never a second bank debit.','Own transfers are neutral consolidated; unresolved destinations remain explicit in clearing.')
);
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_wealth_detail_v2()'::regprocedure))<>'da3b5cc93b0196f63bdca18ee26c0a95' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_browser_wealth_detail_v2()'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_settings jsonb := '{}'::jsonb;
  v_schedule jsonb := '[]'::jsonb;
  v_retention_events jsonb := '[]'::jsonb;
  v_awards jsonb := '{}'::jsonb;
begin
  v_base := public.lts_browser_wealth_detail_v1();

  select coalesce(settings, '{}'::jsonb)
    into v_settings
  from public.app_settings
  where user_id = v_uid;

  with source_rows as (
    select
      s.id,
      case when lower(s.asset_type) like '%cash%' then 'Cash RSU' else 'RSU' end as award_type,
      s.eligibility_date,
      (s.eligibility_date + s.settlement_days) as available_date,
      s.quantity,
      s.unit_price_assumption,
      s.fx_assumption,
      s.gross_value_brl,
      s.net_value_brl,
      s.tax_status,
      s.cash_treatment,
      s.confidence,
      s.source
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id = v_uid
      and s.active = true
      and (upper(trim(s.asset_type)) = 'RSU' or lower(s.asset_type) like '%cash%')
  ), grouped as (
    select
      award_type,
      eligibility_date,
      max(available_date) as available_date,
      array_agg(id order by id) as award_ids,
      sum(quantity) as quantity,
      case when min(unit_price_assumption) = max(unit_price_assumption)
        then min(unit_price_assumption) end as unit_price_usd,
      case when min(fx_assumption) = max(fx_assumption)
        then min(fx_assumption) end as fx_rate,
      sum(gross_value_brl) as gross_value_brl,
      case when award_type = 'Cash RSU'
        then sum(coalesce(net_value_brl, 0))
        else sum(gross_value_brl)
      end as considered_value_brl,
      min(tax_status) as tax_status,
      min(cash_treatment) as cash_treatment,
      min(confidence) as confidence,
      min(source) as source,
      (case when award_type = 'Cash RSU' then 'cash_rsu:' else 'rsu:' end)
        || eligibility_date::text as group_key
    from source_rows
    group by award_type, eligibility_date
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'group_key', group_key,
      'award_ids', to_jsonb(award_ids),
      'asset_type', award_type,
      'eligibility_date', eligibility_date,
      'available_date', available_date,
      'quantity', quantity,
      'unit_price_usd', unit_price_usd,
      'fx_rate', fx_rate,
      'gross_value_brl', gross_value_brl,
      'net_value_brl', considered_value_brl,
      'anticipated_date', nullif(v_settings #>> array['wealth_v165','vesting_anticipation',group_key], ''),
      'tax_status', tax_status,
      'cash_treatment', cash_treatment,
      'confidence', confidence,
      'source', source
    ) order by eligibility_date, award_type
  ), '[]'::jsonb)
  into v_schedule
  from grouped;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', e.id::text,
      'date', (e.dados->>'dia')::date,
      'description', e.dados->>'desc',
      'account', e.dados->>'conta',
      'direction', e.dados->>'efeito',
      'amount', abs((e.dados->>'valor')::numeric)
    ) order by (e.dados->>'dia')::date, e.id
  ), '[]'::jsonb)
  into v_retention_events
  from public.evento_base e
  where e.usuario_id = v_uid
    and lower(coalesce(e.dados->>'desc','')) like '%retention%';

  v_awards := coalesce(v_settings #> '{wealth_v165,employment_awards}', '{}'::jsonb)
    || jsonb_build_object('retention_projected_events', v_retention_events);

  return v_base || jsonb_build_object(
    'version', 'wealth-detail-v3-private-awards-v165',
    'rsu', coalesce(v_base->'rsu', '{}'::jsonb) || jsonb_build_object(
      'future_schedule', v_schedule,
      'future_schedule_count', jsonb_array_length(v_schedule),
      'grouped_by_vesting_date', true,
      'anticipation_persisted', true
    ),
    'employment_awards', v_awards
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_flow_dynamic_layers_v1(uuid,date,date)'::regprocedure))<>'926175319039786ca9cdc057d7c21780' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_flow_dynamic_layers_v1(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_flow_dynamic_layers_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(flow_date date, payroll_withholding_today numeric, fgts_value numeric, fgts_monthly_accrual numeric, vested_rsu_value numeric, vested_rsu_added_today numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with params as (
  select
    coalesce((select value_brl from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),0)::numeric fgts_anchor,
    coalesce((select as_of_date from public.asset_positions where user_id=p_user_id and asset_type='FGTS' order by as_of_date desc limit 1),p_from)::date fgts_anchor_date,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='salario_base' limit 1),0)::numeric fgts_salary_base,
    coalesce((select (dados->>'_v')::numeric from public.fgts where usuario_id=p_user_id and dados->>'_k'='percentual' limit 1),0)::numeric fgts_pct,
    coalesce((select (dados->>'_v')::boolean from public.fgts where usuario_id=p_user_id and dados->>'_k'='ativo' limit 1),false)::boolean fgts_active,
    coalesce((select sum(value_brl) from public.asset_positions where user_id=p_user_id and is_available_now=true and liquidity_class in ('D+1','D+2','D+3')),0)::numeric rsu_anchor
), salary_dates as (
  select distinct f.event_date from params p cross join lateral public.lts_corrected_cashflow_fix86_v4(p_user_id,(p.fgts_anchor_date+1)::date,p_to) f
  where f.signed_amount>0 and lower(trim(f.description))='salário'
), award_schedule as (
  select (eligibility_date+settlement_days)::date available_date,
    sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl)
             else coalesce(gross_value_brl,net_value_brl) end)::numeric value_brl
  from public.lts_future_liquidity_effective_v290
  where user_id=p_user_id and active=true
    and (upper(trim(asset_type))='RSU' or lower(asset_type) like '%cash%')
  group by 1
), withholding as (
  select effective_event_date event_date,sum(amount)::numeric amt
  from public.lts_payroll_withholding_effective_v1(p_user_id,p_from,p_to) group by effective_event_date
), days as (
  select (p_from+s.n)::date d
  from generate_series(0,p_to-p_from) as s(n)
)
select d.d,coalesce(w.amt,0)::numeric,
 (p.fgts_anchor+case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)*(select count(*) from salary_dates s where s.event_date<=d.d) else 0 end)::numeric,
 case when p.fgts_active then (p.fgts_salary_base*p.fgts_pct)::numeric else 0::numeric end,
 (p.rsu_anchor+coalesce((select sum(r.value_brl) from award_schedule r where r.available_date<=d.d),0))::numeric,
 coalesce((select sum(r.value_brl) from award_schedule r where r.available_date=d.d),0)::numeric
from days d cross join params p left join withholding w on w.event_date=d.d order by d.d;
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v19(uuid,date,date)'::regprocedure))<>'cf23cb93cfbcfbc31dc664abb2b96faf' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v19(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v19(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare base jsonb; d jsonb; dt date; rsu_remaining numeric; cash_remaining numeric; base_after_fgts numeric; out_days jsonb:='[]'::jsonb; out_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  base:=public.lts_daily_flow_fix86_v14(p_user_id,p_from,p_to);
  -- Aggregate once instead of repeatedly copying a growing JSON array.
  -- Identical fields, availability dates and input ordering.
  with schedule as materialized (
    select upper(trim(asset_type)) kind,lower(asset_type) lower_kind,
      eligibility_date+settlement_days available_date,
      coalesce(gross_value_brl,net_value_brl) rsu_value,
      coalesce(net_value_brl,gross_value_brl) cash_value
    from public.lts_future_liquidity_effective_v290 where user_id=p_user_id and active=true
  ), valued as (
    select x.d,x.ordinality,
      coalesce(nullif(x.d#>>'{fix86_columns,saldo_apos_fgts}','')::numeric,
        coalesce(nullif(x.d#>>'{fix86_columns,saldo_apos_rsu}','')::numeric,0)
        +coalesce(nullif(x.d#>>'{fix86_columns,fgts}','')::numeric,0)) base_total,
      s.rsu_remaining,s.cash_remaining
    from jsonb_array_elements(coalesce(base->'days','[]'::jsonb)) with ordinality x(d,ordinality)
    cross join lateral (
      select coalesce(sum(rsu_value) filter(where kind='RSU' and available_date>(x.d->>'date')::date),0) rsu_remaining,
        coalesce(sum(cash_value) filter(where lower_kind like '%cash%' and available_date>(x.d->>'date')::date),0) cash_remaining
      from schedule
    ) s
  )
  select coalesce(jsonb_agg(
    jsonb_set(jsonb_set(jsonb_set(v.d,
      '{fix86_columns,rsus_futuras}',to_jsonb(v.rsu_remaining),true),
      '{fix86_columns,cash_awards_futuros}',to_jsonb(v.cash_remaining),true),
      '{fix86_columns,posicao_economica_total}',to_jsonb(v.base_total+v.rsu_remaining+v.cash_remaining),true)
    order by v.ordinality),'[]'::jsonb) into out_days from valued v;
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb) into out_events from (
    select value e from jsonb_array_elements(coalesce(base->'events','[]'::jsonb))
    union all
    select jsonb_build_object('event_date',(s.eligibility_date+s.settlement_days)::date,'account','Corretora','description','Cash RSU disponível','signed_amount',coalesce(s.net_value_brl,s.gross_value_brl),'category','Cash RSU','source','future_cash_rsu','source_ref',s.id,'status','expected','editable',false,'availability_from_vesting',true)
    from public.lts_future_liquidity_effective_v290 s where s.user_id=p_user_id and s.active=true and lower(s.asset_type) like '%cash%' and (s.eligibility_date+s.settlement_days)::date between p_from and p_to
  ) q;
  return (base-'days'-'events')||jsonb_build_object('days',out_days,'events',out_events,'version','daily-flow-fix86-v19-cash-rsu-availability','future_awards_contract',jsonb_build_object('availability_rule','eligibility_date_plus_settlement_days','cash_rsu_net_factor',0.70,'cash_rsu_enters_projected_liquidity_on_available_date',true,'no_award_before_availability',true));
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_wealth_detail_v3()'::regprocedure))<>'1b4f1f68228d3f5a7b481a606dbc9a0c' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_browser_wealth_detail_v3()'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v3()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_pensions jsonb:='[]'::jsonb;
  v_pension_total numeric:=0;
  v_rsu jsonb:='{}'::jsonb;
  v_commitments jsonb;
  v_docs jsonb;
  v_cipo_components jsonb:='[]'::jsonb;
  v_base_assets numeric:=0;
  v_base_net numeric:=0;
begin
  v_base:=public.lts_browser_wealth_detail_v2();
  with latest as (
    select distinct on (legacy_id) legacy_id,asset_name,as_of_date,quantity,unit_price,value_brl,liquidity_class,availability_note,metadata
    from public.asset_positions
    where user_id=v_uid and asset_type='private_pension'
    order by legacy_id,as_of_date desc,id desc
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',legacy_id,'name',asset_name,'as_of',as_of_date,'units',quantity,'unit_value',unit_price,
      'gross_balance_brl',value_brl,'liquidity_class',liquidity_class,'availability_note',availability_note,
      'tax_regime',metadata->>'tax_regime','profile',metadata->>'profile',
      'participant_balance_brl',metadata->'participant_balance_brl','sponsor_balance_brl',metadata->'sponsor_balance_brl',
      'monthly_return_brl',metadata->'monthly_return_brl','monthly_return_pct',metadata->'monthly_return_pct',
      'source_label',metadata->>'source_label'
    ) order by asset_name),'[]'::jsonb),coalesce(sum(value_brl),0)
    into v_pensions,v_pension_total from latest;

  select jsonb_build_object(
    'vested_shares_brl',coalesce(sum(value_brl) filter(where asset_type='RSU' and is_available_now),0),
    'brokerage_cash_brl',coalesce(sum(value_brl) filter(where asset_type='brokerage_cash' and is_available_now),0),
    'available_total_brl',coalesce(sum(value_brl) filter(where asset_type in ('RSU','brokerage_cash') and is_available_now),0),
    'as_of',max(as_of_date) filter(where asset_type in ('RSU','brokerage_cash')),
    'future_regular_brl',coalesce((select sum(coalesce(gross_value_brl,net_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active and upper(trim(asset_type))='RSU'),0),
    'future_cash_net_brl',coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active and lower(asset_type) like '%cash%'),0),
    'future_considered_total_brl',coalesce((select sum(case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl) else coalesce(gross_value_brl,net_value_brl) end) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active),0)
  ) into v_rsu
  from public.asset_positions where user_id=v_uid;

  v_commitments:=public.lts_commitments_summary_v1(v_uid,current_date);
  v_docs:=public.lts_documentary_commitments_v1(v_uid);
  v_cipo_components:=coalesce(v_base#>'{wealth,cipo_reconciliation,components}',v_base#>'{cipo,components}','[]'::jsonb);
  v_base_assets:=coalesce(nullif(v_base#>>'{wealth,summary,assets_central}','')::numeric,0);
  v_base_net:=coalesce(nullif(v_base#>>'{wealth,summary,net_worth_central}','')::numeric,0);

  return v_base||jsonb_build_object(
    'version','wealth-detail-v4-v167-pensions-financing',
    'pensions',jsonb_build_object('total_gross_brl',v_pension_total,'positions',v_pensions,
      'tax_note','Regime regressivo: a alíquota depende do tempo de cada contribuição; o saldo líquido não é inferido.'),
    'rsu_summary',v_rsu,
    'financing',jsonb_build_object('summary',v_commitments,'documentary',v_docs),
    'cipo_detail',jsonb_build_object('components',v_cipo_components,
      'historical_purchase_plus_reform_brl',v_base#>'{wealth,assets,cipo_396,historical_purchase_plus_reform}',
      'current_payoff_brl',v_base#>'{wealth,assets,cipo_396,documentary_debt}',
      'contractual_outflow_current_terms_brl',(select x->'remaining_scheduled_outflow_current_terms'
        from jsonb_array_elements(coalesce(v_commitments->'commitments','[]'::jsonb)) x
        where x->>'id'='cipo_396' limit 1),
      'subject_to_tr',true),
    'wealth_v167',jsonb_build_object('assets_central_including_pensions',v_base_assets+v_pension_total,
      'net_worth_central_including_pensions',v_base_net+v_pension_total,'pensions_are_restricted',true),
    'schiavalli',jsonb_build_object('status','documentary_position_not_located','included_in_total',false)
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_daily_flow_fix86_v20(uuid,date,date)'::regprocedure))<>'ee68c6489b5e9648bb4e32fd8597d12a' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_daily_flow_fix86_v20(uuid,date,date)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_daily_flow_fix86_v20(p_user_id uuid, p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + '1 year'::interval))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare v_base jsonb; v_events jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
  v_base:=public.lts_daily_flow_fix86_v19(p_user_id,p_from,p_to);
  with extra as (
    select jsonb_build_object(
      'event_date',s.eligibility_date,
      'account','Corretora',
      'description',case when lower(s.asset_type) like '%cash%' then 'Vesting Cash RSU · disponível em '
                         else 'Vesting RSU · disponível em ' end
                    ||to_char(s.eligibility_date+s.settlement_days,'DD/MM/YYYY'),
      'signed_amount',0,
      'category',case when lower(s.asset_type) like '%cash%' then 'Cash RSU' else 'RSU' end,
      'source','future_award_vesting_marker',
      'source_ref',s.id||':vesting',
      'status','expected',
      'editable',false,
      'non_cash_marker',true,
      'available_date',s.eligibility_date+s.settlement_days
    ) e
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id and s.active=true
      and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
      and s.eligibility_date between p_from and p_to
    union all
    select jsonb_build_object(
      'event_date',s.eligibility_date+s.settlement_days,
      'account','Corretora',
      'description','RSU disponível após liquidação',
      'signed_amount',coalesce(s.gross_value_brl,s.net_value_brl),
      'category','RSU',
      'source','future_rsu_available',
      'source_ref',s.id||':available',
      'status','expected',
      'editable',false,
      'liquidity_layer','D+3',
      'available_from_vesting',true
    ) e
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=p_user_id and s.active=true
      and upper(trim(s.asset_type))='RSU'
      and (s.eligibility_date+s.settlement_days) between p_from and p_to
  ), all_events as (
    select value e from jsonb_array_elements(coalesce(v_base->'events','[]'::jsonb))
    union all select e from extra
  )
  select coalesce(jsonb_agg(e order by e->>'event_date',e->>'source_ref'),'[]'::jsonb)
    into v_events from all_events;
  return jsonb_set(v_base,'{events}',v_events,true)||jsonb_build_object(
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181',
    'award_milestone_contract',jsonb_build_object(
      'vesting_date_visible',true,
      'availability_date_visible',true,
      'vesting_marker_is_non_cash',true,
      'cash_rsu_uses_net_value_on_availability',true
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_awards_v178()'::regprocedure))<>'a1a8de30fc707be6a1d8abb6b7f647b7' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_browser_awards_v178()'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_browser_awards_v178()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); snap public.lts_brokerage_position_snapshots%rowtype; current_position jsonb;
begin
 select * into snap from public.lts_brokerage_position_snapshots where user_id=u and institution='Morgan Stanley' AND as_of_date<=current_date order by as_of_date desc,updated_at desc limit 1;
 select canonical_value into current_position from public.lts_validated_lock_registry where lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;
 if current_position is null or abs((current_position->>'total_available_brl')::numeric-(current_position->>'shares_value_brl')::numeric-(current_position->>'brokerage_cash_brl')::numeric)>0.01 then raise exception 'validated brokerage position incomplete'; end if;
 return jsonb_build_object('version','awards-v180','as_of',current_position->'as_of',
 'vested_shares',current_position->'shares_value_brl','brokerage_cash',current_position->'brokerage_cash_brl',
 'other_available',0,'brokerage_available',current_position->'total_available_brl',
 'other_unavailable',snap.other_unavailable_brl,'basis','validated_current_position',
 'events',coalesce((select jsonb_agg(jsonb_build_object(
 'id',s.id,'type',s.asset_type,'vesting_date',s.eligibility_date,'available_date',s.eligibility_date+coalesce(s.settlement_days,0),
 'value',coalesce(s.net_value_brl,s.gross_value_brl),'regular_rsu',upper(s.asset_type)='RSU','basis',s.source
 ) order by s.eligibility_date,s.id) from public.lts_future_liquidity_effective_v290 s
 where s.user_id=u and s.active and s.eligibility_date>snap.as_of_date),'[]'::jsonb));
end $function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_dashboard_source_key_v240(uuid)'::regprocedure))<>'dcd7429a2487831a4b3a7dcf72963bec' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_dashboard_source_key_v240(uuid)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v250-receipt-age-boundary','date',current_date,
 'cash_position_guard_revision','observed-position-not-reconciled-ledger-v1',
 'operational',public.lts_operational_source_key_v238(p_user_id),
 'fact_confirmations',(select md5(coalesce(string_agg(to_jsonb(f)::text,'|' order by id),'empty')) from public.lts_fact_confirmation f where user_id=p_user_id),
 'bank',public.lts_open_finance_checking_positions_v1(p_user_id),
 'bank_receipt_freshness',(select jsonb_agg(jsonb_build_object('bank',p->>'bank','as_of',p->>'as_of',
  'fresh',(p->>'as_of')::timestamptz BETWEEN current_timestamp-interval '24 hours' AND current_timestamp) order by p->>'bank')
  from jsonb_array_elements(public.lts_open_finance_checking_positions_v1(p_user_id)) p),
 'staging',(select md5(coalesce(string_agg(jsonb_build_array(id,resource_type,raw_hash,normalized_payload,posting_date,signed_amount,provider_deleted_at)::text,'|' order by id),'empty')) from public.lts_open_finance_staging where user_id=p_user_id),
 'decisions',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by source_table,source_ref),'empty')) from public.lts_v178_review_decision d where user_id=p_user_id),
 'assets',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.asset_positions a where user_id=p_user_id),
 'movements',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_liquidity_movement a where user_id=p_user_id),
 'schedule',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_future_liquidity_effective_v290 a where user_id=p_user_id),
 'brokerage',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_brokerage_position_snapshots a where user_id=p_user_id),
 'invoices',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.card_invoices a where user_id=p_user_id),
 'closed_statement_documents',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by d.id),'empty')) from public.source_documents d
  where d.user_id=p_user_id and exists(select 1 from public.card_invoices ci where ci.user_id=p_user_id and ci.metadata->>'bank_statement_document_id'=d.id::text)),
 'locks',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by lock_key),'empty')) from public.lts_validated_lock_registry a where superseded_at is null)
)::text)
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'::regprocedure))<>'7acd9d4a4909cea9cf7a2a3993dc425d' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_dashboard_cash_ladder_from_flow_v229(p_user_id uuid, p_from date, p_to date, p_flow jsonb)
 RETURNS TABLE(flow_date date, operational_cash numeric, d01_resource numeric, balance_after_d01 numeric, rsu_vested_today numeric, rsu_vested_scheduled numeric, balance_no_new_vesting numeric, balance_with_scheduled_vesting numeric, fgts_projected numeric, balance_with_fgts_projected numeric)
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base as (
 select (d->>'date')::date dt,(d#>>'{fix86_columns,saldo_final}')::numeric bank_close,(d#>>'{fix86_columns,liq_d0_1_recurso}')::numeric d01_resource
 from jsonb_array_elements(coalesce(p_flow->'days','[]'::jsonb)) d
), lay as (
 select b.dt flow_date,(select effective_value_brl from public.lts_asset_position_effective_v1(p_user_id,current_date) where asset_type='FGTS' order by documented_as_of desc,asset_position_id desc limit 1) fgts_value,
 coalesce((select sum(case when lower(s.asset_type) like '%cash%' then coalesce(s.net_value_brl,s.gross_value_brl) else coalesce(s.gross_value_brl,s.net_value_brl) end)
  from public.lts_future_liquidity_effective_v290 s where s.user_id=p_user_id and s.active
  and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  and s.eligibility_date+s.settlement_days<=b.dt),0)::numeric vested_rsu_value
 from base b join jsonb_array_elements(p_flow->'days') d on (d->>'date')::date=b.dt
),
params as (
 select (public.lts_open_finance_current_bank_position_v1(p_user_id)->>'bank_cash')::numeric bank_anchor,
 public.lts_cofrinho_effective_locked_v245(p_user_id,current_date) d0_anchor,
 coalesce((select (canonical_value->>'total_available_brl')::numeric from public.lts_validated_lock_registry where lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1),0) rsu_anchor
), anchor as (
 select (select bank_anchor from params)-coalesce((select bank_close from base where dt=current_date),(select bank_anchor from params)) bank_delta,
 (select d0_anchor from params)-coalesce((select d01_resource from base where dt=current_date),(select d0_anchor from params)) d0_delta,
 (select rsu_anchor from params)-coalesce((select vested_rsu_value from lay where flow_date=current_date),(select rsu_anchor from params)) rsu_delta
)
select b.dt,b.bank_close+a.bank_delta,b.d01_resource+a.d0_delta,b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta,
p.rsu_anchor,l.vested_rsu_value+a.rsu_delta,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+p.rsu_anchor,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta,
l.fgts_value,
b.bank_close+a.bank_delta+b.d01_resource+a.d0_delta+l.vested_rsu_value+a.rsu_delta+l.fgts_value
from base b join lay l on l.flow_date=b.dt cross join params p cross join anchor a order by b.dt
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_wealth_detail_v4()'::regprocedure))<>'291789e656ab1f3f3c85eec45a70d170' THEN RAISE EXCEPTION 'V290 award reader source changed: public.lts_browser_wealth_detail_v4()'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v4()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_base jsonb;
  v_snapshot public.lts_brokerage_position_snapshots%rowtype;
  v_summary jsonb;
  v_cash_net numeric;
  v_reserve numeric;
  v_future_net numeric;
  v_total_net numeric;
  v_schedule_cash_gross numeric;
begin
  v_base:=public.lts_browser_wealth_detail_v3();
  v_summary:=coalesce(v_base->'rsu_summary','{}'::jsonb);

  select * into v_snapshot
  from public.lts_brokerage_position_snapshots
  where user_id=v_uid and institution='Morgan Stanley' AND as_of_date<=current_date
  order by as_of_date desc,updated_at desc
  limit 1;

  if not found then
    return v_base||jsonb_build_object('version','wealth-detail-v6-v180-no-brokerage-snapshot');
  end if;

  v_cash_net:=round(v_snapshot.future_cash_rsu_gross_brl*0.70,2);
  v_reserve:=v_snapshot.future_cash_rsu_gross_brl-v_cash_net;
  v_future_net:=v_snapshot.future_rsu_gross_brl
    +v_cash_net
    +v_snapshot.other_unavailable_brl;
  v_total_net:=v_snapshot.available_total_brl+v_future_net;

  select coalesce(sum(gross_value_brl) filter(where lower(asset_type) like '%cash%'),0)
    into v_schedule_cash_gross
  from public.lts_future_liquidity_effective_v290
  where user_id=v_uid and active;

  v_summary:=v_summary||jsonb_build_object(
    'as_of',v_snapshot.as_of_date,
    'vested_shares_brl',v_snapshot.vested_shares_available_brl,
    'brokerage_cash_brl',v_snapshot.brokerage_cash_available_brl,
    'other_available_brl',v_snapshot.other_available_brl,
    'available_total_brl',v_snapshot.available_total_brl,
    'statement_total_gross_brl',v_snapshot.total_gross_brl,
    'statement_unavailable_gross_brl',v_snapshot.unavailable_total_brl,
    'other_unavailable_brl',v_snapshot.other_unavailable_brl
  );

  return v_base||jsonb_build_object(
    'version','wealth-detail-v6-v180-morgan-reconciled',
    'rsu_summary',v_summary,
    'morgan_statement',jsonb_build_object(
      'institution',v_snapshot.institution,
      'as_of',v_snapshot.as_of_date,
      'source_label',v_snapshot.source_label,
      'statement_component_rounding_delta_brl',v_snapshot.metadata->'statement_component_rounding_delta_brl',
      'evidence_sha256',v_snapshot.metadata->'evidence_sha256',
      'gross_total_brl',v_snapshot.total_gross_brl,
      'available_total_brl',v_snapshot.available_total_brl,
      'unavailable_gross_brl',v_snapshot.unavailable_total_brl,
      'available_components',jsonb_build_object(
        'vested_shares_brl',v_snapshot.vested_shares_available_brl,
        'brokerage_cash_brl',v_snapshot.brokerage_cash_available_brl,
        'unallocated_statement_brl',v_snapshot.other_available_brl
      ),
      'future_components',jsonb_build_object(
        'regular_rsu_gross_brl',v_snapshot.future_rsu_gross_brl,
        'cash_rsu_gross_brl',v_snapshot.future_cash_rsu_gross_brl,
        'unallocated_statement_brl',v_snapshot.other_unavailable_brl,
        'cash_rsu_after_reserve_brl',v_cash_net,
        'cash_rsu_reserve_brl',v_reserve,
        'future_after_reserve_brl',v_future_net
      ),
      'considered_total_after_reserve_brl',v_total_net,
      'reserve_rate',0.30,
      'quantities',jsonb_build_object(
        'vested_shares',v_snapshot.vested_share_quantity,
        'future_regular_rsu',v_snapshot.future_rsu_quantity,
        'future_cash_rsu',v_snapshot.future_cash_rsu_quantity
      ),
      'planning_schedule_reconciliation',jsonb_build_object(
        'schedule_regular_gross_brl',nullif(v_summary->>'future_regular_brl','')::numeric,
        'statement_regular_gross_brl',v_snapshot.future_rsu_gross_brl,
        'regular_delta_brl',coalesce(nullif(v_summary->>'future_regular_brl','')::numeric,0)-v_snapshot.future_rsu_gross_brl,
        'schedule_cash_gross_brl',v_schedule_cash_gross,
        'statement_cash_gross_brl',v_snapshot.future_cash_rsu_gross_brl,
        'cash_delta_brl',v_schedule_cash_gross-v_snapshot.future_cash_rsu_gross_brl,
        'unallocated_statement_brl',v_snapshot.other_unavailable_brl,
        'status','statement_and_assumption_model_kept_separate'
      ),
      'guardrail','Os totais brutos seguem a tela da corretora. Componentes não visíveis permanecem não alocados; não são tratados como arredondamento nem recebem natureza presumida. A visão após reserva é planejamento, não apuração fiscal nem um segundo saldo.'
    )
  );
end
$function$;
DO $lease$ BEGIN IF md5(pg_get_functiondef('lts_award_private.provenance_v183()'::regprocedure))<>'30108433352c5eeaf7d2bbd46b9594ce' THEN RAISE EXCEPTION 'V290 award reader source changed: lts_award_private.provenance_v183()'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION lts_award_private.provenance_v183()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  u uuid := public.lts_browser_assert_user_v1();
  groups jsonb;
begin
  with source_rows as (
    select s.*,
      case when lower(s.asset_type) like '%cash%' then 'cash_rsu' else 'rsu' end as kind,
      case when lower(s.asset_type) like '%cash%' then s.net_value_brl else s.gross_value_brl end as considered,
      case when s.metadata->>'valuation_basis'='automatic_market_reference' then 'market_reference'
           when nullif(s.metadata->>'manual_assumption_at','') is not null then 'manual'
           when s.source='liquidez_ativo' then 'historical_assumption' else 'unverified_assumption' end as provenance
    from public.lts_future_liquidity_effective_v290 s
    where s.user_id=u and s.active
      and (upper(trim(s.asset_type))='RSU' or lower(s.asset_type) like '%cash%')
  ), grouped as (
    select kind, eligibility_date,
      sum(quantity) as quantity, sum(gross_value_brl) as gross,
      case when count(considered)=count(*) then sum(considered) end as considered,
      jsonb_agg(jsonb_build_object(
        'quantity',quantity,'unit_price_usd',unit_price_assumption,'fx_rate',fx_assumption,
        'gross_value_brl',gross_value_brl,'considered_value_brl',considered,
        'calculated_gross_brl',round(quantity*unit_price_assumption*fx_assumption,2),
        'calculation_delta_brl',gross_value_brl-round(quantity*unit_price_assumption*fx_assumption,2),
        'provenance',provenance,'market_quotes',metadata->'market_quotes','market_quote_as_of',metadata#>>'{market_quotes,stock,quoted_at}',
        'assumption_recorded_at',nullif(metadata->>'manual_assumption_at',''),
        'source_updated_at',coalesce(nullif(metadata->>'legacy_updated_at',''),updated_at::text),
        'source',source,'settlement_days',settlement_days,
        'availability_basis','recorded_calendar_day_assumption'
      ) order by id) as components
    from source_rows group by kind,eligibility_date
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'group_key',kind||':'||eligibility_date::text,'asset_type',kind,
    'eligibility_date',eligibility_date,'quantity',quantity,
    'gross_value_brl',gross,'considered_value_brl',considered,'components',components
  ) order by eligibility_date,kind),'[]'::jsonb) into groups from grouped;
  return jsonb_build_object('version','award-provenance-v183','financial_effect','none',
    'read_at',now(),'groups',groups,'market_feed',true);
end $function$;
SELECT cron.schedule('lts_market_quotes_hourly_v290','7 * * * *','select public.lts_market_request_quotes_v290()');
SELECT cron.schedule('lts_market_quotes_collect_v290','8,9,10 * * * *','select public.lts_market_collect_quotes_v290()');

