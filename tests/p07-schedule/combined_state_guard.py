"""Reviewed joint-state guard generator. Synthetic fixture inputs only in this package.
This does not replace the complete economic guards or execute any SQL.
"""
import json
import uuid

ORIGINAL_READER_MD5 = '08f44d1c4e33458070d6b63e025f5c5d'
CANDIDATE_READER_MD5 = 'f322c2cf4c7832114612930067ff2ad5'
OWNER_MD5 = '5e133d88399606315302e30389240f8a'

def guard_sql(mode, planned_ids, rule_id):
    if mode not in {'apply', 'recovery'}:
        raise ValueError('Unknown joint operation')
    if len(planned_ids) != 24 or len(set(planned_ids)) != 24:
        raise ValueError('Joint guard requires 24 distinct planned identities')
    for value in planned_ids:
        if str(uuid.UUID(value)) != value:
            raise ValueError('Noncanonical planned UUID')
    if not isinstance(rule_id, str) or not rule_id:
        raise ValueError('A specific rule identity is required')
    quoted_rule = "'" + rule_id.replace("'", "''") + "'"
    return f"""DO $joint_guard$
DECLARE
 v_owner uuid;
 v_reader_hash text;
 v_present integer;
 v_unsuppressed integer;
 v_suppressed integer;
 v_mode text := '{mode}';
 v_rule_id text := {quoted_rule};
 v_ids jsonb := $planned_ids${json.dumps(planned_ids,separators=(',',':'))}$planned_ids$::jsonb;
BEGIN
 IF md5(pg_get_functiondef('public.lts_open_finance_pilot_owner_v1()'::regprocedure)) IS DISTINCT FROM '{OWNER_MD5}' THEN
  RAISE EXCEPTION 'P07_OWNER_CHANGED';
 END IF;
 LOCK TABLE public.financial_events,public.lts_projection_replacement_rule IN ROW EXCLUSIVE MODE;
 v_owner:=public.lts_open_finance_pilot_owner_v1();
 IF v_owner IS NULL THEN RAISE EXCEPTION 'P07_OWNER_MISSING'; END IF;
 -- Preserve economic lock order: the rule precedes planned new rows.
 PERFORM 1 FROM public.lts_projection_replacement_rule WHERE user_id=v_owner AND id=v_rule_id FOR UPDATE;
 PERFORM 1 FROM public.financial_events WHERE user_id=v_owner AND id IN(SELECT value::uuid FROM jsonb_array_elements_text(v_ids)) FOR UPDATE;
 SELECT count(*),count(*) FILTER(WHERE is_suppressed IS FALSE),count(*) FILTER(WHERE is_suppressed IS TRUE)
 INTO v_present,v_unsuppressed,v_suppressed
 FROM public.financial_events
 WHERE user_id=v_owner AND id IN(SELECT value::uuid FROM jsonb_array_elements_text(v_ids));
 SELECT md5(pg_get_functiondef('public.lts_documentary_commitments_v1(uuid)'::regprocedure)) INTO v_reader_hash;
 IF v_mode='apply' THEN
  IF NOT coalesce((v_reader_hash='{ORIGINAL_READER_MD5}' AND v_present=0)
   OR (v_reader_hash='{CANDIDATE_READER_MD5}' AND v_present=24 AND v_unsuppressed=24),false) THEN
   RAISE EXCEPTION 'P07_COMBINED_STATE_MISMATCH';
  END IF;
 ELSE
  IF NOT coalesce((v_reader_hash='{CANDIDATE_READER_MD5}' AND v_present=24 AND v_unsuppressed=24)
   OR (v_reader_hash='{ORIGINAL_READER_MD5}' AND v_present=24 AND v_suppressed=24),false) THEN
   RAISE EXCEPTION 'P07_COMBINED_STATE_MISMATCH';
  END IF;
 END IF;
END $joint_guard$;
"""
