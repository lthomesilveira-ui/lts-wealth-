-- V256: linear JSON assembly and one classification lookup per event.
DO $v256$
DECLARE s text; needle text;
BEGIN
 s:=pg_get_functiondef('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'8824224c21aaf1cc83623d9bd4294ac2' THEN RAISE EXCEPTION 'V256_GUARD_SOURCE_CHANGED';END IF;
 needle:=$old$ f jsonb:=p_flow; d jsonb; old_day jsonb; days jsonb:='[]'; bank_name text;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_DECLARATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ f jsonb:=p_flow; d jsonb; old_day jsonb; day_rows_v256 jsonb[]:=ARRAY[]::jsonb[]; bank_name text;$new$);
 needle:=$old$  days:=days||jsonb_build_array(d);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_APPEND_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$  day_rows_v256:=array_append(day_rows_v256,d);$new$);
 needle:=$old$ RETURN jsonb_set(f,'{current_future,days}',days);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_RETURN_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ RETURN jsonb_set(f,'{current_future,days}',to_jsonb(day_rows_v256));$new$);
 EXECUTE s;
 s:=pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'d7b44020c937ef74e4698437af9497a9' THEN RAISE EXCEPTION 'V256_CLASSIFICATION_SOURCE_CHANGED';END IF;
 needle:=$old$ LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_CLASSIFICATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ -- Keep this expression behind a lateral evaluation barrier: the same
 -- classification JSON is consumed by several output fields.
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL OFFSET 0) k ON true;$new$);
 EXECUTE s;
END $v256$;
