-- Caller provides a signed-in test context and lts.qa_user_id locally.
WITH q AS MATERIALIZED(SELECT public.lts_browser_flow_v242(current_date-5,date '2027-12-31')j),
parts AS(SELECT jsonb_build_object('historical_days',j#>'{flow,historical,days}',
 'historical_events',j#>'{flow,historical,events}','current_days',j#>'{flow,current_future,days}',
 'current_events',j#>'{flow,current_future,events}')j FROM q)
SELECT jsonb_build_object('financial_digest',md5(parts.j::text),'days',jsonb_array_length(parts.j->'current_days'),
 'events',jsonb_array_length(parts.j->'current_events'),'pending_count',(SELECT jsonb_array_length(j#>'{flow,observed_bank_movements,pending_projections}')FROM q),
 'canonical_agreement',(SELECT j#>'{flow,observed_bank_movements,pending_projections}' FROM q)=public.lts_pending_projections_v233(current_setting('lts.qa_user_id')::uuid)) receipt FROM parts;
