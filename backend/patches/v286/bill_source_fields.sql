-- Pure input validation. This helper never reads or writes financial relations.
CREATE OR REPLACE FUNCTION public.lts_bill_source_fields_v286(p_normalized jsonb,p_raw jsonb,p_fallback_due date)
RETURNS TABLE(header_valid boolean,due_date date,closing_date date,source_updated_at timestamptz,payments_valid boolean,reason text)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO ''
SET "TimeZone" TO 'UTC'
SET "DateStyle" TO 'ISO, YMD'
AS $function$
DECLARE due_text text; close_text text; source_text text; payment jsonb; payment_date text;
 stamp_pattern constant text:='^[0-9]{4}-[0-9]{2}-[0-9]{2}T(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,6})?(Z|[+-](0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$';
BEGIN
 header_valid:=false;payments_valid:=false;reason:='invalid_payload_shape';
 IF jsonb_typeof(p_normalized) IS DISTINCT FROM 'object' OR jsonb_typeof(p_raw) IS DISTINCT FROM 'object' THEN RETURN NEXT;RETURN;END IF;
 reason:='warnings_not_clear';
 IF p_normalized ? 'warnings' THEN
  IF jsonb_typeof(p_normalized->'warnings') IS DISTINCT FROM 'array' THEN RETURN NEXT;RETURN;END IF;
  IF jsonb_array_length(p_normalized->'warnings')<>0 THEN RETURN NEXT;RETURN;END IF;
 END IF;
 due_text:=p_normalized->>'due_date';close_text:=p_normalized->>'closing_date';
 reason:='invalid_due_date';
 IF due_text IS NOT NULL THEN
  IF jsonb_typeof(p_normalized->'due_date') IS DISTINCT FROM 'string' OR due_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RETURN NEXT;RETURN;END IF;
  IF NOT pg_catalog.pg_input_is_valid(due_text,'date') THEN RETURN NEXT;RETURN;END IF;
  due_date:=due_text::date;
 ELSE
  IF p_fallback_due IS NULL OR NOT pg_catalog.isfinite(p_fallback_due) THEN RETURN NEXT;RETURN;END IF;
  due_date:=p_fallback_due;
 END IF;
 reason:='invalid_closing_date';
 IF close_text IS NOT NULL THEN
  IF jsonb_typeof(p_normalized->'closing_date') IS DISTINCT FROM 'string' OR close_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RETURN NEXT;RETURN;END IF;
  IF NOT pg_catalog.pg_input_is_valid(close_text,'date') THEN RETURN NEXT;RETURN;END IF;
  closing_date:=close_text::date;
 END IF;
 -- A collection timestamp is not an issuer revision and cannot replace one.
 source_text:=coalesce(p_normalized->>'provider_updated_at',p_raw->>'updatedAt');
 reason:='invalid_or_missing_issuer_revision';
 IF source_text IS NULL OR source_text !~ stamp_pattern THEN RETURN NEXT;RETURN;END IF;
 IF NOT pg_catalog.pg_input_is_valid(source_text,'timestamptz') THEN RETURN NEXT;RETURN;END IF;
 source_updated_at:=source_text::timestamptz;
 header_valid:=true;reason:=NULL;
 payments_valid:=jsonb_typeof(p_raw->'payments')='array';
 IF payments_valid IS NOT TRUE THEN payments_valid:=false;RETURN NEXT;RETURN;END IF;
 FOR payment IN SELECT value FROM jsonb_array_elements(p_raw->'payments') LOOP
  IF jsonb_typeof(payment) IS DISTINCT FROM 'object'
   OR jsonb_typeof(payment->'id') IS DISTINCT FROM 'string' OR nullif(payment->>'id','') IS NULL
   OR coalesce(payment->>'currencyCode','')<>'BRL'
   OR coalesce(payment->>'valueType','') NOT IN('FULL_PAYMENT','PARTIAL_PAYMENT','MINIMUM_PAYMENT','OTHER','OTHER_PAYMENT')
   OR coalesce(payment->>'amount','') !~ '^[0-9]+([.][0-9]+)?$'
   OR jsonb_typeof(payment->'paymentDate') IS DISTINCT FROM 'string'
  THEN payments_valid:=false;CONTINUE;END IF;
  payment_date:=payment->>'paymentDate';
  IF payment_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND payment_date !~ stamp_pattern THEN payments_valid:=false;CONTINUE;END IF;
  IF NOT pg_catalog.pg_input_is_valid(left(payment_date,10),'date') THEN payments_valid:=false;CONTINUE;END IF;
  IF length(payment_date)>10 AND NOT pg_catalog.pg_input_is_valid(payment_date,'timestamptz') THEN payments_valid:=false;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_raw->'payments')p GROUP BY p->>'id' HAVING count(DISTINCT p)>1)
 THEN payments_valid:=false;END IF;
 RETURN NEXT;
END $function$;

REVOKE ALL ON FUNCTION public.lts_bill_source_fields_v286(jsonb,jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bill_source_fields_v286(jsonb,jsonb,date) TO service_role;
