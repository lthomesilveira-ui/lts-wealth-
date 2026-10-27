-- Correct documentary interpretation only. Original events and spending stay intact.
CREATE FUNCTION public.lts_cipo_consortium_source_v358(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $function$
 WITH candidate AS MATERIALIZED(
  SELECT o.*,CASE WHEN pg_catalog.pg_input_is_valid(o.evidence_note,'jsonb') THEN o.evidence_note::jsonb END m
  FROM public.lts_expense_documentary_amount_override o
  WHERE o.user_id=p_user_id AND o.status='documented' AND o.source_table='evento_base'
 ),valid AS(
  SELECT c.*,b.dados raw,old.id old_id
  FROM candidate c JOIN public.evento_base b ON b.usuario_id=c.user_id AND b.idx::text=c.source_ref
  JOIN public.lts_expense_documentary_amount_override old ON old.user_id=c.user_id
   AND old.source_table=c.source_table AND old.source_ref=c.m->>'superseded_source_ref'
   AND old.id::text=c.m->>'superseded_override_id' AND old.status='superseded'
  JOIN public.evento_base old_raw ON old_raw.usuario_id=old.user_id AND old_raw.idx::text=old.source_ref
  WHERE c.m->>'schema'='documented-sign-v347' AND c.m->>'batch'='cipo-consortium-v358'
   AND b.dados->>'desc'=c.description_raw AND c.description_raw='Consórcio - O Parque - Itaú'
   AND b.dados->>'dia'=c.event_date::text AND b.dados->>'efeito'='saida'
   AND jsonb_typeof(b.dados->'valor')='number' AND(b.dados->>'valor')::numeric=c.imported_amount
   AND c.imported_amount>0 AND c.documented_signed_amount=-c.imported_amount
   AND old_raw.dados->>'desc'=old.description_raw AND old_raw.dados->>'dia'=old.event_date::text
   AND jsonb_typeof(old_raw.dados->'valor')='number' AND(old_raw.dados->>'valor')::numeric=old.imported_amount
   AND NOT EXISTS(SELECT 1 FROM public.lts_v178_review_decision d WHERE d.user_id=c.user_id
    AND d.source_table=c.source_table AND d.source_ref IN(c.source_ref,old.source_ref))
   AND jsonb_typeof(c.m->'workbook_evidence')='array' AND jsonb_array_length(c.m->'workbook_evidence')=2
   AND(SELECT count(DISTINCT x->>'file')FROM jsonb_array_elements(c.m->'workbook_evidence')x)=2
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.m->'workbook_evidence')x
    WHERE x->>'sheet'IS DISTINCT FROM'Pagamentos e Recebimentos'
     OR x->>'date'IS DISTINCT FROM c.event_date::text OR x->>'description'IS DISTINCT FROM c.description_raw
     OR jsonb_typeof(x->'signed_amount')IS DISTINCT FROM'number'
     OR(x->>'signed_amount')::numeric IS DISTINCT FROM c.documented_signed_amount
     OR coalesce(x->>'sha256','')!~'^[0-9a-f]{64}$')
 )SELECT CASE WHEN count(*)=1 THEN jsonb_build_object('status','verified_original_signed_rows',
  'source_ref',min(source_ref),'event_date',min(event_date),'signed_amount',min(documented_signed_amount),
  'workbook_evidence',(jsonb_agg(m->'workbook_evidence'))->0,
  'superseded_source_ref',min(m->>'superseded_source_ref'),
  'replaced_source_evidence',(jsonb_agg(m->'replaced_source_evidence'))->0,
  'snapshot_scope',(jsonb_agg(m->'snapshot_scope'))->0) ELSE NULL END FROM valid;
$function$;

