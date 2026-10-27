-- Pure transformation of already owner-scoped, strongly identified contracts.
-- A documented chain may bridge a three-hour provider clock change. Ambiguous
-- chains retain their original identity and all original financial attributes.
CREATE OR REPLACE FUNCTION public.lts_c6_contract_clock_rows_v349(p_rows jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
WITH tagged AS MATERIALIZED(
 SELECT r, r->>'contract_key' old_key,
 jsonb_set((r->>'contract_key')::jsonb,'{3}',to_jsonb(r->>'purchase_date'))::text civil_key,
 (((r->>'contract_key')::jsonb)->>3)::timestamptz purchase_instant
 FROM jsonb_array_elements(coalesce(p_rows,'[]'::jsonb))r
), blocks AS(
 SELECT civil_key,old_key,count(*) n FROM tagged GROUP BY civil_key,old_key
), proved AS(
 SELECT civil_key FROM tagged GROUP BY civil_key
 HAVING bool_or(r->>'provider_status'='DOCUMENTED')
 AND count(DISTINCT old_key)=2
 AND max(purchase_instant)-min(purchase_instant)=interval '3 hours'
 AND bool_and(r->>'purchase_date'=((purchase_instant AT TIME ZONE 'America/Sao_Paulo')::date)::text)
 AND count(*)=count(DISTINCT r->>'installment_number')
 AND count(DISTINCT r->>'cycle_offset')=1
 AND max((r->>'amount')::numeric)-min((r->>'amount')::numeric)<=0.15
 AND (SELECT min(n) FROM blocks b WHERE b.civil_key=tagged.civil_key)>=2
)
SELECT coalesce(jsonb_agg(CASE WHEN p.civil_key IS NULL THEN t.r
 ELSE jsonb_set(t.r,'{contract_key}',to_jsonb(t.civil_key))END ORDER BY t.r->>'source_id'),'[]'::jsonb)
FROM tagged t LEFT JOIN proved p USING(civil_key)
$fn$;
REVOKE ALL ON FUNCTION public.lts_c6_contract_clock_rows_v349(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_contract_clock_rows_v349(jsonb) TO service_role;

DO $patch$
DECLARE target regprocedure:='public.lts_card_cycles_v226(uuid)'::regprocedure;
 old_def text;next_def text;attrs jsonb;
 old_a text:='c6_contract_rows AS MATERIALIZED (';
 new_a text:='c6_contract_rows_raw_v349 AS MATERIALIZED (';
 old_b text:='), c6_contract_validity AS MATERIALIZED (';
 new_b text:=$slot$), c6_contract_rows AS MATERIALIZED (
 SELECT r.* FROM jsonb_to_recordset(public.lts_c6_contract_clock_rows_v349(
 (SELECT coalesce(jsonb_agg(to_jsonb(raw)),'[]'::jsonb) FROM c6_contract_rows_raw_v349 raw)))r(
 source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,
 posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,
 amount numeric,description text,category text,category_basis text,installment_number integer,
 total_installments integer,is_payment boolean,bill_id text,observed_at timestamptz,
 contract_key text,cycle_offset integer)
), c6_contract_validity AS MATERIALIZED ($slot$;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc' INTO old_def,attrs FROM pg_proc p WHERE oid=target;
 IF position('c6_contract_rows_raw_v349'IN old_def)>0 THEN
  IF md5(replace(replace(old_def,new_a,old_a),new_b,old_b))<>'ec074a664f6aa8ee1a46b0990ce860b1'
  THEN RAISE EXCEPTION 'V349_REPLAY_SOURCE_CHANGED';END IF;RETURN;
 END IF;
 IF md5(old_def)<>'ec074a664f6aa8ee1a46b0990ce860b1' THEN RAISE EXCEPTION 'V349_CYCLES_SOURCE_LEASE_CHANGED';END IF;
 next_def:=replace(replace(old_def,old_a,new_a),old_b,new_b);
 IF next_def=old_def OR position('lts_c6_contract_clock_rows_v349'IN next_def)=0
 THEN RAISE EXCEPTION 'V349_CYCLES_SLOT_MISSING';END IF;
 EXECUTE next_def;
 IF attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)
 THEN RAISE EXCEPTION 'V349_CYCLES_ATTRIBUTES_CHANGED';END IF;
END $patch$;
