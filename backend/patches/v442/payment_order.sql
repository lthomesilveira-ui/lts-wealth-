-- A provider may reorder payments. Retain every reviewed identity and field.
CREATE OR REPLACE FUNCTION public.lts_invoice_payment_order_equal_v442(p_invoice jsonb,p_contract jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
WITH p AS(SELECT CASE WHEN jsonb_typeof(p_invoice->'raw_payload')='object' THEN p_invoice->'raw_payload' END actual,
 CASE WHEN jsonb_typeof(p_contract->'invoice_canonical_payload')='object' THEN p_contract->'invoice_canonical_payload' END expected,p_contract->'issuer_payments' reviewed),
a AS(SELECT label,j FROM p CROSS JOIN LATERAL(VALUES('actual',actual->'payments'),('expected',expected->'payments'),('reviewed',reviewed))v(label,j)),
n AS(SELECT label,jsonb_agg(x ORDER BY x::text) normalized,
 count(*)=count(DISTINCT x->>'id') AND bool_and(jsonb_typeof(x)='object' AND nullif(x->>'id','')IS NOT NULL) valid
 FROM a CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(j)='array' THEN j ELSE '[]'::jsonb END)x GROUP BY label)
SELECT coalesce(jsonb_typeof(actual)='object' AND jsonb_typeof(expected)='object'
 AND (actual-'updatedAt'-'payments')=(expected-'payments')
 AND (SELECT count(*)=3 AND bool_and(CASE WHEN jsonb_typeof(j)='array' THEN jsonb_array_length(j)>0 ELSE false END) FROM a)
 AND (SELECT count(*)=3 AND bool_and(valid) AND count(DISTINCT normalized)=1 FROM n),false) FROM p
$function$;
REVOKE ALL ON FUNCTION public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)TO service_role;
