\ir lts_v429_setup.sql
CREATE OR REPLACE FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT $2||'{"changed":true}'::jsonb$$;
REVOKE ALL ON FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb) TO service_role;
\ir ../patches/v429/canonical_cycle_settlement.sql
