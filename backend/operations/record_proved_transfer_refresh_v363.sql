-- Supply private transaction-local lts.transfer_refresh.* settings.
-- The caller owns BEGIN/ROLLBACK for trial, then BEGIN/COMMIT for activation.
DO $record$
DECLARE
 u uuid:=current_setting('lts.transfer_refresh.owner_id')::uuid;
 did uuid:=current_setting('lts.transfer_refresh.debit_id')::uuid;
 cid uuid:=current_setting('lts.transfer_refresh.credit_id')::uuid;
 prior_id uuid:=current_setting('lts.transfer_refresh.prior_credit_observation_id')::uuid;
 aid bigint:=current_setting('lts.transfer_refresh.confirmation_audit_id')::bigint;
 dh text:=current_setting('lts.transfer_refresh.debit_raw_hash');
 ch text:=current_setting('lts.transfer_refresh.credit_raw_hash');
 ph text:=current_setting('lts.transfer_refresh.prior_credit_raw_hash');
 d public.lts_open_finance_staging%rowtype;c public.lts_open_finance_staging%rowtype;
 p public.lts_open_finance_observation%rowtype;a public.audit_log%rowtype;
 proof public.lts_reconciliation_evidence%rowtype;existing public.lts_reconciliation_evidence%rowtype;
 ref text;before_sources text;before_events text;before_expenses jsonb;
BEGIN
 SELECT * INTO STRICT d FROM public.lts_open_finance_staging WHERE user_id=u AND id=did FOR SHARE;
 SELECT * INTO STRICT c FROM public.lts_open_finance_staging WHERE user_id=u AND id=cid FOR SHARE;
 SELECT * INTO STRICT p FROM public.lts_open_finance_observation WHERE user_id=u AND id=prior_id FOR SHARE;
 SELECT * INTO STRICT a FROM public.audit_log WHERE user_id=u AND id=aid FOR SHARE;
 IF d.raw_hash IS DISTINCT FROM dh OR c.raw_hash IS DISTINCT FROM ch OR p.raw_hash IS DISTINCT FROM ph
 THEN RAISE EXCEPTION 'V363_REVIEWED_SOURCE_CHANGED';END IF;
 ref:='proved-transfer-refresh-v363:'||did::text||':'||cid::text;
 proof.user_id:=u;proof.evidence_date:=d.posting_date;proof.account:='Transferência própria';
 proof.amount:=c.signed_amount;proof.description:='Transferência própria comprovada pelo histórico bancário e destino confirmado';
 proof.evidence_type:='previously_proved_transfer_refresh_v363';proof.source_ref:=ref;proof.status:='documented';proof.created_at:=now();
 proof.metadata:=jsonb_build_object('version','previously-proved-transfer-v363',
 'basis','confirmed_destination_and_prior_same_owner_posted_pair','owner_confirmation_scope','destination_confirmation_only',
 'debit_id',did,'credit_id',cid,'debit_raw_hash',dh,'credit_raw_hash',ch,
 'prior_credit_observation_id',prior_id,'prior_credit_raw_hash',ph,'confirmation_audit_id',aid,
 'incoming_payer_conflict_preserved',true,'raw_bank_data_changed',false,'consolidated_cash_effect',0);
 SELECT * INTO existing FROM public.lts_reconciliation_evidence WHERE user_id=u AND source_ref=ref;
 IF FOUND THEN
  IF(SELECT count(*)FROM public.lts_reconciliation_evidence WHERE user_id=u AND source_ref=ref)<>1
   OR existing.metadata IS DISTINCT FROM proof.metadata OR existing.status<>'documented'
   OR (SELECT count(*)FROM public.lts_previously_proved_transfer_pairs_v363(u)q WHERE q.debit_id=did AND q.credit_id=cid)<>1
  THEN RAISE EXCEPTION 'V363_EXISTING_PROOF_DIFFERS';END IF;
  RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM public.lts_reconciliation_evidence e WHERE e.user_id=u
 AND e.evidence_type='previously_proved_transfer_refresh_v363' AND e.status='documented'
 AND(e.metadata->>'debit_id'=did::text OR e.metadata->>'credit_id'=cid::text))
 THEN RAISE EXCEPTION 'V363_SOURCE_ALREADY_LINKED';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(s)ORDER BY s.id)::text,'[]'))INTO before_sources FROM public.lts_open_finance_staging s WHERE s.user_id=u;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(e)ORDER BY e.id)::text,'[]'))INTO before_events FROM public.financial_events e WHERE e.user_id=u;
 SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY to_jsonb(x)::text),'[]')INTO before_expenses
 FROM public.lts_v229_expense_rows(u,'2013-01-01',current_date)x;
 INSERT INTO public.lts_reconciliation_evidence(user_id,evidence_date,account,amount,description,evidence_type,source_ref,status,metadata,created_at)
 VALUES(proof.user_id,proof.evidence_date,proof.account,proof.amount,proof.description,proof.evidence_type,proof.source_ref,proof.status,proof.metadata,proof.created_at);
 IF (SELECT count(*)FROM public.lts_previously_proved_transfer_pairs_v363(u)q WHERE q.debit_id=did AND q.credit_id=cid)<>1
 OR (SELECT count(*)FROM public.lts_owner_confirmed_transfer_pairs_v263(u)q WHERE q.debit_id=did AND q.credit_id=cid)<>1
 THEN RAISE EXCEPTION 'V363_PRIOR_DOCUMENTARY_PAIR_REJECTED';END IF;
 IF before_sources IS DISTINCT FROM(SELECT md5(coalesce(jsonb_agg(to_jsonb(s)ORDER BY s.id)::text,'[]'))FROM public.lts_open_finance_staging s WHERE s.user_id=u)
 OR before_events IS DISTINCT FROM(SELECT md5(coalesce(jsonb_agg(to_jsonb(e)ORDER BY e.id)::text,'[]'))FROM public.financial_events e WHERE e.user_id=u)
 OR before_expenses IS DISTINCT FROM(SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY to_jsonb(x)::text),'[]')FROM public.lts_v229_expense_rows(u,'2013-01-01',current_date)x)
 THEN RAISE EXCEPTION 'V363_RAW_SOURCES_OR_EXPENSES_CHANGED';END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $record$;
