-- A signed amount correction does not revoke the original workbook identity.
-- Keep the original equality; accept only the explicit original->signed mapping
-- introduced by this narrowly verified documentary batch.
DO $patch$
DECLARE target regprocedure:='public.lts_v229_expense_rows_pre_v238(uuid,date,date)'::regprocedure;
 old_definition text;next_definition text;attributes jsonb;
 old_slot text:='AND e.event_date=r.event_date AND round(e.amount,2)=round(r.amount,2)';
 new_slot text:=$slot$AND e.event_date=r.event_date AND (round(e.amount,2)=round(r.amount,2)
 OR EXISTS(SELECT 1 FROM public.lts_expense_documentary_amount_override signed_identity
 WHERE signed_identity.user_id=p_user_id AND signed_identity.source_table=r.source_table
 AND signed_identity.source_ref=r.source_ref AND signed_identity.event_date=r.event_date
 AND signed_identity.status='documented'
 AND signed_identity.source_document='Controle_Financeiro_v16.xlsm'
 AND signed_identity.source_sheet='Pagamentos e Recebimentos'
 AND signed_identity.evidence_note LIKE '%"schema": "documented-sign-v347"%'
 AND signed_identity.imported_amount>0 AND signed_identity.documented_signed_amount<0
 AND signed_identity.imported_amount=-signed_identity.documented_signed_amount
 AND round(signed_identity.imported_amount,2)=round(e.amount,2)
 AND round(signed_identity.documented_signed_amount,2)=round(r.amount,2)))$slot$;
BEGIN
 SELECT pg_get_functiondef(oid),to_jsonb(p)-'prosrc'INTO old_definition,attributes FROM pg_proc p WHERE oid=target;
 IF position('signed_identity'IN old_definition)>0 THEN
  IF md5(replace(old_definition,new_slot,old_slot))<>'ec2b3c244ae440d83e526752bc86f2d4'THEN RAISE EXCEPTION 'V347_REPLAY_SOURCE_CHANGED';END IF;RETURN;
 END IF;
 IF md5(old_definition)<>'ec2b3c244ae440d83e526752bc86f2d4'THEN RAISE EXCEPTION 'V347_IDENTITY_SOURCE_LEASE_CHANGED';END IF;
 next_definition:=replace(old_definition,old_slot,new_slot);
 IF next_definition=old_definition THEN RAISE EXCEPTION 'V347_IDENTITY_SLOT_MISSING';END IF;
 EXECUTE next_definition;
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)THEN RAISE EXCEPTION 'V347_IDENTITY_ATTRIBUTES_CHANGED';END IF;
END $patch$;
