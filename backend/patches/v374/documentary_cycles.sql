-- Documentary cycles may span several original rows and several bank PDFs.
-- This private consultation layer is never an input of a financial reader.
CREATE SCHEMA lts_history_private_v374;
REVOKE ALL ON SCHEMA lts_history_private_v374 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_history_private_v374 TO authenticated,service_role;

CREATE TABLE lts_history_private_v374.cycle (
 user_id uuid NOT NULL REFERENCES auth.users(id),cycle_key text NOT NULL,
 booked_on date NOT NULL,competence_month date NOT NULL,
 workbook jsonb NOT NULL CHECK(jsonb_typeof(workbook)='object'),
 members jsonb NOT NULL CHECK(jsonb_typeof(members)='array'AND jsonb_array_length(members)>0),
 validation jsonb NOT NULL CHECK(jsonb_typeof(validation)='object'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,cycle_key),
 CHECK(competence_month=date_trunc('month',competence_month)::date)
);
CREATE TABLE lts_history_private_v374.document (
 user_id uuid NOT NULL,source_sha256 text NOT NULL CHECK(source_sha256~'^[0-9a-f]{64}$'),
 semantic_sha256 text NOT NULL CHECK(semantic_sha256~'^[0-9a-f]{64}$'),cycle_key text NOT NULL,
 source_file text NOT NULL,library_file_id text NOT NULL,source_message_ref text,
 issuer text NOT NULL,family text NOT NULL,billing_last4 text NOT NULL CHECK(billing_last4~'^[0-9]{4}$'),
 document_date date NOT NULL,due_date date NOT NULL,
 reported_total numeric NOT NULL CHECK(reported_total=round(reported_total,2)),
 source_rows integer NOT NULL CHECK(source_rows BETWEEN 1 AND 10000),
 items jsonb NOT NULL CHECK(jsonb_typeof(items)='array'AND jsonb_array_length(items)=source_rows),
 validation jsonb NOT NULL CHECK(jsonb_typeof(validation)='object'),
 PRIMARY KEY(user_id,source_sha256),UNIQUE(user_id,semantic_sha256),UNIQUE(user_id,family,billing_last4,due_date),
 FOREIGN KEY(user_id,cycle_key)REFERENCES lts_history_private_v374.cycle(user_id,cycle_key),
 CHECK(document_date<=due_date)
);
CREATE INDEX documentary_cycle_documents ON lts_history_private_v374.document(user_id,cycle_key);
CREATE TABLE lts_history_private_v374.binding (
 user_id uuid NOT NULL,parent_key text NOT NULL,cycle_key text NOT NULL,
 signature jsonb NOT NULL CHECK(jsonb_typeof(signature)='object'),
 PRIMARY KEY(user_id,parent_key),
 FOREIGN KEY(user_id,cycle_key)REFERENCES lts_history_private_v374.cycle(user_id,cycle_key)
);
CREATE INDEX documentary_cycle_bindings ON lts_history_private_v374.binding(user_id,cycle_key);
ALTER TABLE lts_history_private_v374.cycle ENABLE ROW LEVEL SECURITY;
ALTER TABLE lts_history_private_v374.document ENABLE ROW LEVEL SECURITY;
ALTER TABLE lts_history_private_v374.binding ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON lts_history_private_v374.cycle,lts_history_private_v374.document,lts_history_private_v374.binding FROM PUBLIC,anon,authenticated;
GRANT ALL ON lts_history_private_v374.cycle,lts_history_private_v374.document,lts_history_private_v374.binding TO service_role;
CREATE POLICY service_only ON lts_history_private_v374.cycle TO service_role USING(true)WITH CHECK(true);
CREATE POLICY service_only ON lts_history_private_v374.document TO service_role USING(true)WITH CHECK(true);
CREATE POLICY service_only ON lts_history_private_v374.binding TO service_role USING(true)WITH CHECK(true);

