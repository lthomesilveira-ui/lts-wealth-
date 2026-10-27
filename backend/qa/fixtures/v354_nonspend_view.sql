CREATE VIEW public.lts_workbook_nonspend_source_v343 WITH(security_invoker=true)AS
 SELECT e.user_id,
    'historico_analitico'::text AS source_table,
    h.idx::text AS source_ref,
    e.evidence_date,
    e.amount,
    e.description,
    e.id AS evidence_id,
    e.metadata ->> 'nature'::text AS nature
   FROM lts_reconciliation_evidence e
     JOIN historico_analitico h ON h.usuario_id = e.user_id AND e.source_ref = ('historico_analitico:'::text || h.idx::text)
  WHERE e.evidence_type = 'historical_workbook_nonspend_v343'::text AND e.status = 'documented'::text AND e.account = 'Itaú'::text AND e.amount > 0::numeric AND e.evidence_date >= '2013-10-10'::date AND e.evidence_date <= '2017-12-31'::date AND (e.metadata ->> 'schema'::text) = 'workbook-nonspend-v343'::text AND (e.metadata -> 'source_payload'::text) = h.dados AND (e.metadata ->> 'source_table'::text) = 'historico_analitico'::text AND (e.metadata ->> 'source_ref'::text) = h.idx::text AND e.evidence_date::text = (h.dados ->> 'd'::text) AND to_jsonb(e.amount) = (h.dados -> 'v'::text) AND e.description = (h.dados ->> 'x'::text) AND (h.dados ->> 'e'::text) = 'saida'::text AND ((h.dados ->> 'm'::text) = ''::text AND ((h.dados ->> 'x'::text) = 'Família'::text AND (h.dados ->> 'c'::text) = 'Família'::text AND (e.metadata ->> 'flow_label_cell'::text) = 'A44'::text AND (e.metadata ->> 'nature'::text) = 'receipt'::text OR (h.dados ->> 'x'::text) = 'Nota Fiscal Paulista'::text AND (h.dados ->> 'c'::text) = 'Impostos'::text AND (e.metadata ->> 'flow_label_cell'::text) = 'A50'::text AND (e.metadata ->> 'nature'::text) = 'receipt'::text OR (h.dados ->> 'x'::text) = 'FGTS'::text AND (h.dados ->> 'c'::text) = 'Impostos'::text AND (e.metadata ->> 'flow_label_cell'::text) = 'A30'::text AND (e.metadata ->> 'nature'::text) = 'asset_withdrawal'::text) OR (h.dados ->> 'm'::text) = 'sinal negativo'::text AND (h.dados ->> 'x'::text) = 'Salário'::text AND (h.dados ->> 'c'::text) = 'Salário'::text AND (e.metadata ->> 'nature'::text) = 'receipt_adjustment'::text AND (e.metadata ->> 'flow_label_cell'::text) = 'A10'::text AND (e.metadata ->> 'batch'::text) = 'workbook-source-v348'::text AND jsonb_typeof(e.metadata -> 'workbook_signed_amount'::text) = 'number'::text AND (e.metadata -> 'workbook_signed_amount'::text) = to_jsonb(- e.amount) AND jsonb_array_length(
        CASE
            WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
            ELSE '[]'::jsonb
        END) = 1 AND (( SELECT count(*) AS count
           FROM jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(e.metadata -> 'workbook_evidence'::text) = 'array'::text THEN e.metadata -> 'workbook_evidence'::text
                    ELSE '[]'::jsonb
                END) w(value)
          WHERE (w.value ->> 'sheet'::text) = 'Pagamentos e Recebimentos'::text AND (w.value ->> 'date'::text) = e.evidence_date::text AND (w.value ->> 'description'::text) = e.description AND (w.value ->> 'category'::text) = 'Salário'::text AND to_jsonb((w.value ->> 'row'::text)::integer) = ((e.metadata -> 'workbook_rows'::text) -> 0) AND round((w.value ->> 'signed_amount'::text)::numeric, 2) = (- e.amount) AND ((w.value ->> 'file'::text) = 'Controle_Financeiro_v16.xlsm'::text AND (w.value ->> 'sha256'::text) = '57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e'::text OR (w.value ->> 'file'::text) = 'Controle_Financeiro_Fase1_Compactado.xlsx'::text AND (w.value ->> 'sha256'::text) = '36e26f4c168483680bfbb723934fb09165c5884b03de052cc07b39ded00ab086'::text))) = 2 AND (( SELECT count(DISTINCT w.value ->> 'file'::text) AS count
           FROM jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(e.metadata -> 'workbook_evidence'::text) = 'array'::text THEN e.metadata -> 'workbook_evidence'::text
                    ELSE '[]'::jsonb
                END) w(value))) = 2) AND (e.metadata ->> 'documented_direction'::text) = 'entrada'::text AND (e.metadata ->> 'workbook_sheet'::text) = 'Pagamentos e Recebimentos'::text AND (e.metadata ->> 'flow_sheet'::text) = 'Fluxo de Caixa'::text AND (e.metadata -> 'income_sum_row'::text) = '7'::jsonb AND (e.metadata ->> 'workbook_sha256'::text) ~ '^[0-9a-f]{64}$'::text AND jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text AND jsonb_array_length(
        CASE
            WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
            ELSE '[]'::jsonb
        END) > 0 AND NOT (EXISTS ( SELECT 1
           FROM jsonb_array_elements_text(
                CASE
                    WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
                    ELSE '[]'::jsonb
                END) x(v)
          WHERE x.v !~ '^[1-9][0-9]*$'::text)) AND (( SELECT count(DISTINCT x.v) AS count
           FROM jsonb_array_elements_text(
                CASE
                    WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
                    ELSE '[]'::jsonb
                END) x(v))) = jsonb_array_length(
        CASE
            WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
            ELSE '[]'::jsonb
        END) AND (e.metadata -> 'tuple_multiplicity'::text) = to_jsonb(jsonb_array_length(
        CASE
            WHEN jsonb_typeof(e.metadata -> 'workbook_rows'::text) = 'array'::text THEN e.metadata -> 'workbook_rows'::text
            ELSE '[]'::jsonb
        END)) AND (e.metadata -> 'tuple_multiplicity'::text) = to_jsonb(( SELECT count(*) AS count
           FROM historico_analitico same_source
          WHERE same_source.usuario_id = h.usuario_id AND (same_source.dados - 'h'::text) = (h.dados - 'h'::text))) AND NOT (EXISTS ( SELECT 1
           FROM lts_v178_review_decision d
          WHERE d.user_id = e.user_id AND d.source_table = 'historico_analitico'::text AND d.source_ref = h.idx::text)) AND NOT (EXISTS ( SELECT 1
           FROM lts_reconciliation_evidence conflict
          WHERE conflict.id <> e.id AND conflict.user_id = e.user_id AND conflict.source_ref = e.source_ref AND conflict.evidence_type = e.evidence_type AND conflict.status = 'documented'::text));
REVOKE ALL ON public.lts_workbook_nonspend_source_v343 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_workbook_nonspend_source_v343 TO service_role;
