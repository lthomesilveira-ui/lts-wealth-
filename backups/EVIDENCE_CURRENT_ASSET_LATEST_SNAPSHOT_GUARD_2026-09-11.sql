-- Applied through Supabase apply_migration on 2026-09-11.
-- Preserve dated source rows; select only the latest snapshot per current asset.
DO $migration$
DECLARE
  body text;
  old_asset text := $old$  select asset_type,asset_name,as_of_date,coalesce(value_brl,0) value_brl,liquidity_class,is_available_now
  from public.asset_positions where user_id=p_user_id$old$;
  new_asset text := $new$  -- A dated snapshot replaces the same asset's previous snapshot; it is not a second asset.
  select distinct on (asset_name,asset_type)
         asset_type,asset_name,as_of_date,coalesce(value_brl,0) value_brl,liquidity_class,is_available_now
  from public.asset_positions
  where user_id=p_user_id and as_of_date<=current_date
  order by asset_name,asset_type,as_of_date desc,id desc$new$;
BEGIN
  SELECT pg_get_functiondef('public.lts_current_evidence_position_v1(uuid)'::regprocedure) INTO body;
  IF strpos(body,new_asset)>0 THEN RETURN; END IF;
  IF strpos(body,old_asset)=0 THEN RAISE EXCEPTION 'Asset snapshot guard precondition changed; inspect rather than overwrite'; END IF;
  EXECUTE replace(body,old_asset,new_asset);
END
$migration$;
