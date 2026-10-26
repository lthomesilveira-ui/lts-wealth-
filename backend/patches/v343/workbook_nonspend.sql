-- Documentary exclusion from spending only. Original imports, signs, amounts,
-- dates, cash movements, categories and later owner decisions remain intact.
-- Private evidence is supplied separately; this migration contains no owner data.
CREATE OR REPLACE VIEW public.lts_workbook_nonspend_source_v343
WITH (security_invoker=true) AS
SELECT e.user_id,'historico_analitico'::text source_table,h.idx::text source_ref,
       e.evidence_date,e.amount,e.description,e.id evidence_id,e.metadata->>'nature' nature
FROM public.lts_reconciliation_evidence e
JOIN public.historico_analitico h
 ON h.usuario_id=e.user_id AND e.source_ref='historico_analitico:'||h.idx::text
WHERE e.evidence_type='historical_workbook_nonspend_v343'
 AND e.status='documented' AND e.account='Itaú' AND e.amount>0
 AND e.evidence_date BETWEEN date '2013-10-10' AND date '2017-12-31'
 AND e.metadata->>'schema'='workbook-nonspend-v343'
 AND e.metadata->'source_payload'=h.dados
 AND e.metadata->>'source_table'='historico_analitico'
 AND e.metadata->>'source_ref'=h.idx::text
 AND e.evidence_date::text=h.dados->>'d'
 AND to_jsonb(e.amount)=h.dados->'v' AND e.description=h.dados->>'x'
 AND h.dados->>'e'='saida' AND h.dados->>'m'=''
 AND ((h.dados->>'x'='Família' AND h.dados->>'c'='Família'
       AND e.metadata->>'flow_label_cell'='A44' AND e.metadata->>'nature'='receipt')
   OR (h.dados->>'x'='Nota Fiscal Paulista' AND h.dados->>'c'='Impostos'
       AND e.metadata->>'flow_label_cell'='A50' AND e.metadata->>'nature'='receipt')
   OR (h.dados->>'x'='FGTS' AND h.dados->>'c'='Impostos'
       AND e.metadata->>'flow_label_cell'='A30' AND e.metadata->>'nature'='asset_withdrawal'))
 AND e.metadata->>'documented_direction'='entrada'
 AND e.metadata->>'workbook_sheet'='Pagamentos e Recebimentos'
 AND e.metadata->>'flow_sheet'='Fluxo de Caixa'
 AND e.metadata->'income_sum_row'='7'::jsonb
 AND e.metadata->>'workbook_sha256' ~ '^[0-9a-f]{64}$'
 AND jsonb_typeof(e.metadata->'workbook_rows')='array'
 AND jsonb_array_length(CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array'
   THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END)>0
 AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(
   CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array'
     THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END) x(v)
   WHERE x.v !~ '^[1-9][0-9]*$')
 AND (SELECT count(DISTINCT x.v) FROM jsonb_array_elements_text(
   CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array'
     THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END) x(v))
   =jsonb_array_length(CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array'
     THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END)
 AND e.metadata->'tuple_multiplicity'=to_jsonb(jsonb_array_length(
   CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array'
     THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END))
 AND e.metadata->'tuple_multiplicity'=to_jsonb((SELECT count(*)
   FROM public.historico_analitico same_source
   WHERE same_source.usuario_id=h.usuario_id AND same_source.dados-'h'=h.dados-'h'))
 AND NOT EXISTS (SELECT 1 FROM public.lts_v178_review_decision d
   WHERE d.user_id=e.user_id AND d.source_table='historico_analitico' AND d.source_ref=h.idx::text)
 AND NOT EXISTS (SELECT 1 FROM public.lts_reconciliation_evidence conflict
   WHERE conflict.id<>e.id AND conflict.user_id=e.user_id AND conflict.source_ref=e.source_ref
    AND conflict.evidence_type=e.evidence_type AND conflict.status='documented');
REVOKE ALL ON public.lts_workbook_nonspend_source_v343 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_workbook_nonspend_source_v343 TO service_role;

DO $patch$
DECLARE old_definition text; next_definition text;
BEGIN
 old_definition:=pg_get_viewdef('public.lts_expense_realized'::regclass,true);
 IF position('lts_workbook_nonspend_source_v343' IN old_definition)>0 THEN
   RETURN;
 END IF;
 IF md5(old_definition)<>'933164467d0082a4ba3d075e7f85ea9a'
 OR (SELECT relacl::text FROM pg_class WHERE oid='public.lts_expense_realized'::regclass)
    <>'{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}'
 OR (SELECT reloptions FROM pg_class WHERE oid='public.lts_expense_realized'::regclass)
    IS DISTINCT FROM ARRAY['security_invoker=true']::text[]
 THEN RAISE EXCEPTION 'V343_EXPENSE_REALIZED_SOURCE_LEASE_CHANGED';END IF;
 next_definition:=replace(old_definition,E'    exclude_from_spend,',
   E'    (exclude_from_spend OR (c.source_table=\'historico_analitico\' AND EXISTS (SELECT 1 FROM public.lts_workbook_nonspend_source_v343 proof WHERE proof.user_id=c.user_id AND proof.source_table=c.source_table AND proof.source_ref=c.source_ref))) AS exclude_from_spend,');
 IF next_definition=old_definition THEN RAISE EXCEPTION 'V343_EXCLUSION_SLOT_MISSING';END IF;
 EXECUTE 'CREATE OR REPLACE VIEW public.lts_expense_realized WITH(security_invoker=true) AS '||next_definition;
END $patch$;
