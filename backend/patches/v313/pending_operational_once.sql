-- Materialize the shared operational read before joining its events to bank anchors.
-- Keep all receipt proofs, source decisions and pending-projection arithmetic intact.
DO $patch$
DECLARE target oid:='public.lts_pending_projections_v233(uuid)'::regprocedure;
 definition text;replacement text;before_attributes jsonb;after_attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,before_attributes FROM pg_proc p WHERE p.oid=target;
 IF md5(definition)='36e3321d535eb10a5e04a376d635a2a6' THEN RETURN;END IF;
 IF md5(definition)<>'ec25065ddf4749c747127a41c3eb8764' THEN RAISE EXCEPTION 'Pending projection definition changed';END IF;
 replacement:=replace(definition,'), candidates AS MATERIALIZED (',
 $text$), operational AS MATERIALIZED (
 SELECT public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date) payload
 WHERE EXISTS(SELECT 1 FROM anchors)
), candidates AS MATERIALIZED ($text$);
 replacement:=replace(replacement,
 'FROM jsonb_array_elements(public.lts_flow_operational_read_v229(p_user_id,(SELECT min(dt)+1 FROM anchors),current_date)) x',
 'FROM operational op CROSS JOIN LATERAL jsonb_array_elements(op.payload) x');
 IF md5(replacement)<>'36e3321d535eb10a5e04a376d635a2a6' THEN RAISE EXCEPTION 'Unexpected pending projection transformation';END IF;
 EXECUTE replacement;
 SELECT to_jsonb(p)-'prosrc' INTO after_attributes FROM pg_proc p WHERE p.oid=target;
 IF after_attributes IS DISTINCT FROM before_attributes
 OR md5(pg_get_functiondef(target))<>'36e3321d535eb10a5e04a376d635a2a6' THEN RAISE EXCEPTION 'Pending reader metadata changed';END IF;
END $patch$;