-- Internal only: the public entry points obtain this owner's canonical rows.
-- No authenticated caller may supply an arbitrary canonical-row snapshot.
CREATE FUNCTION lts_history_private_v374.cycle_payload(p_user uuid,p_cycle text,p_current jsonb,p_selected jsonb,p_base jsonb,p_items boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE c lts_history_private_v374.cycle%rowtype;docs jsonb;rows_out jsonb:='[]';members_out jsonb;
 n_members bigint;bad_members bigint;positive_count bigint;positive_total numeric;negative_total numeric;net_total numeric;
 n_docs bigint;n_items bigint;nonzero bigint;document_total numeric;bad_docs bigint;reconciliation jsonb;
 stale jsonb:=p_base||jsonb_build_object('status','stale','rows','[]'::jsonb,'count',0,'nonzero_count',0,'identified_total',0,
 'residual_total',(p_selected->>'amount')::numeric,'unexplained_total',(p_selected->>'amount')::numeric);
BEGIN
 SELECT * INTO STRICT c FROM lts_history_private_v374.cycle WHERE user_id=p_user AND cycle_key=p_cycle;
 IF jsonb_typeof(c.validation->'accounts')IS DISTINCT FROM'array'
 OR jsonb_typeof(c.validation->'source_tables')IS DISTINCT FROM'array'
 OR jsonb_typeof(c.validation->'event_dates')IS DISTINCT FROM'array'
 OR jsonb_array_length(c.validation->'accounts')=0 OR jsonb_array_length(c.validation->'source_tables')=0
 OR c.booked_on IS DISTINCT FROM(SELECT min((m->'signature'->>'event_date')::date)FROM jsonb_array_elements(c.members)m)
 OR c.validation->'event_dates'IS DISTINCT FROM(SELECT jsonb_agg(d ORDER BY d)FROM(SELECT DISTINCT m->'signature'->>'event_date'd FROM jsonb_array_elements(c.members)m)dates)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_current)x
  WHERE(c.validation->'event_dates')?(x->>'event_date')AND x->>'competence_month'=c.competence_month::text
  AND(c.validation->'accounts')?(x->>'account_source')AND(c.validation->'source_tables')?(x->>'source_table')
  AND x->>'coverage_mode'IN('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235')
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.members)m WHERE m->>'key'=x->>'row_key'))THEN RETURN stale;END IF;
 WITH m AS(SELECT x FROM jsonb_array_elements(c.members)x),
 canonical AS(SELECT x FROM jsonb_array_elements(p_current)x)
 SELECT count(*),count(*)FILTER(WHERE r.x IS NULL
  OR m.x->'signature'IS DISTINCT FROM public.lts_card_history_signature_v346(r.x)
  OR NOT((c.validation->'event_dates')?(r.x->>'event_date'))
  OR r.x->>'competence_month'IS DISTINCT FROM c.competence_month::text
  OR NOT((c.validation->'accounts')?(r.x->>'account_source'))
  OR NOT((c.validation->'source_tables')?(r.x->>'source_table'))
  OR NOT(((r.x->>'amount')::numeric>0 AND r.x->>'coverage_mode'='card_invoice_aggregate_fallback')
   OR((r.x->>'amount')::numeric<0 AND r.x->>'coverage_mode'='card_workbook_signed_adjustment_v235'))),
  count(*)FILTER(WHERE(r.x->>'amount')::numeric>0),
  coalesce(sum((r.x->>'amount')::numeric)FILTER(WHERE(r.x->>'amount')::numeric>0),0),
  coalesce(sum((r.x->>'amount')::numeric)FILTER(WHERE(r.x->>'amount')::numeric<0),0),
  coalesce(sum((r.x->>'amount')::numeric),0),
  coalesce(jsonb_agg(jsonb_build_object('key',r.x->>'row_key','amount',r.x->'amount','date',r.x->>'event_date',
   'description',r.x->>'description','account_source',r.x->>'account_source',
   'source_table',r.x->>'source_table','source_ref',r.x->>'source_ref','workbook_rows',m.x->'workbook_rows')
   ORDER BY r.x->>'row_key'),'[]'::jsonb)
 INTO n_members,bad_members,positive_count,positive_total,negative_total,net_total,members_out
 FROM m LEFT JOIN canonical r ON r.x->>'row_key'=m.x->>'key';
 IF bad_members>0 OR positive_count=0 OR n_members<>(SELECT count(DISTINCT x->>'key')FROM jsonb_array_elements(c.members)x)
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.members)x WHERE x->>'key'=p_selected->>'row_key'
  AND x->'signature'=public.lts_card_history_signature_v346(p_selected))THEN RETURN stale;END IF;
 WITH detail AS(
  SELECT d.*,a.n,a.nonzero,a.amount,a.bad FROM lts_history_private_v374.document d
  CROSS JOIN LATERAL(
   SELECT count(*)n,count(*)FILTER(WHERE(i->>'amount')::numeric<>0)nonzero,
    coalesce(sum((i->>'amount')::numeric),0)amount,
    count(*)FILTER(WHERE i->>'source_page'IS NULL OR i->>'source_column'IS NULL OR i->>'source_line'IS NULL OR i->>'amount'IS NULL
     OR(i->>'source_page')::integer<=0 OR(i->>'source_column')::integer<=0
     OR(i->>'source_line')::integer<=0 OR nullif(i->>'description','')IS NULL
     OR(i->>'amount')::numeric<>round((i->>'amount')::numeric,2)
     OR(i->>'last4'IS NOT NULL AND i->>'last4'!~'^[0-9]{4}$')
     OR(i->>'purchase_day_month'IS NOT NULL AND(i->>'purchase_day_month'!~'^[0-9]{2}/[0-9]{2}$'
      OR to_char(to_date(i->>'purchase_day_month'||'/2000','DD/MM/YYYY'),'DD/MM')<>i->>'purchase_day_month'))
     OR(i->>'purchase_date'IS NOT NULL AND i->>'purchase_day_month'IS NOT NULL
      AND to_char((i->>'purchase_date')::date,'DD/MM')<>i->>'purchase_day_month')
     OR((i->>'installment_number'IS NULL)IS DISTINCT FROM(i->>'installments'IS NULL))
     OR(i->>'installment_number'IS NOT NULL AND((i->>'installment_number')::integer<=0
      OR(i->>'installments')::integer<(i->>'installment_number')::integer)))bad
   FROM jsonb_array_elements(d.items)i
  )a WHERE d.user_id=p_user AND d.cycle_key=p_cycle
 )
 SELECT count(*),coalesce(sum(q.n),0),coalesce(sum(q.nonzero),0),coalesce(sum(q.reported_total),0),
 count(*)FILTER(WHERE q.n<>q.source_rows OR q.amount<>q.reported_total OR q.bad>0 OR date_trunc('month',q.due_date)::date<>c.competence_month),
 coalesce(jsonb_agg(jsonb_build_object('sha256',q.source_sha256,'file',q.source_file,'library_file_id',q.library_file_id,
  'issuer',q.issuer,'family',q.family,'billing_last4',q.billing_last4,'document_date',q.document_date,
  'due_date',q.due_date,'total',q.reported_total,'rows',q.source_rows)ORDER BY q.source_sha256),'[]'::jsonb)
 INTO n_docs,n_items,nonzero,document_total,bad_docs,docs FROM detail q;
 IF n_docs=0 OR bad_docs>0 OR round(net_total,2)<>document_total THEN RETURN stale;END IF;
 IF p_items THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object(
   'key',d.source_sha256||':'||a.n,'description',i->>'description','category',p_selected->>'category',
   'original_category',coalesce(i->>'original_category','Não informada na fatura'),
   'amount',(i->>'amount')::numeric,'original_amount',(i->>'amount')::numeric,'period',c.competence_month,
   'account_source',CASE d.family WHEN'itau_mastercard'THEN'Mastercard Itaú'WHEN'itau_visa'THEN'Visa Itaú'ELSE d.family END,
   'last4',i->>'last4','source_date',d.document_date,
   'date',CASE WHEN i->>'purchase_date'IS NOT NULL THEN(i->>'purchase_date')::date
    WHEN i->>'purchase_day_month'IS NULL THEN d.document_date END,
   'date_kind',CASE WHEN i->>'purchase_date'IS NOT NULL THEN'purchase'WHEN i->>'purchase_day_month'IS NOT NULL THEN'purchase_day_month'ELSE'document'END,
   'date_label',CASE WHEN i->>'purchase_date'IS NULL THEN i->>'purchase_day_month'END,
   'source',jsonb_build_object('kind','bank_invoice_pdf','file',d.source_file,'library_file_id',d.library_file_id,
    'sha256',d.source_sha256,'page',i->'source_page','column',i->'source_column','row',a.n,
    'extracted_line',i->'source_line','date',d.document_date,'description',i->>'original_description','amount',(i->>'amount')::numeric),
   'document',jsonb_build_object('source_kind','bank_invoice_pdf','source_file',d.source_file,
    'source_page',i->'source_page','source_line',a.n,'description',i->>'description',
    'purchase_date',i->'purchase_date','purchase_day_month',i->'purchase_day_month',
    'installment_number',i->'installment_number','installments',i->'installments','invoice_due_date',d.due_date)
  )ORDER BY d.due_date,d.family,d.billing_last4,d.source_sha256,a.n),'[]'::jsonb)INTO rows_out
  FROM lts_history_private_v374.document d CROSS JOIN LATERAL jsonb_array_elements(d.items)WITH ORDINALITY a(i,n)
  WHERE d.user_id=p_user AND d.cycle_key=p_cycle;
 END IF;
 reconciliation:=jsonb_build_object('status','documented_cycle_net_match','original_total',positive_total,
  'adjustments_total',negative_total,'net_total',round(net_total,2),'document_total',document_total,
  'selected_total',(p_selected->>'amount')::numeric,'member_count',n_members,'document_count',n_docs,
  'members',members_out,'documents',docs,'workbook',c.workbook);
 RETURN p_base||jsonb_build_object('version','expense-documentary-cycle-v374','status','complete',
  'rows',rows_out,'count',n_items,'nonzero_count',nonzero,'identified_total',document_total,
  'residual_total',round((p_selected->>'amount')::numeric-document_total,2),'unexplained_total',0,
  'reconciliation',reconciliation,'source_document_total',document_total,'financial_effect','none');
EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range OR datetime_field_overflow OR invalid_datetime_format THEN
 RETURN stale;
END;
$$;
REVOKE ALL ON FUNCTION lts_history_private_v374.cycle_payload(uuid,text,jsonb,jsonb,jsonb,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_history_private_v374.cycle_payload(uuid,text,jsonb,jsonb,jsonb,boolean) TO service_role;

CREATE FUNCTION lts_history_private_v374.read_composition(p_from date,p_to date,p_row_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1();base jsonb;b lts_history_private_v374.binding%rowtype;
 parent jsonb;canonical jsonb;c lts_history_private_v374.cycle%rowtype;
BEGIN
 base:=public.lts_browser_expense_composition_v373(p_from,p_to,p_row_key);
 IF base->>'status'IS DISTINCT FROM'missing'THEN RETURN base;END IF;
 SELECT * INTO b FROM lts_history_private_v374.binding WHERE user_id=u AND parent_key=p_row_key;
 IF NOT FOUND THEN RETURN base;END IF;
 SELECT * INTO STRICT c FROM lts_history_private_v374.cycle WHERE user_id=u AND cycle_key=b.cycle_key;
 SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb)INTO canonical FROM public.lts_v229_expense_rows(u,c.booked_on,
  (SELECT max((m->'signature'->>'event_date')::date)FROM jsonb_array_elements(c.members)m))r;
 SELECT x INTO STRICT parent FROM jsonb_array_elements(canonical)x WHERE x->>'row_key'=p_row_key;
 IF b.signature IS DISTINCT FROM public.lts_card_history_signature_v346(parent)THEN
  RETURN base||jsonb_build_object('status','stale','rows','[]'::jsonb,'count',0,'identified_total',0);
 END IF;
 RETURN lts_history_private_v374.cycle_payload(u,b.cycle_key,canonical,parent,base,true);
END;
$$;
REVOKE ALL ON FUNCTION lts_history_private_v374.read_composition(date,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION lts_history_private_v374.read_composition(date,date,text) TO authenticated,service_role;
CREATE FUNCTION public.lts_browser_expense_composition_v374(p_from date,p_to date,p_row_key text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_history_private_v374.read_composition(p_from,p_to,p_row_key);
$$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_composition_v374(date,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_composition_v374(date,date,text) TO authenticated,service_role;

CREATE FUNCTION lts_history_private_v374.decorate_detail(p_from date,p_to date,p_base jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1();current_rows jsonb;row_out jsonb;result_rows jsonb:='[]';
 r jsonb;parent jsonb;payload jsonb;b lts_history_private_v374.binding%rowtype;min_date date;max_date date;rev text;
BEGIN
 SELECT min(cycle_row.booked_on),max((member_row->'signature'->>'event_date')::date)INTO min_date,max_date
 FROM lts_history_private_v374.binding bind_row JOIN lts_history_private_v374.cycle cycle_row USING(user_id,cycle_key)
 CROSS JOIN LATERAL jsonb_array_elements(cycle_row.members)member_row
 WHERE bind_row.user_id=u AND bind_row.parent_key IN(SELECT x->>'key'FROM jsonb_array_elements(p_base->'rows')x);
 IF min_date IS NOT NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)INTO current_rows FROM public.lts_v229_expense_rows(u,min_date,max_date)x;
 END IF;
 FOR r IN SELECT x FROM jsonb_array_elements(p_base->'rows')x LOOP
  row_out:=r;payload:=NULL;
  IF r->'composition'->>'status'='missing' THEN
   SELECT * INTO b FROM lts_history_private_v374.binding WHERE user_id=u AND parent_key=r->>'key';
   IF FOUND THEN
    SELECT x INTO parent FROM jsonb_array_elements(current_rows)x WHERE x->>'row_key'=r->>'key';
    IF parent IS NOT NULL AND b.signature=public.lts_card_history_signature_v346(parent)THEN
     payload:=lts_history_private_v374.cycle_payload(u,b.cycle_key,current_rows,parent,
      jsonb_build_object('total',(r->>'amount')::numeric,'status','missing'),false);
    ELSE payload:=jsonb_build_object('status','stale','count',0,'nonzero_count',0);END IF;
   ELSIF EXISTS(SELECT 1 FROM lts_history_private_v373.pdf_parent WHERE user_id=u AND parent_key=r->>'key')THEN
    payload:=public.lts_browser_expense_composition_v373(p_from,p_to,r->>'key');
   END IF;
   IF payload IS NOT NULL THEN
    row_out:=r||jsonb_build_object('composition',jsonb_build_object('status',payload->>'status',
     'count',coalesce((payload->>'count')::bigint,0),'nonzero_count',coalesce((payload->>'nonzero_count')::bigint,0),
     'source_kind','bank_invoice_pdf'));
    IF payload->>'status'<>'complete'AND row_out->'source_audit'IS NOT NULL THEN
     row_out:=jsonb_set(row_out,'{source_audit,note}','"A composição documental recebida precisa de nova conferência."');
    END IF;
   END IF;
  END IF;
  result_rows:=result_rows||jsonb_build_array(row_out);
 END LOOP;
 SELECT md5(coalesce(string_agg(x,'|'ORDER BY x),''))INTO rev FROM(
  SELECT to_jsonb(d)::text x FROM lts_history_private_v374.document d WHERE d.user_id=u
  UNION ALL SELECT to_jsonb(c)::text FROM lts_history_private_v374.cycle c WHERE c.user_id=u
  UNION ALL SELECT to_jsonb(p)::text FROM lts_history_private_v373.pdf_parent p WHERE p.user_id=u
  UNION ALL SELECT to_jsonb(i)::text FROM lts_history_private_v373.pdf_item i WHERE i.user_id=u
 )q;
 RETURN p_base||jsonb_build_object('rows',result_rows,'version','expense-detail-documentary-v374',
  'revision',coalesce(p_base->>'revision','')||':documentary-v374:'||rev);
END;
$$;
REVOKE ALL ON FUNCTION lts_history_private_v374.decorate_detail(date,date,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_history_private_v374.decorate_detail(date,date,jsonb) TO service_role;
CREATE FUNCTION lts_history_private_v374.read_detail(p_from date,p_to date,p_group text,p_subgroup text,p_offset integer,p_limit integer,p_query text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE base jsonb;
BEGIN
 PERFORM public.lts_browser_assert_user_v1();
 base:=public.lts_browser_expense_detail_v346(p_from,p_to,p_group,p_subgroup,p_offset,p_limit,p_query);
 RETURN lts_history_private_v374.decorate_detail(p_from,p_to,base);
END;
$$;
CREATE FUNCTION lts_history_private_v374.read_scope_detail(p_from date,p_to date,p_scope jsonb,p_offset integer,p_limit integer,p_query text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE base jsonb;
BEGIN
 PERFORM public.lts_browser_assert_user_v1();
 base:=public.lts_browser_expense_detail_v353(p_from,p_to,p_scope,p_offset,p_limit,p_query);
 RETURN lts_history_private_v374.decorate_detail(p_from,p_to,base);
END;
$$;
REVOKE ALL ON FUNCTION lts_history_private_v374.read_detail(date,date,text,text,integer,integer,text),lts_history_private_v374.read_scope_detail(date,date,jsonb,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION lts_history_private_v374.read_detail(date,date,text,text,integer,integer,text),lts_history_private_v374.read_scope_detail(date,date,jsonb,integer,integer,text) TO authenticated,service_role;
CREATE FUNCTION public.lts_browser_expense_detail_v374(p_from date,p_to date,p_group text DEFAULT NULL,p_subgroup text DEFAULT NULL,p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_history_private_v374.read_detail(p_from,p_to,p_group,p_subgroup,p_offset,p_limit,p_query);
$$;
CREATE FUNCTION public.lts_browser_expense_scope_detail_v374(p_from date,p_to date,p_scope jsonb DEFAULT '{}',p_offset integer DEFAULT 0,p_limit integer DEFAULT 500,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_history_private_v374.read_scope_detail(p_from,p_to,p_scope,p_offset,p_limit,p_query);
$$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_detail_v374(date,date,text,text,integer,integer,text),public.lts_browser_expense_scope_detail_v374(date,date,jsonb,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_detail_v374(date,date,text,text,integer,integer,text),public.lts_browser_expense_scope_detail_v374(date,date,jsonb,integer,integer,text) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