CREATE FUNCTION public.lts_cipo_consortium_presentation_v358(p_reconciliation jsonb,p_source jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $function$
DECLARE j jsonb:=p_reconciliation;c jsonb;note text;
BEGIN
 IF p_source->>'status'IS DISTINCT FROM'verified_original_signed_rows'
 OR jsonb_typeof(j#>'{consortium,itau_ledger}')IS DISTINCT FROM'number'
 OR jsonb_typeof(j#>'{consortium,itau_source}')IS DISTINCT FROM'number'
 OR abs((j#>>'{consortium,itau_ledger}')::numeric-(j#>>'{consortium,itau_source}')::numeric)>.005
 THEN RETURN j;END IF;
 note:='O resumo inclui as parcelas positivas e o ajuste negativo registrado em outra linha da planilha. O sinal e a identidade foram conferidos nos dois arquivos originais; não é uma nova movimentação bancária.';
 c:=j->'consortium'||jsonb_build_object('itau_resolution_status','original_signed_rows_verified',
  'reconciliation_status','cash_contributions_reconciled_card_detail_separate',
  'itau_source_pattern_note',note,'itau_source_audit',p_source);
 j:=jsonb_set(j,'{consortium}',c);
 j:=jsonb_set(j,'{components}',coalesce((SELECT jsonb_agg(x||CASE WHEN x->>'id'='cipo_src_cc_consorcio_itau'
  THEN jsonb_build_object('evidence_note',note) ELSE'{}'::jsonb END ORDER BY ord)
  FROM jsonb_array_elements(j->'components')WITH ORDINALITY a(x,ord)),'[]'::jsonb));
 RETURN j;
END $function$;

CREATE FUNCTION public.lts_apply_cipo_consortium_source_v358(p_user_id uuid,p_manifest jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $function$
DECLARE old public.lts_expense_documentary_amount_override%ROWTYPE;old_raw record;new_raw record;
 old_ref text:=p_manifest#>>'{replace,source_ref}';new_ref text:=p_manifest#>>'{correct,source_ref}';
 target_date date;target_amount numeric;new_id bigint;m jsonb;proof jsonb;replacement jsonb;n integer;
BEGIN
 IF p_manifest->>'user_id'IS DISTINCT FROM p_user_id::text OR old_ref IS NULL OR new_ref IS NULL OR old_ref=new_ref
 THEN RAISE EXCEPTION 'V358_INVALID_OWNER_OR_IDENTITY';END IF;
 SELECT * INTO old FROM public.lts_expense_documentary_amount_override
 WHERE user_id=p_user_id AND source_table='evento_base'AND source_ref=old_ref FOR UPDATE;
 IF NOT FOUND OR old.status<>'documented'OR md5(to_jsonb(old)::text)IS DISTINCT FROM p_manifest#>>'{replace,row_digest}'
 THEN RAISE EXCEPTION 'V358_REPLACEMENT_LEASE_CHANGED';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_expense_documentary_amount_override WHERE user_id=p_user_id AND source_table='evento_base'AND source_ref=new_ref)
 THEN RAISE EXCEPTION 'V358_TARGET_ALREADY_EXISTS: inspect state before retry';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v178_review_decision WHERE user_id=p_user_id AND source_table='evento_base'AND source_ref IN(old_ref,new_ref))
 THEN RAISE EXCEPTION 'V358_OWNER_DECISION_REQUIRES_REVIEW';END IF;
 SELECT * INTO old_raw FROM public.evento_base WHERE usuario_id=p_user_id AND idx::text=old_ref;
 SELECT * INTO new_raw FROM public.evento_base WHERE usuario_id=p_user_id AND idx::text=new_ref;
 IF old_raw.dados->>'desc'IS DISTINCT FROM'Consórcio - O Parque - Itaú'
 OR new_raw.dados->>'desc'IS DISTINCT FROM old_raw.dados->>'desc'
 OR old_raw.dados->>'dia'IS DISTINCT FROM old.event_date::text
 OR(old_raw.dados->>'valor')::numeric IS DISTINCT FROM old.imported_amount
 OR old.imported_amount<=0 OR old.documented_signed_amount>=0
 OR new_raw.dados->>'efeito'IS DISTINCT FROM'saida'
 OR jsonb_typeof(new_raw.dados->'valor')IS DISTINCT FROM'number'
 OR NOT coalesce(pg_catalog.pg_input_is_valid(new_raw.dados->>'dia','date'),false)
 THEN RAISE EXCEPTION 'V358_RAW_SOURCE_CHANGED';END IF;
 target_date:=(new_raw.dados->>'dia')::date;target_amount:=-(new_raw.dados->>'valor')::numeric;
 IF target_amount>=0 THEN RAISE EXCEPTION 'V358_INVALID_TARGET_SIGN';END IF;
 proof:=p_manifest#>'{correct,workbook_evidence}';replacement:=p_manifest#>'{replace,workbook_evidence}';
 FOR m IN SELECT x FROM(VALUES(proof),(replacement))a(x)LOOP
  IF jsonb_typeof(m)IS DISTINCT FROM'array'OR jsonb_array_length(m)<>2
   OR(SELECT count(DISTINCT x->>'file')FROM jsonb_array_elements(m)x)<>2
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(m)x WHERE coalesce(x->>'sha256','')!~'^[0-9a-f]{64}$'
    OR x->>'sheet'IS DISTINCT FROM'Pagamentos e Recebimentos'OR coalesce(x->>'row','')!~'^[1-9][0-9]*$'
    OR x->>'description'IS DISTINCT FROM old.description_raw OR jsonb_typeof(x->'signed_amount')IS DISTINCT FROM'number')
  THEN RAISE EXCEPTION 'V358_INCOMPLETE_WORKBOOK_EVIDENCE';END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(proof)x WHERE(x->>'signed_amount')::numeric<>target_amount OR x->>'date'IS DISTINCT FROM target_date::text)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(replacement)x WHERE(x->>'signed_amount')::numeric<>old.imported_amount OR x->>'date'IS DISTINCT FROM old.event_date::text)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(proof)x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(replacement)y WHERE x->>'file'=y->>'file'AND x->>'sha256'=y->>'sha256'))
 THEN RAISE EXCEPTION 'V358_WORKBOOK_IDENTITY_OR_SIGN_MISMATCH';END IF;
 UPDATE public.lts_expense_documentary_amount_override SET status='superseded',updated_at=now()WHERE id=old.id;
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>1 THEN RAISE EXCEPTION 'V358_REPLACEMENT_COUNT';END IF;
 m:=jsonb_build_object('schema','documented-sign-v347','batch','cipo-consortium-v358',
  'workbook_evidence',proof,'replaced_source_evidence',replacement,'superseded_source_ref',old_ref,
  'superseded_override_id',old.id,'snapshot_scope',p_manifest->'snapshot_scope',
  'basis','Original positive installment and separate negative adjustment; preserve all raw cash events and classifications.');
 INSERT INTO public.lts_expense_documentary_amount_override(user_id,source_table,source_ref,event_date,description_raw,
  imported_amount,documented_signed_amount,source_document,source_sheet,source_locator,evidence_note,status)
 VALUES(p_user_id,'evento_base',new_ref,target_date,new_raw.dados->>'desc',-target_amount,target_amount,
  proof#>>'{0,file}','Pagamentos e Recebimentos','B'||(proof#>>'{0,row}'),m::text,'documented')RETURNING id INTO new_id;
 IF public.lts_cipo_consortium_source_v358(p_user_id)IS NULL THEN RAISE EXCEPTION 'V358_NEW_SOURCE_NOT_VALID';END IF;
 RETURN jsonb_build_object('status','applied','superseded_override_id',old.id,'new_override_id',new_id,'source_ref',new_ref);
END $function$;

REVOKE ALL ON FUNCTION public.lts_cipo_consortium_source_v358(uuid),public.lts_cipo_consortium_presentation_v358(jsonb,jsonb),
 public.lts_apply_cipo_consortium_source_v358(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_cipo_consortium_source_v358(uuid),public.lts_cipo_consortium_presentation_v358(jsonb,jsonb),
 public.lts_apply_cipo_consortium_source_v358(uuid,jsonb) TO service_role;
