-- Negative original transfer values require original per-bank cash evidence.
-- This changes transfer identity only; the effective cash signs already agree.
CREATE TABLE IF NOT EXISTS public.lts_workbook_transfer_reversal_v338 (
 user_id uuid NOT NULL,legacy_index integer NOT NULL,source_payload jsonb NOT NULL,
 workbook_sha256 text NOT NULL CHECK(workbook_sha256 ~ '^[0-9a-f]{64}$'),
 workbook_sheet text NOT NULL,workbook_row integer NOT NULL CHECK(workbook_row>0),
 workbook_through date NOT NULL,document_date date NOT NULL,
 document_description text NOT NULL,document_amount numeric NOT NULL CHECK(document_amount<0),
 document_category text NOT NULL CHECK(document_category='Transferência Bancária'),
 origin_bank text NOT NULL CHECK(origin_bank IN ('Itaú','Bradesco','C6')),
 destination_bank text NOT NULL CHECK(destination_bank IN ('Itaú','Bradesco','C6')),
 leg_direction text NOT NULL CHECK(leg_direction IN ('entrada','saida')),
 flow_sheet text NOT NULL CHECK(flow_sheet='Fluxo de Caixa'),
 flow_date_cell text NOT NULL CHECK(flow_date_cell ~ '^[A-Z]+3$'),
 flow_value_cell text NOT NULL CHECK(flow_value_cell ~ '^[A-Z]+[1-9][0-9]*$'),
 flow_date date NOT NULL,flow_value numeric NOT NULL,
 flow_opening numeric NOT NULL,flow_entries numeric NOT NULL,
 flow_exits numeric NOT NULL,flow_closing numeric NOT NULL,flow_other_component numeric NOT NULL,
 PRIMARY KEY(user_id,legacy_index),
 CHECK(origin_bank<>destination_bank),CHECK(document_date<=workbook_through),
 CHECK(flow_date=document_date AND flow_value=document_amount),
 CHECK(regexp_replace(flow_date_cell,'[0-9]','','g')=regexp_replace(flow_value_cell,'[0-9]','','g')),
 CHECK(abs(flow_opening+flow_entries-flow_exits-flow_closing)<=0.021),
 CHECK(abs(flow_other_component+flow_value-CASE leg_direction WHEN 'entrada' THEN flow_entries ELSE flow_exits END)<=0.021)
);
ALTER TABLE public.lts_workbook_transfer_reversal_v338 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_workbook_transfer_reversal_v338 FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.lts_workbook_transfer_reversal_v338 TO service_role;
DROP POLICY IF EXISTS service_workbook_reversal_v338 ON public.lts_workbook_transfer_reversal_v338;
CREATE POLICY service_workbook_reversal_v338 ON public.lts_workbook_transfer_reversal_v338
 FOR ALL TO service_role USING(true) WITH CHECK(true);

CREATE OR REPLACE FUNCTION public.lts_workbook_transfer_identity_v338(p_user_id uuid)
RETURNS TABLE(source_ref text,event_date date,account text,description text,signed_amount numeric)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $body$
 SELECT * FROM public.lts_workbook_transfer_identity_v336(p_user_id)
 UNION ALL
 SELECT 'evento_base:'||e.idx::text,p.document_date,
 CASE p.leg_direction WHEN 'entrada' THEN p.destination_bank ELSE p.origin_bank END,
 e.dados->>'desc',CASE p.leg_direction WHEN 'entrada' THEN p.document_amount ELSE -p.document_amount END
 FROM public.lts_workbook_transfer_reversal_v338 p
 JOIN public.evento_base e ON e.usuario_id=p.user_id AND e.idx=p.legacy_index AND e.dados=p.source_payload
 WHERE p.user_id=p_user_id AND (e.dados->>'dia')::date=p.document_date
 AND lower(regexp_replace(btrim(e.dados->>'desc'),'\s+',' ','g'))=lower(regexp_replace(btrim(p.document_description),'\s+',' ','g'))
 AND (e.dados->>'valor')::numeric=abs(p.document_amount) AND e.dados->>'efeito'=p.leg_direction
 AND CASE lower(e.dados->>'conta') WHEN 'itau' THEN 'Itaú' WHEN 'itaú' THEN 'Itaú' WHEN 'bradesco' THEN 'Bradesco' WHEN 'c6' THEN 'C6' END=
     CASE p.leg_direction WHEN 'entrada' THEN p.destination_bank ELSE p.origin_bank END
 AND NOT EXISTS(SELECT 1 FROM public.lts_workbook_transfer_evidence_v336 b WHERE b.user_id=p.user_id AND b.legacy_index=p.legacy_index)
 AND NOT EXISTS(
  SELECT 1 FROM public.lts_v178_review_decision d
  WHERE d.user_id=p.user_id AND d.source_table='evento_base' AND d.source_ref=e.idx::text
  AND (d.beneficiary IS NOT NULL OR d.property_code IS NOT NULL
   OR (d.category_label IS NOT NULL AND lower(btrim(d.category_label)) NOT IN
      ('transferência própria','transferencia propria','transferência bancária','transferencia bancaria','movimentação interna','movimentacao interna')))
 );
$body$;
REVOKE ALL ON FUNCTION public.lts_workbook_transfer_identity_v338(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_workbook_transfer_identity_v338(uuid) TO service_role;

DROP TRIGGER IF EXISTS lts_v338_reversal_i ON public.lts_workbook_transfer_reversal_v338;
CREATE TRIGGER lts_v338_reversal_i AFTER INSERT ON public.lts_workbook_transfer_reversal_v338
 REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v338_reversal_u ON public.lts_workbook_transfer_reversal_v338;
CREATE TRIGGER lts_v338_reversal_u AFTER UPDATE ON public.lts_workbook_transfer_reversal_v338
 REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v338_reversal_d ON public.lts_workbook_transfer_reversal_v338;
CREATE TRIGGER lts_v338_reversal_d AFTER DELETE ON public.lts_workbook_transfer_reversal_v338
 REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v338_reversal_t ON public.lts_workbook_transfer_reversal_v338;
CREATE TRIGGER lts_v338_reversal_t AFTER TRUNCATE ON public.lts_workbook_transfer_reversal_v338
 FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();

DO $patch$
DECLARE target regprocedure:='public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure;
 definition text;attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF position('lts_workbook_transfer_identity_v338(p_user_id)' IN definition)>0 THEN
  IF md5(replace(definition,'lts_workbook_transfer_identity_v338(p_user_id)','lts_workbook_transfer_identity_v336(p_user_id)')) IS DISTINCT FROM 'be423d11064e77ceb5450d28fc9d6ea3'
  THEN RAISE EXCEPTION 'V338 replay definition changed';END IF;RETURN;
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=target) IS DISTINCT FROM '97d161bc604bb29becbeb2ad7a19bb97'
  OR md5(definition) IS DISTINCT FROM 'be423d11064e77ceb5450d28fc9d6ea3'
 THEN RAISE EXCEPTION 'V338 history definition lease changed';END IF;
 EXECUTE replace(definition,'lts_workbook_transfer_identity_v336(p_user_id)','lts_workbook_transfer_identity_v338(p_user_id)');
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V338 history attributes changed';END IF;
END $patch$;
