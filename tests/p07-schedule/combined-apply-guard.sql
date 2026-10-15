DO $joint_guard$
DECLARE
 v_owner uuid;
 v_reader_hash text;
 v_present integer;
 v_unsuppressed integer;
 v_suppressed integer;
 v_mode text := 'apply';
 v_rule_id text := 'replace_qa_legacy_with_synthetic_contract';
 v_ids jsonb := $planned_ids$["f0000000-0000-4000-8000-000000000088","f0000000-0000-4000-8000-000000000089","f0000000-0000-4000-8000-00000000008a","f0000000-0000-4000-8000-00000000008b","f0000000-0000-4000-8000-00000000008c","f0000000-0000-4000-8000-00000000008d","f0000000-0000-4000-8000-00000000008e","f0000000-0000-4000-8000-00000000008f","f0000000-0000-4000-8000-000000000090","f0000000-0000-4000-8000-000000000091","f0000000-0000-4000-8000-000000000092","f0000000-0000-4000-8000-000000000093","f0000000-0000-4000-8000-000000000094","f0000000-0000-4000-8000-000000000095","f0000000-0000-4000-8000-000000000096","f0000000-0000-4000-8000-000000000097","f0000000-0000-4000-8000-000000000098","f0000000-0000-4000-8000-000000000099","f0000000-0000-4000-8000-00000000009a","f0000000-0000-4000-8000-00000000009b","f0000000-0000-4000-8000-00000000009c","f0000000-0000-4000-8000-00000000009d","f0000000-0000-4000-8000-00000000009e","f0000000-0000-4000-8000-00000000009f"]$planned_ids$::jsonb;
BEGIN
 IF md5(pg_get_functiondef('public.lts_open_finance_pilot_owner_v1()'::regprocedure)) IS DISTINCT FROM '5e133d88399606315302e30389240f8a' THEN
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
  IF NOT coalesce((v_reader_hash='08f44d1c4e33458070d6b63e025f5c5d' AND v_present=0)
   OR (v_reader_hash='f322c2cf4c7832114612930067ff2ad5' AND v_present=24 AND v_unsuppressed=24),false) THEN
   RAISE EXCEPTION 'P07_COMBINED_STATE_MISMATCH';
  END IF;
 ELSE
  IF NOT coalesce((v_reader_hash='f322c2cf4c7832114612930067ff2ad5' AND v_present=24 AND v_unsuppressed=24)
   OR (v_reader_hash='08f44d1c4e33458070d6b63e025f5c5d' AND v_present=24 AND v_suppressed=24),false) THEN
   RAISE EXCEPTION 'P07_COMBINED_STATE_MISMATCH';
  END IF;
 END IF;
END $joint_guard$;
