-- A later primary position cannot change the anchor used for an earlier day.
-- Cofrinho redemptions use V381 source identities; FGTS is a separate resource.
CREATE OR REPLACE FUNCTION public.lts_cofrinho_composition_v399(p_user_id uuid,p_date date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
WITH anchor AS MATERIALIZED(
 SELECT l.lock_key,(l.canonical_value->>'as_of')::date dt,(l.canonical_value->>'amount')::numeric amount
 FROM public.lts_validated_lock_registry l
 WHERE l.lock_key LIKE 'itau_cofrinho_%' AND l.superseded_at IS NULL
 AND (l.canonical_value->>'as_of')::date<=p_date
 AND EXISTS(SELECT 1 FROM public.asset_positions a WHERE a.user_id=p_user_id
  AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
  AND a.metadata->>'validated_lock_key'=l.lock_key)
 ORDER BY (l.canonical_value->>'as_of')::date DESC,l.locked_at DESC,l.lock_key DESC LIMIT 1
),moves AS MATERIALIZED(
 SELECT m.id,m.event_date,m.movement_type,m.asset_delta_brl
 FROM public.lts_liquidity_movement m
 JOIN public.asset_positions a ON a.id=m.asset_position_id AND a.user_id=m.user_id
 CROSS JOIN anchor x WHERE m.user_id=p_user_id AND m.status='active'
 AND a.asset_name='Cofrinho Itaú' AND a.asset_type='cash_investment'
 AND m.event_date>x.dt AND m.event_date<=p_date
),receipts AS MATERIALIZED(
 SELECT r.* FROM anchor x CROSS JOIN LATERAL public.lts_cofrinho_bank_redemptions_v381(p_user_id,x.dt,p_date)r
),totals AS(
 SELECT x.*,coalesce((SELECT sum(asset_delta_brl)FROM moves),0) movement_delta,
 coalesce((SELECT sum(unrepresented_asset_delta_brl)FROM receipts WHERE NOT representation_conflict),0) receipt_delta,
 coalesce((SELECT bool_or(representation_conflict)FROM receipts),false) conflict FROM anchor x
)
SELECT coalesce((SELECT jsonb_build_object('version','dated-cofrinho-composition-v399','as_of',p_date,
 'has_anchor',true,'complete',NOT conflict,'status',CASE WHEN conflict THEN 'reconciliation_required' ELSE 'dated_anchor_and_distinct_movements' END,
 'asset_name','Cofrinho Itaú','snapshot_date',dt,'snapshot_brl',amount,'lock_key',lock_key,
 'recorded_movement_delta_brl',movement_delta,'unrepresented_redemption_delta_brl',receipt_delta,
 'available_brl',CASE WHEN NOT conflict THEN amount+movement_delta+receipt_delta END,
 'recorded_movements',coalesce((SELECT jsonb_agg(to_jsonb(m)ORDER BY event_date,id)FROM moves m),'[]'),
 'bank_redemptions',coalesce((SELECT jsonb_agg(to_jsonb(r)ORDER BY event_date,staging_id)FROM receipts r),'[]'),
 'fgts_included',false,'bank_cash_event_created',false,'future_position_copied_backwards',false)
 FROM totals),jsonb_build_object('version','dated-cofrinho-composition-v399','as_of',p_date,'has_anchor',false,'complete',false,'available_brl',NULL));
$function$;
REVOKE ALL ON FUNCTION public.lts_cofrinho_composition_v399(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_cofrinho_composition_v399(uuid,date) TO service_role;

DO $patch$
DECLARE signature text;definition text;old_block text;new_block text;changed boolean:=false;
BEGIN
 FOREACH signature IN ARRAY ARRAY['public.lts_browser_flow_v228(date,date)',
 'public.lts_browser_flow_pre_v238(date,date)','public.lts_flow_cache_pre_v240(uuid,date,date)']LOOP
  definition:=pg_get_functiondef(signature::regprocedure);
  IF position('v399-dated-cofrinho-anchor'IN definition)>0 THEN CONTINUE;END IF;
  old_block:=substring(definition FROM $regex$    IF dt>=\(cofrinho->>'as_of'\)::date THEN d0:=[^;]+;
    ELSE
     SELECT coalesce\(sum\(\(x->>'signed_amount'\)::numeric\),0\) INTO asset_net FROM jsonb_array_elements\(added\) x
      WHERE coalesce\(\(x->>'asset_movement'\)::boolean,false\) AND \(x->>'event_date'\)::date<=dt;
     d0:=d0-asset_net;
    END IF;$regex$);
  IF old_block IS NULL THEN RAISE EXCEPTION 'V399 expected D0 source block changed: %',signature;END IF;
  new_block:=$new$    -- v399-dated-cofrinho-anchor: select a position valid for this day.
    cofrinho:=public.lts_cofrinho_composition_v399(u,dt);
    IF coalesce((cofrinho->>'has_anchor')::boolean,false) THEN
     d0:=(cofrinho->>'available_brl')::numeric;
     c:=c||jsonb_build_object('d0_position_basis','dated_cofrinho_anchor_and_distinct_movements',
      'd0_composition',cofrinho);
    ELSE
     -- Preserve history preceding the first validated position.
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;$new$;
  definition:=replace(definition,old_block,new_block);
  EXECUTE definition;changed:=true;
 END LOOP;
 IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;END IF;
END $patch$;
