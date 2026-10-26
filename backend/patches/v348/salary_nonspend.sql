-- Extend the established exclusion to a proved negative salary adjustment.
-- The lease deliberately rejects replay: inspect the live view before retrying.
DO $lease$BEGIN
 IF md5(pg_get_viewdef('public.lts_workbook_nonspend_source_v343'::regclass,true))<>'af5e6a71f1d1a36b8a739b573fce0dfb'
 OR(SELECT relacl::text FROM pg_class WHERE oid='public.lts_workbook_nonspend_source_v343'::regclass)<>'{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres}'
 OR(SELECT reloptions FROM pg_class WHERE oid='public.lts_workbook_nonspend_source_v343'::regclass)IS DISTINCT FROM ARRAY['security_invoker=true']::text[]
 THEN RAISE EXCEPTION 'V348_NONSPEND_SOURCE_LEASE_CHANGED';END IF;
END $lease$;
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
 AND h.dados->>'e'='saida'
 AND ((h.dados->>'m'='' AND ((h.dados->>'x'='Família' AND h.dados->>'c'='Família'
       AND e.metadata->>'flow_label_cell'='A44' AND e.metadata->>'nature'='receipt')
   OR (h.dados->>'x'='Nota Fiscal Paulista' AND h.dados->>'c'='Impostos'
       AND e.metadata->>'flow_label_cell'='A50' AND e.metadata->>'nature'='receipt')
   OR (h.dados->>'x'='FGTS' AND h.dados->>'c'='Impostos'
       AND e.metadata->>'flow_label_cell'='A30' AND e.metadata->>'nature'='asset_withdrawal')))
 OR (h.dados->>'m'='sinal negativo' AND h.dados->>'x'='Salário' AND h.dados->>'c'='Salário'
 AND e.metadata->>'nature'='receipt_adjustment' AND e.metadata->>'flow_label_cell'='A10'
 AND e.metadata->>'batch'='workbook-source-v348'
 AND jsonb_typeof(e.metadata->'workbook_signed_amount')='number'
 AND e.metadata->'workbook_signed_amount'=to_jsonb(-e.amount)
 AND jsonb_array_length(CASE WHEN jsonb_typeof(e.metadata->'workbook_rows')='array' THEN e.metadata->'workbook_rows' ELSE '[]'::jsonb END)=1
 AND (SELECT count(*)FROM jsonb_array_elements(CASE WHEN jsonb_typeof(e.metadata->'workbook_evidence')='array' THEN e.metadata->'workbook_evidence' ELSE '[]'::jsonb END)w
 WHERE w->>'sheet'='Pagamentos e Recebimentos' AND w->>'date'=e.evidence_date::text
 AND w->>'description'=e.description AND w->>'category'='Salário'
 AND to_jsonb((w->>'row')::integer)=e.metadata->'workbook_rows'->0
 AND round((w->>'signed_amount')::numeric,2)=-e.amount
 AND ((w->>'file'='Controle_Financeiro_v16.xlsm' AND w->>'sha256'='57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e')
 OR(w->>'file'='Controle_Financeiro_Fase1_Compactado.xlsx' AND w->>'sha256'='36e26f4c168483680bfbb723934fb09165c5884b03de052cc07b39ded00ab086')))=2
 AND (SELECT count(DISTINCT w->>'file')FROM jsonb_array_elements(CASE WHEN jsonb_typeof(e.metadata->'workbook_evidence')='array' THEN e.metadata->'workbook_evidence' ELSE '[]'::jsonb END)w)=2))

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
