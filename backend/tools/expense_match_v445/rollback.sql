-- Reverse only the exact V445 read-layer integration; no source/cache rows deleted.
-- Coordinate with other deployments: refuses partial integration or baseline drift.
BEGIN;
DO $rollback$
DECLARE body text; integrated text; original text;
 expected_md5 constant text := '24c9b55478e02403bdca12003f5f22fe';
BEGIN
 body:=pg_get_functiondef('public.lts_expense_rows_v230_baseline(uuid,date,date)'::regprocedure);
 -- Verified original is a harmless no-op on repeated rollback.
 IF md5(body)=expected_md5 THEN RETURN; END IF;
 integrated:=$integrated$original_bank_context AS MATERIALIZED(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to)), matched_bank_context AS MATERIALIZED(select m.* from public.lts_expense_matched_bank_rows_v445(p_user_id,p_from,p_to) m where not exists(select 1 from original_bank_context n where n.id=m.id)), new_bank_raw as materialized(select * from original_bank_context UNION ALL select id,event_date,signed_amount,description,bank,category from matched_bank_context)$integrated$;
 original:=$original$new_bank_raw as materialized(select * from public.lts_v229_new_bank_rows(p_user_id,p_from,p_to))$original$;
 IF length(body)-length(replace(body,integrated,''))<>length(integrated) THEN
  RAISE EXCEPTION 'Rollback rejected partial integration or drift';
 END IF;
 body:=replace(body,integrated,original);
 integrated:=$integrated$select 'lts_open_finance_staging',n.id::text,coalesce(mc.operational_event->>'description',n.description),n.category,case when mc.operational_event->>'center_cost' in ('Lucas','Larissa','Benjamin','Rafiki') then mc.operational_event->>'center_cost' end,null,coalesce(mc.operational_event,'{}'::jsonb),1 from new_bank n left join matched_bank_context mc on mc.id=n.id$integrated$;
 original:=$original$select 'lts_open_finance_staging',n.id::text,n.description,n.category,null,null,'{}'::jsonb,1 from new_bank n$original$;
 IF length(body)-length(replace(body,integrated,''))<>length(integrated) THEN
  RAISE EXCEPTION 'Rollback rejected partial integration or drift';
 END IF;
 body:=replace(body,integrated,original);
 integrated:=$integrated$d.beneficiary person_decision,coalesce(d.property_code,case when b.source_table='lts_open_finance_staging' then s.meta->>'property_code' end) property_decision,d.category_label category_decision$integrated$;
 original:=$original$d.beneficiary person_decision,d.property_code property_decision,d.category_label category_decision$original$;
 IF length(body)-length(replace(body,integrated,''))<>length(integrated) THEN
  RAISE EXCEPTION 'Rollback rejected partial integration or drift';
 END IF;
 body:=replace(body,integrated,original);
 IF md5(body)<>expected_md5 THEN RAISE EXCEPTION 'Rollback rejected changed baseline outside integration'; END IF;
 EXECUTE body;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 IF NOT FOUND THEN RAISE EXCEPTION 'Missing derived-read epoch'; END IF;
 -- Helper intentionally remains installed with its existing revoked execution rights.
END $rollback$;
COMMIT;
