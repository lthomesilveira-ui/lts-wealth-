-- Source-specific workbook evidence; no financial leg is created or changed.
CREATE TABLE IF NOT EXISTS public.lts_workbook_transfer_evidence_v336 (
 user_id uuid NOT NULL,
 legacy_index integer NOT NULL,
 source_payload jsonb NOT NULL,
 workbook_sha256 text NOT NULL CHECK (workbook_sha256 ~ '^[0-9a-f]{64}$'),
 workbook_sheet text NOT NULL CHECK (length(workbook_sheet)>0),
 workbook_row integer NOT NULL CHECK (workbook_row>0),
 workbook_through date NOT NULL,
 document_date date NOT NULL,
 document_description text NOT NULL,
 document_amount numeric NOT NULL CHECK (document_amount>0),
 document_category text NOT NULL CHECK (document_category='Transferência Bancária'),
 origin_bank text NOT NULL CHECK (origin_bank IN ('Itaú','Bradesco','C6')),
 destination_bank text NOT NULL CHECK (destination_bank IN ('Itaú','Bradesco','C6')),
 leg_direction text NOT NULL CHECK (leg_direction IN ('entrada','saida')),
 PRIMARY KEY (user_id,legacy_index),
 CHECK (origin_bank<>destination_bank),
 CHECK (document_date<=workbook_through)
);
ALTER TABLE public.lts_workbook_transfer_evidence_v336 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_workbook_transfer_evidence_v336 FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.lts_workbook_transfer_evidence_v336 TO service_role;
DROP POLICY IF EXISTS service_workbook_evidence_v336 ON public.lts_workbook_transfer_evidence_v336;
CREATE POLICY service_workbook_evidence_v336 ON public.lts_workbook_transfer_evidence_v336
 FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.lts_workbook_transfer_identity_v336(p_user_id uuid)
RETURNS TABLE(source_ref text,event_date date,account text,description text,signed_amount numeric)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $body$
 SELECT 'evento_base:'||e.idx::text,p.document_date,
 CASE p.leg_direction WHEN 'entrada' THEN p.destination_bank ELSE p.origin_bank END,
 e.dados->>'desc',
 CASE p.leg_direction WHEN 'entrada' THEN p.document_amount ELSE -p.document_amount END
 FROM public.lts_workbook_transfer_evidence_v336 p
 JOIN public.evento_base e ON e.usuario_id=p.user_id AND e.idx=p.legacy_index
  AND e.dados=p.source_payload
 WHERE p.user_id=p_user_id
 AND (e.dados->>'dia')::date=p.document_date
 AND lower(regexp_replace(btrim(e.dados->>'desc'),'\s+',' ','g'))=
     lower(regexp_replace(btrim(p.document_description),'\s+',' ','g'))
 AND abs((e.dados->>'valor')::numeric)=p.document_amount
 AND e.dados->>'efeito'=p.leg_direction
 AND NOT EXISTS (
  SELECT 1 FROM public.lts_v178_review_decision d
  WHERE d.user_id=p.user_id AND d.source_table='evento_base' AND d.source_ref=e.idx::text
  AND (d.beneficiary IS NOT NULL OR d.property_code IS NOT NULL
   OR (d.category_label IS NOT NULL AND lower(btrim(d.category_label)) NOT IN
      ('transferência própria','transferencia propria','transferência bancária','transferencia bancaria','movimentação interna','movimentacao interna')))
 );
