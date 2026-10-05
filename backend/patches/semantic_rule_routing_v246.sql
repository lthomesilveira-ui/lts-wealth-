-- Route exact semantic matches through the existing partial index.
-- Preserve confidence, rule-type, length and updated-at precedence.
CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4_pre_v246(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH resolved AS (
 SELECT e.*,coalesce(sr.category,e.category) resolved_category,coalesce(sr.counterparty,e.counterparty) resolved_counterparty,
  coalesce(sr.center_cost,e.center_cost) resolved_center,coalesce(sr.exclude_from_spend,e.excluded_from_spend) resolved_excluded
 FROM public.lts_historical_effective_cash_v3(p_user_id,p_from,p_to)e
 LEFT JOIN LATERAL (
  SELECT r.category,r.counterparty,r.center_cost,r.exclude_from_spend FROM public.lts_semantic_rule r
  WHERE r.active AND r.user_id=p_user_id AND (
   (r.match_type='exact' AND lower(trim(e.description))=lower(trim(r.match_value))) OR
   (r.match_type='prefix' AND lower(trim(e.description)) LIKE lower(trim(r.match_value))||'%') OR
   (r.match_type='contains' AND lower(trim(e.description)) LIKE '%'||lower(trim(r.match_value))||'%'))
  ORDER BY CASE WHEN r.confidence='user_confirmed' THEN 0 ELSE 1 END,
   CASE r.match_type WHEN 'exact' THEN 0 WHEN 'prefix' THEN 1 WHEN 'contains' THEN 2 ELSE 9 END,length(r.match_value) DESC,r.updated_at DESC LIMIT 1
 )sr ON true
), posted_identity AS (
 SELECT ev.id evidence_id,min(f.id::text) fact_id FROM public.lts_reconciliation_evidence ev
 JOIN public.financial_events f ON f.user_id=ev.user_id AND f.event_date::text=ev.metadata->>'posting_date'
  AND f.amount=ev.amount AND lower(trim(f.description_raw))=lower(trim(ev.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
  AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(ev.account)),'ú','u')
 WHERE ev.user_id=p_user_id AND ev.evidence_type='bank_statement' AND ev.status='documented'
  AND ev.metadata->>'cash_effect'='statement_fact_not_new_projection' AND ev.metadata->>'initiated_date'=ev.evidence_date::text
  AND ev.metadata->>'posting_date'>ev.evidence_date::text AND f.metadata->>'documented_statement_fact'='true'
  AND NOT f.is_suppressed AND NOT f.is_projection AND f.status<>'cancelled'
 GROUP BY ev.id HAVING count(*)=1
)
SELECT e.event_date,e.account,e.description,e.signed_amount,e.source,e.source_ref,e.confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced,e.internal_transfer,
 CASE WHEN lower(trim(coalesce(e.resolved_category,''))) IN ('','a classificar','—','classificação pendente') THEN coalesce(nullif(src.category,''),e.resolved_category) ELSE e.resolved_category END,
 CASE WHEN lower(trim(coalesce(e.resolved_counterparty,''))) IN ('','não identificado') THEN coalesce(nullif(src.counterparty,''),e.resolved_counterparty) ELSE e.resolved_counterparty END,
 coalesce(nullif(nullif(src.metadata#>>'{classification_h_answers_20260914,center_cost}',''),'Não atribuído'),nullif(nullif(src.metadata#>>'{user_classification_20260913,beneficiary}',''),'Não atribuído'),e.resolved_center),e.resolved_excluded
FROM resolved e LEFT JOIN LATERAL (
 SELECT f.category,f.metadata,f.counterparty FROM public.financial_events f JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 WHERE f.user_id=p_user_id AND NOT f.is_suppressed AND f.status<>'cancelled' AND e.source IN ('current_event','financial_events','confirmed_fact')
  AND (f.id::text=e.source_ref OR f.legacy_id=e.source_ref OR 'financial_events:'||f.id::text=e.source_ref)
  AND f.event_date=e.event_date AND f.amount=e.signed_amount AND translate(lower(a.institution),'ú','u')=translate(lower(e.account),'ú','u')
  AND lower(trim(coalesce(f.category,''))) NOT IN ('','a classificar','—') LIMIT 1
)src ON true WHERE NOT(e.source='reconciliation_evidence' AND EXISTS(SELECT 1 FROM posted_identity p WHERE p.evidence_id::text=e.source_ref));
$function$
;
REVOKE ALL ON FUNCTION public.lts_historical_effective_cash_v4_pre_v246(uuid,date,date) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4_pre_v237(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED (
 SELECT e.*,lower(trim(e.description)) normalized_description
 FROM public.lts_historical_effective_cash_v3(p_user_id,p_from,p_to) e
), patterns AS MATERIALIZED (
 SELECT r.*,lower(trim(r.match_value)) normalized_match
 FROM public.lts_semantic_rule r WHERE r.active AND r.user_id=p_user_id AND r.match_type IN ('prefix','contains')
), resolved AS (
 SELECT e.*,coalesce(sr.category,e.category) resolved_category,coalesce(sr.counterparty,e.counterparty) resolved_counterparty,
  coalesce(sr.center_cost,e.center_cost) resolved_center,coalesce(sr.exclude_from_spend,e.excluded_from_spend) resolved_excluded
 FROM base e
 LEFT JOIN LATERAL (
  SELECT r.category,r.counterparty,r.center_cost,r.exclude_from_spend FROM (
   SELECT r.category,r.counterparty,r.center_cost,r.exclude_from_spend,r.confidence,r.match_type,r.match_value,r.updated_at
   FROM public.lts_semantic_rule r
   WHERE r.active AND r.user_id=p_user_id AND r.match_type='exact'
    AND lower(trim(r.match_value))=e.normalized_description
   UNION ALL
   SELECT r.category,r.counterparty,r.center_cost,r.exclude_from_spend,r.confidence,r.match_type,r.match_value,r.updated_at
   FROM patterns r
   WHERE (r.match_type='prefix' AND e.normalized_description LIKE r.normalized_match||'%')
      OR (r.match_type='contains' AND e.normalized_description LIKE '%'||r.normalized_match||'%')
  ) r
  ORDER BY CASE WHEN r.confidence='user_confirmed' THEN 0 ELSE 1 END,
   CASE r.match_type WHEN 'exact' THEN 0 WHEN 'prefix' THEN 1 WHEN 'contains' THEN 2 ELSE 9 END,length(r.match_value) DESC,r.updated_at DESC LIMIT 1
 )sr ON true
), posted_identity AS (
 SELECT ev.id evidence_id,min(f.id::text) fact_id FROM public.lts_reconciliation_evidence ev
 JOIN public.financial_events f ON f.user_id=ev.user_id AND f.event_date::text=ev.metadata->>'posting_date'
  AND f.amount=ev.amount AND lower(trim(f.description_raw))=lower(trim(ev.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
  AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(ev.account)),'ú','u')
 WHERE ev.user_id=p_user_id AND ev.evidence_type='bank_statement' AND ev.status='documented'
  AND ev.metadata->>'cash_effect'='statement_fact_not_new_projection' AND ev.metadata->>'initiated_date'=ev.evidence_date::text
  AND ev.metadata->>'posting_date'>ev.evidence_date::text AND f.metadata->>'documented_statement_fact'='true'
  AND NOT f.is_suppressed AND NOT f.is_projection AND f.status<>'cancelled'
 GROUP BY ev.id HAVING count(*)=1
)
SELECT e.event_date,e.account,e.description,e.signed_amount,e.source,e.source_ref,e.confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced,e.internal_transfer,
 CASE WHEN lower(trim(coalesce(e.resolved_category,''))) IN ('','a classificar','—','classificação pendente') THEN coalesce(nullif(src.category,''),e.resolved_category) ELSE e.resolved_category END,
 CASE WHEN lower(trim(coalesce(e.resolved_counterparty,''))) IN ('','não identificado') THEN coalesce(nullif(src.counterparty,''),e.resolved_counterparty) ELSE e.resolved_counterparty END,
 coalesce(nullif(nullif(src.metadata#>>'{classification_h_answers_20260914,center_cost}',''),'Não atribuído'),nullif(nullif(src.metadata#>>'{user_classification_20260913,beneficiary}',''),'Não atribuído'),e.resolved_center),e.resolved_excluded
FROM resolved e LEFT JOIN LATERAL (
 SELECT f.category,f.metadata,f.counterparty FROM public.financial_events f JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 WHERE f.user_id=p_user_id AND NOT f.is_suppressed AND f.status<>'cancelled' AND e.source IN ('current_event','financial_events','confirmed_fact')
  AND (f.id::text=e.source_ref OR f.legacy_id=e.source_ref OR 'financial_events:'||f.id::text=e.source_ref)
  AND f.event_date=e.event_date AND f.amount=e.signed_amount AND translate(lower(a.institution),'ú','u')=translate(lower(e.account),'ú','u')
  AND lower(trim(coalesce(f.category,''))) NOT IN ('','a classificar','—') LIMIT 1
)src ON true WHERE NOT(e.source='reconciliation_evidence' AND EXISTS(SELECT 1 FROM posted_identity p WHERE p.evidence_id::text=e.source_ref));
$function$
;
