-- Contains no private texts or expected private digests. Compare its receipt
-- before/after and require zero expression mismatches.
WITH corpus AS MATERIALIZED(
 SELECT description_raw v FROM public.lts_open_finance_staging
 WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 UNION SELECT dados->>'desc' FROM public.evento_base
 WHERE usuario_id=public.lts_open_finance_pilot_owner_v1()
 UNION SELECT s.value#>>'{}' FROM public.financial_events f
 CROSS JOIN LATERAL jsonb_path_query(to_jsonb(f),'$.** ? (@.type() == "string")')s(value)
 WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 UNION SELECT v FROM (VALUES(NULL::text),(''),
 ('áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ'),
 (E'\tA\nB\rC  D'),('KİΣς😀 ñ Ö œ ß'),
 ('Pagamento de Pix QR Code | 01/10'),('ix'))s(v)
), compared AS MATERIALIZED(
 SELECT v,public.lts_v178_norm(v) actual_norm,
 public.lts_bank_merchant_key_v231(v) actual_merchant,
 pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(v,''),
 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') reference_norm
 FROM corpus
), final AS MATERIALIZED(
 SELECT *,pg_catalog.regexp_replace(pg_catalog.regexp_replace(
 pg_catalog.regexp_replace(pg_catalog.regexp_replace(reference_norm,
 '^(pagamento de pix qr code|pix qrs|pix recebido|pix enviado|pagamento de seguro)[[:space:]]+','','i'),
 '[[:space:]]+[0-9]{2}/[0-9]{2}$','','g'),
 '[[:space:]]+(s[.]?[[:space:]]*a[.]?|ltda[.]?)$','','i'),'[^a-z0-9]','','g') reference_merchant
 FROM compared
)
SELECT count(*) corpus_count,
 count(*) FILTER(WHERE actual_norm IS DISTINCT FROM reference_norm) norm_mismatches,
 count(*) FILTER(WHERE actual_merchant IS DISTINCT FROM reference_merchant) merchant_mismatches,
 md5(string_agg(coalesce(v,'<NULL>')||':'||actual_norm||':'||actual_merchant,E'\n'
 ORDER BY v NULLS FIRST)) corpus_digest FROM final;