$body$;
REVOKE ALL ON FUNCTION public.lts_workbook_transfer_identity_v336(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_workbook_transfer_identity_v336(uuid) TO service_role;

-- Evidence edits invalidate the same derived readers as existing classifications.
DROP TRIGGER IF EXISTS lts_v336_evidence_i ON public.lts_workbook_transfer_evidence_v336;
CREATE TRIGGER lts_v336_evidence_i AFTER INSERT ON public.lts_workbook_transfer_evidence_v336
 REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v336_evidence_u ON public.lts_workbook_transfer_evidence_v336;
CREATE TRIGGER lts_v336_evidence_u AFTER UPDATE ON public.lts_workbook_transfer_evidence_v336
 REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v336_evidence_d ON public.lts_workbook_transfer_evidence_v336;
CREATE TRIGGER lts_v336_evidence_d AFTER DELETE ON public.lts_workbook_transfer_evidence_v336
 REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
DROP TRIGGER IF EXISTS lts_v336_evidence_t ON public.lts_workbook_transfer_evidence_v336;
CREATE TRIGGER lts_v336_evidence_t AFTER TRUNCATE ON public.lts_workbook_transfer_evidence_v336
 FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();

DO $patch$
DECLARE target regprocedure:='public.lts_historical_effective_cash_v3(uuid,date,date)'::regprocedure;
 definition text; attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF position('v336-source-workbook-transfer' IN definition)>0 THEN
  IF md5(replace(replace(replace(replace(replace(definition,
   $new$/* v336-source-workbook-transfer */(e.internal_transfer OR proof.source_ref IS NOT NULL)$new$,'e.internal_transfer'),
   $new$case when proof.source_ref IS NOT NULL then 'Transferência própria' else case when e.source='legacy_fix86' then coalesce(nullif(s.category_candidate,''),nullif(s.category_raw,''),e.category) else e.category end end category$new$,
   $old$case when e.source='legacy_fix86' then coalesce(nullif(s.category_candidate,''),nullif(s.category_raw,''),e.category) else e.category end category$old$),
   $new$case when proof.source_ref IS NOT NULL then 'Própria' else case when e.source='legacy_fix86' then coalesce(nullif(s.counterparty_candidate,''),e.counterparty) else e.counterparty end end counterparty$new$,
   $old$case when e.source='legacy_fix86' then coalesce(nullif(s.counterparty_candidate,''),e.counterparty) else e.counterparty end counterparty$old$),
   $new$case when proof.source_ref IS NOT NULL then true else case when e.source='legacy_fix86' then coalesce(s.exclude_from_spend,e.excluded_from_spend) else e.excluded_from_spend end end excluded_from_spend$new$,
   $old$case when e.source='legacy_fix86' then coalesce(s.exclude_from_spend,e.excluded_from_spend) else e.excluded_from_spend end excluded_from_spend$old$),
   $new$
left join public.lts_workbook_transfer_identity_v336(p_user_id) proof on e.source='legacy_fix86'
 and e.source_ref=proof.source_ref and e.original_date=proof.event_date
 and e.description=proof.description and e.account=proof.account and e.signed_amount=proof.signed_amount$new$,''))
   IS DISTINCT FROM '050c13521f38b8357a59e62ee0edc50f' THEN
   -- Full-definition lease is checked below for the first application; replay
   -- must reverse exactly the same narrow substitutions before it is a no-op.
   RAISE EXCEPTION 'V336 replay definition changed';
  END IF;
  RETURN;
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=target) IS DISTINCT FROM '45dbdab240589fa895f2d89487a5293f'
 THEN RAISE EXCEPTION 'V336 history definition lease changed';END IF;
 IF position('e.displaced,e.internal_transfer,' IN definition)=0 OR position(
  'from public.lts_historical_effective_cash_v2(p_user_id,p_from,p_to) e' IN definition)=0
 THEN RAISE EXCEPTION 'V336 history anchors changed';END IF;
 definition:=replace(definition,'e.displaced,e.internal_transfer,',
  'e.displaced,/* v336-source-workbook-transfer */(e.internal_transfer OR proof.source_ref IS NOT NULL),');
 definition:=replace(definition,
  $old$case when e.source='legacy_fix86' then coalesce(nullif(s.category_candidate,''),nullif(s.category_raw,''),e.category) else e.category end category$old$,
  $new$case when proof.source_ref IS NOT NULL then 'Transferência própria' else case when e.source='legacy_fix86' then coalesce(nullif(s.category_candidate,''),nullif(s.category_raw,''),e.category) else e.category end end category$new$);
 definition:=replace(definition,
  $old$case when e.source='legacy_fix86' then coalesce(nullif(s.counterparty_candidate,''),e.counterparty) else e.counterparty end counterparty$old$,
  $new$case when proof.source_ref IS NOT NULL then 'Própria' else case when e.source='legacy_fix86' then coalesce(nullif(s.counterparty_candidate,''),e.counterparty) else e.counterparty end end counterparty$new$);
 definition:=replace(definition,
  $old$case when e.source='legacy_fix86' then coalesce(s.exclude_from_spend,e.excluded_from_spend) else e.excluded_from_spend end excluded_from_spend$old$,
  $new$case when proof.source_ref IS NOT NULL then true else case when e.source='legacy_fix86' then coalesce(s.exclude_from_spend,e.excluded_from_spend) else e.excluded_from_spend end end excluded_from_spend$new$);
 definition:=replace(definition,'from public.lts_historical_effective_cash_v2(p_user_id,p_from,p_to) e',
  $new$from public.lts_historical_effective_cash_v2(p_user_id,p_from,p_to) e
left join public.lts_workbook_transfer_identity_v336(p_user_id) proof on e.source='legacy_fix86'
 and e.source_ref=proof.source_ref and e.original_date=proof.event_date
 and e.description=proof.description and e.account=proof.account and e.signed_amount=proof.signed_amount$new$);
 EXECUTE definition;
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V336 history attributes changed';END IF;
END $patch$;
