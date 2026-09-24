-- Index the exact user/source-reference predicate used by the historical reader.
-- Non-unique access path only: no balance, category, source row or ACL changes.
SET LOCAL lock_timeout = '2s';
DO $repair$
DECLARE
  before_rows text;
  after_rows text;
BEGIN
  IF to_regclass('public.lts_evento_base_user_idx_text_v183') IS NOT NULL THEN
    RAISE EXCEPTION 'Historical lookup index already exists; inspect migration state';
  END IF;
  SELECT md5(coalesce(string_agg(to_jsonb(r)::text,E'\n'
    ORDER BY u.user_id,r.event_date,r.source,r.source_ref,to_jsonb(r)::text),''))
  INTO before_rows
  FROM (SELECT DISTINCT user_id FROM public.lts_expense_effective_read_cache) u
  CROSS JOIN LATERAL public.lts_historical_effective_cash_v3(
    u.user_id,date '2013-10-10',current_date) r;

  CREATE INDEX lts_evento_base_user_idx_text_v183
    ON public.evento_base (usuario_id, (idx::text))
    WHERE dados ? 'dia';
  ANALYZE public.evento_base;

  SELECT md5(coalesce(string_agg(to_jsonb(r)::text,E'\n'
    ORDER BY u.user_id,r.event_date,r.source,r.source_ref,to_jsonb(r)::text),''))
  INTO after_rows
  FROM (SELECT DISTINCT user_id FROM public.lts_expense_effective_read_cache) u
  CROSS JOIN LATERAL public.lts_historical_effective_cash_v3(
    u.user_id,date '2013-10-10',current_date) r;
  IF before_rows IS DISTINCT FROM after_rows THEN
    RAISE EXCEPTION 'Historical source output changed; reverting lookup index';
  END IF;
END
$repair$;
