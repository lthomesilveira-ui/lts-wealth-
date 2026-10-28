-- Read-only documentary detail beneath an existing historical consolidated row.
-- These sources never enter expense totals, cash, invoices or projections.
-- Earlier clients keep their established Excel-only reader and presentation.
CREATE SCHEMA lts_history_private_v373;
REVOKE ALL ON SCHEMA lts_history_private_v373 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_history_private_v373 TO authenticated,service_role;

CREATE TABLE lts_history_private_v373.pdf_parent (
 user_id uuid NOT NULL REFERENCES auth.users(id),parent_key text NOT NULL,
 signature jsonb NOT NULL CHECK(jsonb_typeof(signature)='object'),
 source_sha256 text NOT NULL CHECK(source_sha256~'^[0-9a-f]{64}$'),
 source_file text NOT NULL,library_file_id text NOT NULL,source_message_ref text,
 issuer text NOT NULL,family text NOT NULL,document_date date NOT NULL,due_date date NOT NULL,
 reported_total numeric NOT NULL CHECK(reported_total=round(reported_total,2)),
 source_rows integer NOT NULL CHECK(source_rows BETWEEN 1 AND 10000),
 validation jsonb NOT NULL CHECK(jsonb_typeof(validation)='object'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,parent_key),UNIQUE(user_id,source_sha256),
 CHECK(document_date<=due_date)
);
CREATE TABLE lts_history_private_v373.pdf_item (
 user_id uuid NOT NULL,parent_key text NOT NULL,ordinal integer NOT NULL CHECK(ordinal>0),
 source_page integer NOT NULL CHECK(source_page>0),source_column integer NOT NULL CHECK(source_column>0),
 extracted_line integer NOT NULL CHECK(extracted_line>0),
 original_description text NOT NULL,description text NOT NULL,bank_category text,
 amount numeric NOT NULL CHECK(amount=round(amount,2)AND abs(amount)<=100000000),
 purchase_date date,purchase_day_month text,last4 text,
 installment_number integer,installments integer,
 PRIMARY KEY(user_id,parent_key,ordinal),
 FOREIGN KEY(user_id,parent_key) REFERENCES lts_history_private_v373.pdf_parent(user_id,parent_key),
 CHECK(last4 IS NULL OR last4~'^[0-9]{4}$'),
 CHECK(purchase_day_month IS NULL OR (purchase_day_month~'^[0-9]{2}/[0-9]{2}$'
 AND to_char(to_date(purchase_day_month||'/2000','DD/MM/YYYY'),'DD/MM')=purchase_day_month)),
 CHECK(purchase_date IS NULL OR purchase_day_month IS NULL OR to_char(purchase_date,'DD/MM')=purchase_day_month),
 CHECK((installment_number IS NULL AND installments IS NULL)OR
 (installment_number IS NOT NULL AND installments IS NOT NULL
 AND installment_number>0 AND installments>=installment_number))
);
ALTER TABLE lts_history_private_v373.pdf_parent ENABLE ROW LEVEL SECURITY;
ALTER TABLE lts_history_private_v373.pdf_item ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON lts_history_private_v373.pdf_parent,lts_history_private_v373.pdf_item FROM PUBLIC,anon,authenticated;
GRANT ALL ON lts_history_private_v373.pdf_parent,lts_history_private_v373.pdf_item TO service_role;
CREATE POLICY service_only ON lts_history_private_v373.pdf_parent TO service_role USING(true)WITH CHECK(true);
CREATE POLICY service_only ON lts_history_private_v373.pdf_item TO service_role USING(true)WITH CHECK(true);

