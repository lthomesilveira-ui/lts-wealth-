-- A received reference with an unknown position date is not a dated valuation.
CREATE TABLE public.lts_brokerage_reference_v352(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 institution text NOT NULL,
 received_on date NOT NULL,
 position_as_of date,
 total_gross_brl numeric(18,2) NOT NULL CHECK(total_gross_brl>=0),
 available_total_brl numeric(18,2) NOT NULL CHECK(available_total_brl>=0),
 unavailable_total_brl numeric(18,2) NOT NULL CHECK(unavailable_total_brl>=0),
 source_file text NOT NULL CHECK(length(source_file)>0),
 source_sha256 text NOT NULL CHECK(source_sha256 ~ '^[0-9a-f]{64}$'),
 metadata jsonb NOT NULL CHECK(jsonb_typeof(metadata)='object'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,institution,source_sha256),
 CHECK(position_as_of IS NULL OR position_as_of<=received_on),
 CHECK(total_gross_brl=available_total_brl+unavailable_total_brl)
);
COMMENT ON TABLE public.lts_brokerage_reference_v352 IS 'Documentary references only. Not used for cash, income, expenditure, dated positions or projected vesting valuation.';
ALTER TABLE public.lts_brokerage_reference_v352 ENABLE ROW LEVEL SECURITY;
CREATE POLICY brokerage_reference_owner_read ON public.lts_brokerage_reference_v352 FOR SELECT TO authenticated USING(user_id=auth.uid());
REVOKE ALL ON public.lts_brokerage_reference_v352 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_brokerage_reference_v352 TO authenticated;
GRANT ALL ON public.lts_brokerage_reference_v352 TO service_role;

CREATE FUNCTION public.lts_brokerage_reference_v352(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT jsonb_build_object('institution',r.institution,'received_on',r.received_on,
 'position_as_of',r.position_as_of,'position_date_status',CASE WHEN r.position_as_of IS NULL THEN 'not_visible'ELSE 'documented'END,
 'total_gross_brl',r.total_gross_brl,'available_total_brl',r.available_total_brl,'unavailable_total_brl',r.unavailable_total_brl,
 'source_file',r.source_file,'source_sha256',r.source_sha256,'metadata',r.metadata,
 'status','documentary_reference_pending_reconciliation','included_in_current_liquidity',false,
 'included_in_current_valuation',false,'cash_effect','none')
 FROM public.lts_brokerage_reference_v352 r WHERE r.user_id=p_user_id AND r.received_on<=current_date
 ORDER BY r.received_on DESC,r.created_at DESC,r.id DESC LIMIT 1
$fn$;
REVOKE ALL ON FUNCTION public.lts_brokerage_reference_v352(uuid)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_brokerage_reference_v352(uuid)TO service_role;

-- Preserve the current owner boundary and the entire existing financial reader.
DO $patch$
DECLARE d text;a jsonb;t regprocedure:='public.lts_browser_wealth_detail_v242()'::regprocedure;
 old text:='j||jsonb_build_object(''reader_revision'',''v242-settled-resource-transfers'')';
 new text:='j||jsonb_build_object(''brokerage_reference'',public.lts_brokerage_reference_v352(u),''reader_revision'',''v242-settled-resource-transfers'')';
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO d,a FROM pg_proc p WHERE oid=t;
 IF md5(d)<>'769a6cf3621b8dfb422acf23384827d4'OR position(old IN d)=0 THEN RAISE EXCEPTION 'V352_WEALTH_SOURCE_CHANGED';END IF;
 EXECUTE replace(d,old,new);
 IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=t)THEN RAISE EXCEPTION 'V352_WEALTH_ATTRIBUTES_CHANGED';END IF;
END $patch$;
