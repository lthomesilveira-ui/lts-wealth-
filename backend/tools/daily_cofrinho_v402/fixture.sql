-- Synthetic identities, products and amounts only.
SET TIME ZONE 'America/Sao_Paulo';
CREATE TABLE public.lts_open_finance_resource_map(
 id bigserial PRIMARY KEY,user_id uuid,provider text,item_id text,resource_type text,
 provider_resource_id text,local_target text,reconciliation_status text,fingerprint text,metadata jsonb
);
CREATE TABLE public.lts_open_finance_sync_run(
 id uuid PRIMARY KEY,user_id uuid,connection_id uuid,status text,started_at timestamptz,finished_at timestamptz
);
CREATE INDEX ON public.lts_open_finance_sync_run(user_id,started_at DESC);
CREATE TABLE public.lts_open_finance_observation(
 id uuid PRIMARY KEY,user_id uuid,connection_id uuid,sync_run_id uuid,resource_type text,
 provider_record_id text,raw_hash text,raw_payload jsonb,normalized_payload jsonb,observed_at timestamptz
);
CREATE UNIQUE INDEX ON public.lts_open_finance_observation(sync_run_id,resource_type,provider_record_id);
INSERT INTO public.lts_open_finance_resource_map(user_id,provider,item_id,resource_type,provider_resource_id,local_target,reconciliation_status,fingerprint,metadata)
VALUES('11111111-1111-4111-8111-111111111111','pluggy','synthetic-item','investment','component-a','itau_cofrinhos','verified','SYNTHETIC-A','{"itau_cofrinhos_total":1000,"component_net_valuation":300}'),
('11111111-1111-4111-8111-111111111111','pluggy','synthetic-item','investment','component-b','itau_cofrinhos','verified','SYNTHETIC-B','{"itau_cofrinhos_total":1000,"component_net_valuation":700}');
INSERT INTO public.asset_positions VALUES(
 '44444444-4444-4444-8444-444444444450','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2019-12-31',1000,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20191231"}'),(
 '44444444-4444-4444-8444-444444444451','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2020-01-05',740,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20200105"}');
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value)VALUES
 ('itau_cofrinho_fixture_20191231','{"as_of":"2019-12-31","amount":1000}'),
 ('itau_cofrinho_fixture_20200105','{"as_of":"2020-01-05","amount":740}');

CREATE FUNCTION public.qa_cohort_v402(p_date date,p_a numeric,p_b numeric)
RETURNS void LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';c uuid:='33333333-3333-4333-8333-333333333333';r uuid:=md5(p_date::text)::uuid;x record;
BEGIN
 INSERT INTO public.lts_open_finance_sync_run VALUES(r,u,c,'success',p_date::timestamp+interval '17 hours',p_date::timestamp+interval '17 hours 1 minute');
 FOR x IN SELECT * FROM(VALUES('a',p_a),('b',p_b))v(part,amount) LOOP
  INSERT INTO public.lts_open_finance_observation VALUES(md5(p_date::text||x.part)::uuid,u,c,r,'investment','synthetic-item:component-'||x.part,md5(p_date::text||x.part),
   jsonb_build_object('id','component-'||x.part,'itemId','synthetic-item','code','SYNTHETIC-'||upper(x.part),
    'date',(p_date+3)::text||'T00:00:00Z','currencyCode','BRL','status','ACTIVE','balance',x.amount,
    'amount',x.amount+5,'taxes',5,'updatedAt',p_date::text||'T18:00:00Z'),
   jsonb_build_object('amount_semantics','net_valuation','net_valuation',x.amount),p_date::timestamp+interval '17 hours');
 END LOOP;
END $function$;
SELECT public.qa_cohort_v402('2020-01-01',300,700);
SELECT public.qa_cohort_v402('2020-01-02',305,705);
SELECT public.qa_cohort_v402('2020-01-03',200,520);
SELECT public.qa_cohort_v402('2020-01-04',205,520);
SELECT public.qa_cohort_v402('2020-01-05',210,520);
SELECT public.qa_cohort_v402('2020-01-06',220,540);

SELECT public.qa_receipt('55555555-5555-4555-8555-555555555560','2020-01-02',100);
UPDATE public.lts_open_finance_staging SET occurred_at='2020-01-02T19:00:00Z' WHERE id='55555555-5555-4555-8555-555555555560';
SELECT public.qa_receipt('55555555-5555-4555-8555-555555555561','2020-01-03',200);
UPDATE public.lts_open_finance_staging SET occurred_at='2020-01-03T17:00:00Z' WHERE id='55555555-5555-4555-8555-555555555561';
INSERT INTO public.lts_liquidity_movement VALUES(
 '66666666-6666-4666-8666-666666666660','11111111-1111-4111-8111-111111111111','44444444-4444-4444-8444-444444444450',NULL,'2020-01-02','active','redemption',100,-100,
 '{"bank_staging_id":"55555555-5555-4555-8555-555555555560"}');

CREATE FUNCTION public.lts_current_evidence_position_v2(p_user_id uuid)RETURNS jsonb LANGUAGE sql STABLE AS $function$
with b as (select public.lts_open_finance_current_bank_position_v1(p_user_id) j), c as (select (canonical_value->>'amount')::numeric v from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null)
select jsonb_build_object('as_of',current_date,'bank_cash',(b.j->>'bank_cash')::numeric,
'assets',jsonb_build_array(jsonb_build_object('name','Cofrinho Itaú','type','cash_investment','as_of',current_date,'value_brl',c.v)),
'liquid_d0_assets',c.v,'liquidity_now_d0',(b.j->>'bank_cash')::numeric+c.v,'restricted_assets',500)
from b,c;
$function$;
CREATE TABLE public.qa_protected_v402 AS SELECT jsonb_build_object(
 'assets',(SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.asset_positions a),
 'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.financial_events e),
 'movements',(SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM public.lts_liquidity_movement m),
 'mapping',(SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM public.lts_open_finance_resource_map m),
 'observations',(SELECT jsonb_agg(to_jsonb(o) ORDER BY id) FROM public.lts_open_finance_observation o)) AS data;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO service_role;
