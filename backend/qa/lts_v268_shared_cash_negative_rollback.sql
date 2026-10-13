BEGIN;
SET LOCAL statement_timeout='25s';SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); qa_idx int; wide jsonb; direct jsonb; sliced jsonb; cached_from date; cached_to date; fresh numeric; unknown_rejected boolean:=false;
BEGIN
 SELECT max(e.idx)+1000 INTO qa_idx FROM public.evento_base e WHERE e.usuario_id=u;
 INSERT INTO public.evento_base(usuario_id,idx,dados) VALUES(u,qa_idx,jsonb_build_object('dia','2030-06-10','conta','Itau','desc','V268 QA backwards-date cutoff','valor',41.23,'efeito','saida'));
 INSERT INTO public.projecao_op(usuario_id,idx_origem,dados) VALUES(u,qa_idx,jsonb_build_object('dia','2030-06-10','conta','Itau','desc','V268 QA backwards-date cutoff','tipo','data','status','ativa','depois',jsonb_build_object('dia','2026-10-13'),'ts',(extract(epoch FROM clock_timestamp())*1000)::bigint));
 SELECT jsonb_agg(to_jsonb(r) ORDER BY source_ref) INTO wide FROM public.lts_corrected_cashflow_fix86_v1(u,date '2013-10-10',date '2031-12-31')r;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(wide)j WHERE j->>'source_ref'='evento_base:'||qa_idx AND j->>'event_date'='2026-10-13') THEN RAISE EXCEPTION 'Wide transformed source absent'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_corrected_cashflow_fix86_v1(u,date '2026-10-13',date '2027-12-31')r WHERE r.source_ref='evento_base:'||qa_idx) THEN RAISE EXCEPTION 'Future original row leaked backwards through covering cache'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') INTO direct FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(u,date '2026-10-13',date '2027-12-31')r;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') INTO sliced FROM public.lts_corrected_cashflow_fix86_v1(u,date '2026-10-13',date '2027-12-31')r;
 IF direct IS DISTINCT FROM sliced THEN RAISE EXCEPTION 'Complete returned fields differ'; END IF;
 UPDATE public.evento_base SET dados=jsonb_set(dados,'{valor}','43.21'::jsonb) WHERE usuario_id=u AND evento_base.idx=qa_idx;
 SELECT signed_amount INTO fresh FROM public.lts_corrected_cashflow_fix86_v1(u,date '2013-10-10',date '2031-12-31')r WHERE r.source_ref='evento_base:'||qa_idx;
 IF fresh IS DISTINCT FROM -43.21 THEN RAISE EXCEPTION 'Source change did not invalidate shared read'; END IF;
 IF EXISTS(SELECT 1 FROM public.lts_corrected_cashflow_fix86_v1(NULL,date '2026-10-13',date '2027-12-31')) THEN RAISE EXCEPTION 'Null owner acquired rows'; END IF;
 BEGIN
  PERFORM * FROM public.lts_corrected_cashflow_fix86_v1(gen_random_uuid(),date '2026-10-13',date '2027-12-31');
 EXCEPTION WHEN foreign_key_violation THEN unknown_rejected:=true;
 END;
 IF NOT unknown_rejected THEN RAISE EXCEPTION 'Expected unchanged fail-closed behavior for nonexistent owner'; END IF;
 PERFORM set_config('lts.v268_negative',jsonb_build_object('pass',true,'backwards_original_cutoff',true,'all_fields_equal',true,'live_source_invalidation',true,'null_owner_empty',true,'nonexistent_owner_fail_closed',true,'mutations','rolled_back')::text,true);
END $qa$;
SELECT current_setting('lts.v268_negative')::jsonb receipt;
ROLLBACK;