CREATE FUNCTION lts_history_private_v373.read_composition(p_from date,p_to date,p_row_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1();base jsonb;parent record;doc lts_history_private_v373.pdf_parent%rowtype;
 n bigint;nonzero bigint;identified numeric;items jsonb;
BEGIN
 -- The existing reader validates the requested identity, period and row kind.
 base:=public.lts_browser_expense_composition_v346(p_from,p_to,p_row_key);
 SELECT * INTO doc FROM lts_history_private_v373.pdf_parent p WHERE p.user_id=u AND p.parent_key=p_row_key;
 IF NOT FOUND OR base->>'status' IS DISTINCT FROM 'missing' THEN RETURN base;END IF;
 SELECT * INTO STRICT parent FROM public.lts_v229_expense_rows(u,p_from,p_to)r WHERE r.row_key=p_row_key;
 IF doc.signature IS DISTINCT FROM public.lts_card_history_signature_v346(to_jsonb(parent)) THEN
  RETURN base||jsonb_build_object('status','stale','rows','[]'::jsonb,'count',0,'nonzero_count',0,
   'identified_total',0,'residual_total',round(parent.amount,2));
 END IF;
 SELECT count(*),count(*)FILTER(WHERE c.amount<>0),coalesce(sum(c.amount),0)INTO n,nonzero,identified
 FROM lts_history_private_v373.pdf_item c WHERE c.user_id=u AND c.parent_key=p_row_key;
 IF n<>doc.source_rows OR identified IS DISTINCT FROM doc.reported_total THEN
  RETURN base||jsonb_build_object('status','stale','document_status','incomplete_source',
   'rows','[]'::jsonb,'count',0,'nonzero_count',0,'identified_total',0,'residual_total',round(parent.amount,2));
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'key',doc.source_sha256||':'||c.ordinal,'description',c.description,'category',parent.category,
  'original_category',coalesce(c.bank_category,'Não informada na fatura'),
  'amount',c.amount,'original_amount',c.amount,'period',parent.competence_month,
  'account_source',parent.account_source,'last4',c.last4,'source_date',doc.document_date,
  'date',CASE WHEN c.purchase_date IS NOT NULL THEN c.purchase_date WHEN c.purchase_day_month IS NULL THEN doc.document_date END,
  'date_kind',CASE WHEN c.purchase_date IS NOT NULL THEN 'purchase' WHEN c.purchase_day_month IS NOT NULL THEN 'purchase_day_month' ELSE 'document' END,
  'date_label',CASE WHEN c.purchase_date IS NULL THEN c.purchase_day_month END,
  'source',jsonb_build_object('kind','bank_invoice_pdf','file',doc.source_file,'library_file_id',doc.library_file_id,
   'sha256',doc.source_sha256,'page',c.source_page,'column',c.source_column,'row',c.ordinal,
   'extracted_line',c.extracted_line,'date',doc.document_date,'description',c.original_description,'amount',c.amount),
  'document',jsonb_build_object('source_kind','bank_invoice_pdf','source_file',doc.source_file,'source_page',c.source_page,
   'source_line',c.ordinal,'description',c.description,'purchase_date',c.purchase_date,'purchase_day_month',c.purchase_day_month,
   'installment_number',c.installment_number,'installments',c.installments,'invoice_due_date',doc.due_date)
 )ORDER BY c.ordinal),'[]'::jsonb)INTO items
 FROM lts_history_private_v373.pdf_item c WHERE c.user_id=u AND c.parent_key=p_row_key;
 RETURN base||jsonb_build_object('version','expense-pdf-composition-v373','rows',items,'count',n,'nonzero_count',nonzero,
  'status',public.lts_card_history_status_v346(true,true,parent.amount,identified,n),
  'identified_total',round(identified,2),'residual_total',round(parent.amount-identified,2),
  'source_document_total',doc.reported_total,'source_document_due_date',doc.due_date,'financial_effect','none');
END;
$$;
REVOKE ALL ON FUNCTION lts_history_private_v373.read_composition(date,date,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_history_private_v373.read_composition(date,date,text) TO authenticated,service_role;
CREATE FUNCTION public.lts_browser_expense_composition_v373(p_from date,p_to date,p_row_key text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_history_private_v373.read_composition(p_from,p_to,p_row_key);
$$;
REVOKE ALL ON FUNCTION public.lts_browser_expense_composition_v373(date,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_composition_v373(date,date,text) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
