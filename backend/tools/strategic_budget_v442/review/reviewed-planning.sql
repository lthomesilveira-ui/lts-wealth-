-- Separate reviewed proposals from owner-approved targets. No writer or source mutation.
CREATE OR REPLACE FUNCTION lts_budget_private_v441.reviewed_planning_v442(p_plan jsonb,p_epoch bigint,p_year integer)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $fn$
DECLARE m text;c text;v jsonb;out_months jsonb:='{}';month_rows jsonb;status text;w jsonb;field text;seen text[]:='{}';identity text;payroll jsonb:='[]';links jsonb:='[]';
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
 -- Exact, dated source proof only. Lender/category names never imply withholding.
 IF p_plan ? 'payroll_withholding' THEN
 IF jsonb_typeof(p_plan->'payroll_withholding') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid payroll proof'; END IF;
 FOR w IN SELECT * FROM jsonb_array_elements(p_plan->'payroll_withholding') LOOP
 IF jsonb_typeof(w) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid payroll proof'; END IF;
 FOREACH field IN ARRAY ARRAY['source','source_ref','date'] LOOP
 IF jsonb_typeof(w->field) IS DISTINCT FROM 'string' OR length(btrim(w->>field))=0 THEN RAISE EXCEPTION 'Incomplete payroll identity'; END IF;
 END LOOP;
 IF (w->>'date')!~('^'||p_year::text||'-(0[1-9]|1[0-2])-[0-9]{2}$') THEN RAISE EXCEPTION 'Invalid payroll period'; END IF;
 PERFORM (w->>'date')::date;
 FOREACH field IN ARRAY ARRAY['amount','base_income','net_income'] LOOP
 IF jsonb_typeof(w->field) IS DISTINCT FROM 'number' OR (w->>field)!~'^[0-9]+([.][0-9]{1,2})?$' OR (w->>field)::numeric>100000000 THEN RAISE EXCEPTION 'Invalid payroll amount'; END IF;
 END LOOP;
 IF (w->>'amount')::numeric<=0 OR (w->>'base_income')::numeric-(w->>'net_income')::numeric IS DISTINCT FROM (w->>'amount')::numeric THEN RAISE EXCEPTION 'Unreconciled payroll deduction'; END IF;
 IF jsonb_typeof(w->'evidence') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Missing payroll evidence'; END IF;
 IF jsonb_array_length(w->'evidence')=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(w->'evidence') e WHERE jsonb_typeof(e) IS DISTINCT FROM 'string' OR length(btrim(e#>>'{}'))=0) THEN RAISE EXCEPTION 'Missing payroll evidence'; END IF;
 identity:=jsonb_build_array(w->>'source',w->>'source_ref',w->>'date')::text;
 IF identity=ANY(seen) THEN RAISE EXCEPTION 'Duplicate payroll proof'; END IF;
 seen:=array_append(seen,identity);payroll:=payroll||jsonb_build_array(w);
 END LOOP;
 END IF;
 -- Source-scoped label reconciliation; no global category alias and no source writes.
 seen:='{}';
 IF p_plan ? 'source_links' THEN
 IF jsonb_typeof(p_plan->'source_links') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid source links'; END IF;
 FOR w IN SELECT * FROM jsonb_array_elements(p_plan->'source_links') LOOP
 IF jsonb_typeof(w) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid source link'; END IF;
 FOREACH field IN ARRAY ARRAY['source_table','source_ref','event_date','competence_month','from_category','to_category'] LOOP
 IF jsonb_typeof(w->field) IS DISTINCT FROM 'string' OR length(btrim(w->>field))=0 THEN RAISE EXCEPTION 'Incomplete source link'; END IF;
 END LOOP;
 IF length(w->>'to_category')>120 OR (w->>'event_date')!~'^\d{4}-(0[1-9]|1[0-2])-[0-9]{2}$' OR (w->>'competence_month')!~'^\d{4}-(0[1-9]|1[0-2])-01$' THEN RAISE EXCEPTION 'Invalid source-link date or category'; END IF;
 PERFORM (w->>'event_date')::date;PERFORM (w->>'competence_month')::date;
 IF jsonb_typeof(w->'amount') IS DISTINCT FROM 'number' OR (w->>'amount')!~'^-?[0-9]+([.][0-9]{1,2})?$' OR abs((w->>'amount')::numeric)>100000000 THEN RAISE EXCEPTION 'Invalid source-link amount'; END IF;
 IF jsonb_typeof(w->'evidence') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Missing source-link evidence'; END IF;
 IF jsonb_array_length(w->'evidence')=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(w->'evidence') e WHERE jsonb_typeof(e) IS DISTINCT FROM 'string' OR length(btrim(e#>>'{}'))=0) THEN RAISE EXCEPTION 'Missing source-link evidence'; END IF;
 identity:=jsonb_build_array(w->>'source_table',w->>'source_ref',w->>'event_date',w->>'competence_month')::text;
 IF identity=ANY(seen) THEN RAISE EXCEPTION 'Duplicate source link'; END IF;
 seen:=array_append(seen,identity);links:=links||jsonb_build_array(w);
 END LOOP;
 END IF;
 RETURN jsonb_build_object('status','current','source_epoch',p_epoch,'months',out_months,'payroll_withholding',payroll,'source_links',links);
END $fn$;
REVOKE ALL ON FUNCTION lts_budget_private_v441.reviewed_planning_v442(jsonb,bigint,integer) FROM PUBLIC;

CREATE OR REPLACE FUNCTION lts_budget_private_v441.reviewed_category_v442(p_row jsonb,p_links jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO '' AS $fn$
 SELECT coalesce((SELECT l->>'to_category' FROM jsonb_array_elements(coalesce(p_links,'[]'::jsonb)) l
 WHERE l->>'source_table'=p_row->>'source_table' AND l->>'source_ref'=p_row->>'source_ref'
 AND l->>'event_date'=p_row->>'event_date' AND l->>'competence_month'=p_row->>'competence_month'
 AND l->>'from_category'=p_row->>'category' AND (l->>'amount')::numeric=(p_row->>'amount')::numeric),p_row->>'category');
$fn$;
REVOKE ALL ON FUNCTION lts_budget_private_v441.reviewed_category_v442(jsonb,jsonb) FROM PUBLIC;
