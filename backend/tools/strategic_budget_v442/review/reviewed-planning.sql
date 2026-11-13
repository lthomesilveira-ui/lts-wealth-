-- Separate reviewed proposals from owner-approved targets. No writer or source mutation.
CREATE OR REPLACE FUNCTION lts_budget_private_v441.reviewed_planning_v442(p_plan jsonb,p_epoch bigint,p_year integer)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $fn$
DECLARE m text;c text;v jsonb;out_months jsonb:='{}';month_rows jsonb;status text;
BEGIN
 IF p_plan IS NULL OR jsonb_typeof(p_plan) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('status','missing','months','{}'::jsonb); END IF;
 IF p_plan->>'source_epoch' IS NULL OR (p_plan->>'source_epoch')!~'^[0-9]+$' OR (p_plan->>'source_epoch')::numeric IS DISTINCT FROM p_epoch::numeric THEN
 RETURN jsonb_build_object('status','stale','months','{}'::jsonb); END IF;
 IF jsonb_typeof(p_plan->'months') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid reviewed proposal months'; END IF;
 FOR m,month_rows IN SELECT * FROM jsonb_each(p_plan->'months') LOOP
 IF m!~('^'||p_year::text||'-(0[1-9]|1[0-2])$') OR jsonb_typeof(month_rows) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid reviewed proposal period'; END IF;
 FOR c,v IN SELECT * FROM jsonb_each(month_rows) LOOP
 IF length(btrim(c)) NOT BETWEEN 1 AND 120 OR jsonb_typeof(v) IS DISTINCT FROM 'object'
 OR v->>'status' IS DISTINCT FROM 'reviewed_proposal' OR jsonb_typeof(v->'target') IS DISTINCT FROM 'number'
 OR (v->>'target')!~'^[0-9]+([.][0-9]{1,2})?$' OR (v->>'target')::numeric>100000000
 OR coalesce(length(btrim(v->>'reason')),0)=0 OR jsonb_typeof(v->'evidence') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid reviewed proposal'; END IF;
 IF jsonb_array_length(v->'evidence')=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(v->'evidence') e WHERE jsonb_typeof(e) IS DISTINCT FROM 'string' OR length(btrim(e#>>'{}'))=0) THEN RAISE EXCEPTION 'Missing proposal evidence'; END IF;
 END LOOP;
 out_months:=out_months||jsonb_build_object(m,month_rows);
 END LOOP;
 RETURN jsonb_build_object('status','current','source_epoch',p_epoch,'months',out_months);
END $fn$;
REVOKE ALL ON FUNCTION lts_budget_private_v441.reviewed_planning_v442(jsonb,bigint,integer) FROM PUBLIC;
