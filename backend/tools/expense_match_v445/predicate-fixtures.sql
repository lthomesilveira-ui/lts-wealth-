-- Extracted candidate matched/unmatched SQL predicates, synthetic fixtures only.
BEGIN READ ONLY;
WITH scenarios(name,n) AS (VALUES ('valid',1),('internal_transfer',2),('is_asset_movement',3),('asset_movement',4),('excluded_from_spend',5),('excluded',6),('non_cash_marker',7),('card_settlement',8),('invoice_category',9),('canonical_contract',10),('prior_month',11),('wrong_amount',12),('wrong_day',13),('ambiguous_candidates',14),('duplicate_event',15)), candidates AS MATERIALIZED (
 SELECT ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid AS id,name,
 date '2026-11-03' posting_date,-123.45::numeric signed_amount,'Synthetic Bank'::text bank,
 CASE WHEN name='canonical_contract' THEN '{}'::jsonb END fixture_contract,
 jsonb_build_object('reconciliation',jsonb_build_object('candidates',
 jsonb_build_array(jsonb_build_object('ref','current_event:event-'||name,'date','2026-11-03','amount',-123.45,'delta',0))
 || CASE WHEN name='ambiguous_candidates' THEN jsonb_build_array(jsonb_build_object('ref','other')) ELSE '[]'::jsonb END)) normalized_payload FROM scenarios
), events AS (
 SELECT name,jsonb_build_object('source','current_event','source_ref','event-'||name,
 'account','Synthetic Bank','event_date',CASE WHEN name='wrong_day' THEN '2026-11-04' ELSE '2026-11-03' END,
 'signed_amount',CASE WHEN name='wrong_amount' THEN -124 ELSE -123.45 END,
 'category',CASE WHEN name='invoice_category' THEN 'Pagamento de fatura' ELSE 'Synthetic expense' END)
 || CASE WHEN name IN('internal_transfer','is_asset_movement','asset_movement','excluded_from_spend','excluded','non_cash_marker','card_settlement') THEN jsonb_build_object(name,true) ELSE '{}'::jsonb END e FROM scenarios
), context AS (SELECT jsonb_agg(e) || (SELECT jsonb_build_array(e) FROM events WHERE name='duplicate_event') AS events FROM events),
matched AS MATERIALIZED (
 SELECT s.*, e AS operational_event
 FROM candidates s CROSS JOIN context c CROSS JOIN LATERAL jsonb_array_elements(c.events) e
 WHERE e->>'source'='current_event' AND nullif(e->>'source_ref','') IS NOT NULL
 AND e->>'account'=s.bank AND (e->>'event_date')::date=s.posting_date
 AND (e->>'signed_amount')::numeric=s.signed_amount
 AND NOT coalesce((e->>'internal_transfer')::boolean,false)
 AND NOT coalesce((e->>'is_asset_movement')::boolean,false)
 AND NOT coalesce((e->>'asset_movement')::boolean,false)
 AND NOT coalesce((e->>'excluded_from_spend')::boolean,false)
 AND NOT coalesce((e->>'excluded')::boolean,false)
 AND NOT coalesce((e->>'non_cash_marker')::boolean,false)
 AND NOT coalesce((e->>'card_settlement')::boolean,false)
 AND s.fixture_contract IS NULL
 AND e->>'category' IS DISTINCT FROM 'Pagamento de fatura'
 AND jsonb_array_length(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]'))=1
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(s.normalized_payload#>'{reconciliation,candidates}') z
   WHERE z->>'ref'='current_event:'||(e->>'source_ref')
   AND z->>'date'=s.posting_date::text AND (z->>'amount')::numeric=s.signed_amount
   AND (z->>'delta')::numeric=0)
), existing AS MATERIALIZED (SELECT 'event-prior_month'::text AS source_ref), unmatched AS MATERIALIZED (
 SELECT s.* FROM matched s
 WHERE (SELECT count(*) FROM matched z WHERE z.id=s.id)=1
 AND (SELECT count(*) FROM matched z WHERE z.operational_event->>'source_ref'=s.operational_event->>'source_ref')=1
 AND NOT EXISTS(SELECT 1 FROM public.lts_v229_new_bank_rows('00000000-0000-0000-0000-000000000001'::uuid,date '2026-11-01',date '2026-11-15') n WHERE n.id=s.id)
 AND NOT EXISTS(SELECT 1 FROM public.lts_realized_bank_sources_v238('00000000-0000-0000-0000-000000000001'::uuid) n WHERE n.staging_id=s.id)
 AND NOT EXISTS(SELECT 1 FROM existing e WHERE e.source_ref IN(s.id::text,s.operational_event->>'source_ref')
   OR EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id='00000000-0000-0000-0000-000000000001'::uuid
    AND f.legacy_id=s.operational_event->>'source_ref' AND e.source_ref=f.id::text))

)
SELECT count(*)=1 AND bool_and(name='valid') AS pass, count(*) AS recovered_fixture_rows FROM unmatched;
COMMIT;
