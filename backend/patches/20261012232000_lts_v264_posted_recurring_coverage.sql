-- V264: confirmed posted bank purposes and strict current-month actuals in recurring coverage.
DO $patch$
DECLARE d text; before_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef(oid),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
 IF md5(d)<>'8b9d83439a8feccef69af69617bbd961' THEN RAISE EXCEPTION 'source lease changed: lts_recurring_future_gap_audit_v6'; END IF;
 d:=replace(d,$old$), history_raw AS MATERIALIZED (
 SELECT h.event_date,h.description,public.lts_forecast_series_key_v1(h.description) series_key,
 CASE WHEN h.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(h.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_historical_effective_cash_v4(p_user_id,(p.as_of-interval '36 months')::date,p.as_of) h
 WHERE h.signed_amount<>0 AND NOT h.internal_transfer AND NOT h.excluded_from_spend
), history AS MATERIALIZED (
 SELECT * FROM history_raw
 UNION ALL
 SELECT f.event_date,coalesce(f.description_normalized,f.description_raw),public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)),
 CASE WHEN f.amount>0 THEN 'income' ELSE 'expense' END,abs(f.amount)
 FROM public.financial_events f CROSS JOIN params p
 WHERE f.user_id=p_user_id AND f.event_date BETWEEN date_trunc('month',p.as_of)::date AND p.as_of
 AND f.metadata->>'bank_confirmed'='true' AND NOT f.is_projection AND NOT f.is_suppressed
 AND NOT EXISTS (SELECT 1 FROM history_raw h WHERE h.event_date=f.event_date AND h.series_key=public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)) AND h.amount=abs(f.amount))
$old$,$new$), history_sources AS MATERIALIZED (
 SELECT h.*,public.lts_forecast_series_key_v1(h.description) series_key,
 CASE WHEN h.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(h.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_historical_effective_cash_v4(p_user_id,(p.as_of-interval '36 months')::date,p.as_of) h
 WHERE h.signed_amount<>0 AND NOT h.internal_transfer AND NOT h.excluded_from_spend
), bank_actual AS MATERIALIZED (
 SELECT s.id,s.posting_date event_date,s.signed_amount,
 coalesce(identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,s.description_raw) description,
 public.lts_forecast_series_key_v1(coalesce(identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,s.description_raw)) series_key,
 CASE WHEN s.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(s.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_bank_posted_rows_v231(p_user_id) s
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(p_user_id,s.id) c OFFSET 0)k ON true
 LEFT JOIN LATERAL (
 SELECT CASE WHEN count(DISTINCT h.series_key)=1 THEN min(h.description) END description
 FROM history_sources h
 WHERE h.event_date>=date_trunc('month',p.as_of)::date
 AND h.account=s.institution_name AND h.signed_amount=s.signed_amount
 AND (
 EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm WHERE dm.user_id=p_user_id
  AND dm.staging_id=s.id AND dm.source_ref=h.source_ref AND dm.bank=h.account AND dm.signed_amount=s.signed_amount)
 OR (h.event_date=s.posting_date AND (
  EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]'::jsonb)) z
   WHERE z->>'ref' IN(h.source_ref,h.source||':'||h.source_ref))
  OR lower(trim(h.description))=lower(trim(s.description_raw))
  OR public.lts_documented_bank_event_identity_v242(p_user_id,s.id,to_jsonb(h)))))
 ) identity ON true
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.posting_date BETWEEN date_trunc('month',p.as_of)::date AND p.as_of
 AND s.signed_amount<>0
), history_raw AS MATERIALIZED (
 SELECT h.event_date,h.description,h.series_key,h.direction,h.amount
 FROM history_sources h CROSS JOIN params p
 WHERE h.event_date<date_trunc('month',p.as_of)::date
 OR (h.confidence NOT IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
 AND NOT EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id=p_user_id
  AND f.is_projection AND NOT f.is_suppressed AND (f.id::text=h.source_ref OR f.legacy_id=h.source_ref))
 AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm
  JOIN bank_actual b ON b.id=dm.staging_id WHERE dm.user_id=p_user_id AND dm.source_ref=h.source_ref)
 AND NOT EXISTS(SELECT 1 FROM bank_actual b WHERE b.event_date=h.event_date
  AND b.series_key=h.series_key AND b.direction=h.direction AND b.amount=h.amount))
), history AS MATERIALIZED (
 SELECT * FROM history_raw
 UNION ALL
 SELECT b.event_date,b.description,b.series_key,b.direction,b.amount FROM bank_actual b
 UNION ALL
 SELECT f.event_date,coalesce(f.description_normalized,f.description_raw),public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)),
 CASE WHEN f.amount>0 THEN 'income' ELSE 'expense' END,abs(f.amount)
 FROM public.financial_events f CROSS JOIN params p
 WHERE f.user_id=p_user_id AND f.event_date BETWEEN date_trunc('month',p.as_of)::date AND p.as_of
 AND f.metadata->>'bank_confirmed'='true' AND NOT f.is_projection AND NOT f.is_suppressed
 AND NOT EXISTS (SELECT 1 FROM history_raw h WHERE h.event_date=f.event_date AND h.series_key=public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)) AND h.amount=abs(f.amount))
 AND NOT EXISTS (SELECT 1 FROM bank_actual b WHERE b.event_date=f.event_date AND b.series_key=public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)) AND b.amount=abs(f.amount))
$new$);
 d:=replace(d,$old$calendar-forecast-coverage-v6$old$,$new$calendar-forecast-coverage-v264$new$);
 d:=replace(d,$old$pagamentos já recebidos contam no mês atual.$old$,$new$pagamentos postados contam no mês atual; previsões vencidas sem comprovação não contam como realizadas.$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) IS DISTINCT FROM before_acl THEN RAISE EXCEPTION 'ACL changed'; END IF;
END $patch$;
