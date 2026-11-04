"""Build a synthetic schema from the V290 functions already published in this repo."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
print("""
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon')THEN CREATE ROLE anon;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated')THEN CREATE ROLE authenticated;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role')THEN CREATE ROLE service_role;END IF;
END $roles$;
CREATE SCHEMA net;
CREATE UNLOGGED SEQUENCE net.http_request_queue_id_seq;
CREATE UNLOGGED TABLE net.http_request_queue(
 id bigint NOT NULL DEFAULT nextval('net.http_request_queue_id_seq'),
 method text NOT NULL,url text NOT NULL,headers jsonb NOT NULL,body bytea,
 timeout_milliseconds integer NOT NULL
);
CREATE UNLOGGED TABLE net._http_response(
 id bigint,status_code integer,content_type text,headers jsonb,content text,
 timed_out boolean,error_msg text,created timestamptz NOT NULL DEFAULT now()
);
-- An isolated transport fixture: no HTTP connection or financial data is used.
CREATE FUNCTION net.http_get(url text,params jsonb DEFAULT '{}',headers jsonb DEFAULT '{}',
 timeout_milliseconds integer DEFAULT 2000)RETURNS bigint LANGUAGE sql AS $f$
 INSERT INTO net.http_request_queue(method,url,headers,timeout_milliseconds)
 VALUES('GET',$1,$3,$4)RETURNING id;
$f$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,41);
""")
source = (ROOT / 'backend/patches/v290/automatic_market_quotes.sql').read_text()
print(source.split('CREATE OR REPLACE FUNCTION public.lts_market_parse_v290')[0])
predecessors = {
    'lts_market_parse_v290': 'market_identity_guards.sql',
    'lts_market_request_quotes_v290': 'market_validation_guards.sql',
    'lts_market_collect_quotes_v290': 'automatic_market_quotes.sql',
}
for name, filename in predecessors.items():
    published = (ROOT / 'backend/patches/v290' / filename).read_text()
    pattern = r'CREATE OR REPLACE FUNCTION public\.' + re.escape(name) + r'\([^;]*?AS \$f\$[\s\S]+?\$f\$;'
    matches = re.findall(pattern, published)
    if len(matches) != 1:
        raise ValueError(f'Expected exactly one published predecessor: {name}')
    print(matches[0])
print("""
REVOKE ALL ON FUNCTION public.lts_market_parse_v290(text,jsonb,timestamptz),
 public.lts_market_request_quotes_v290(),public.lts_market_collect_quotes_v290()
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_parse_v290(text,jsonb,timestamptz),
 public.lts_market_request_quotes_v290(),public.lts_market_collect_quotes_v290() TO service_role;
CREATE TABLE public.qa_result_v405(name text PRIMARY KEY);
CREATE TABLE public.qa_call_v405(name text PRIMARY KEY,result jsonb NOT NULL);
CREATE FUNCTION public.qa_assert_v405(p_name text,p_pass boolean)RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
 IF NOT coalesce(p_pass,false)THEN RAISE EXCEPTION 'FAIL: %',p_name;END IF;
 INSERT INTO public.qa_result_v405 VALUES(p_name);
END $f$;
CREATE TABLE public.qa_clock_v405 AS SELECT clock_timestamp()-interval '1 minute' quoted_at;
CREATE FUNCTION public.qa_body_v405(p_symbol text,p_value numeric)RETURNS jsonb LANGUAGE sql AS $f$
 SELECT CASE WHEN p_symbol='OGN' THEN jsonb_build_object('chart',jsonb_build_object('error',NULL,
  'result',jsonb_build_array(jsonb_build_object('meta',jsonb_build_object(
   'symbol','OGN','currency','USD','instrumentType','EQUITY','exchangeTimezoneName','America/New_York',
   'exchangeName','NYQ','regularMarketPrice',p_value,'regularMarketTime',extract(epoch from quoted_at)::bigint,
   'currentTradingPeriod',jsonb_build_object('regular',jsonb_build_object(
    'start',extract(epoch from quoted_at-interval '1 hour')::bigint,
    'end',extract(epoch from quoted_at+interval '1 hour')::bigint)))))))
 ELSE jsonb_build_object('value',jsonb_build_array(jsonb_build_object('cotacaoVenda',p_value,
  'cotacaoCompra',p_value-0.01,'dataHoraCotacao',to_char(quoted_at AT TIME ZONE 'America/Sao_Paulo','YYYY-MM-DD HH24:MI:SS'))))END
 FROM public.qa_clock_v405;
$f$;
INSERT INTO public.lts_market_request_v290(request_id,symbol,requested_at,processed_at,error_code) VALUES
 (1,'USD/BRL',pg_postmaster_start_time()-interval '1 day',NULL,NULL),
 (2,'OGN',pg_postmaster_start_time()-interval '1 day',pg_postmaster_start_time()-interval '23 hours',NULL),
 (5,'OGN',pg_postmaster_start_time()-interval '2 days',pg_postmaster_start_time()-interval '47 hours','source_unavailable'),
 (9,'USD/BRL',pg_postmaster_start_time()-interval '2 days',pg_postmaster_start_time()-interval '47 hours',NULL),
 (50,'OGN',clock_timestamp(),clock_timestamp(),NULL);
CREATE TABLE public.qa_history_v405 AS SELECT * FROM public.lts_market_request_v290;
INSERT INTO public.lts_market_quote_v290(symbol,value,currency,quoted_at,source_name,source_url,market_state,received_at)
 VALUES('OGN',41,'USD',clock_timestamp()-interval '1 day','Yahoo Finance · NYSE',
  'https://finance.yahoo.com/quote/OGN/','closed',clock_timestamp()-interval '1 day'),
 ('USD/BRL',5,'BRL',clock_timestamp()-interval '1 day','Banco Central · PTAX venda',
  'https://ptax.bcb.gov.br/ptax_internet/consultarUltimaCotacaoDolar.do','daily_reference',clock_timestamp()-interval '1 day');
INSERT INTO public.lts_market_head_v290 SELECT symbol,id FROM public.lts_market_quote_v290;
CREATE TABLE public.qa_quotes_before_v405 AS SELECT * FROM public.lts_market_quote_v290;
DO $test$
DECLARE duplicate_reproduced boolean:=false;
BEGIN
 BEGIN PERFORM public.lts_market_request_quotes_v290();
 EXCEPTION WHEN unique_violation THEN duplicate_reproduced:=true;END;
 PERFORM public.qa_assert_v405('original_writer_reproduces_recycled_id_failure',duplicate_reproduced);
END $test$;
""")
