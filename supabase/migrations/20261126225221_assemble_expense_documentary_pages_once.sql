-- Preserve documentary overlays, source order and revision while avoiding repeated copies of the full page.
CREATE OR REPLACE FUNCTION lts_history_private_v374.decorate_detail(p_from date, p_to date, p_base jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();current_rows jsonb;row_out jsonb;result_rows jsonb:=coalesce(p_base->'rows','[]'::jsonb);
 patches jsonb:='{}';
 item record;
 r jsonb;parent jsonb;payload jsonb;b lts_history_private_v374.binding%rowtype;min_date date;max_date date;rev text;
BEGIN
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(result_rows) AS e(entry)
            WHERE e.entry->'composition'->>'status'='missing') THEN
  SELECT min(cycle_row.booked_on),max((member_row->'signature'->>'event_date')::date)INTO min_date,max_date
  FROM lts_history_private_v374.binding bind_row JOIN lts_history_private_v374.cycle cycle_row USING(user_id,cycle_key)
  CROSS JOIN LATERAL jsonb_array_elements(cycle_row.members)member_row
  WHERE bind_row.user_id=u AND bind_row.parent_key IN(SELECT x->>'key'FROM jsonb_array_elements(p_base->'rows')x);
  IF min_date IS NOT NULL THEN
   SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)INTO current_rows FROM public.lts_v229_expense_rows(u,min_date,max_date)x;
  END IF;
  FOR item IN SELECT entry,ord FROM jsonb_array_elements(result_rows) WITH ORDINALITY e(entry,ord)
              WHERE entry->'composition'->>'status'='missing' LOOP
   r:=item.entry;payload:=NULL;
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
     patches:=patches||jsonb_build_object(item.ord::text,row_out);
    END IF;
  END LOOP;
  IF patches<>'{}'::jsonb THEN
   SELECT jsonb_agg(coalesce(patches->(e.ord::text),e.entry) ORDER BY e.ord) INTO result_rows
   FROM jsonb_array_elements(result_rows) WITH ORDINALITY e(entry,ord);
  END IF;
 END IF;
 SELECT md5(coalesce(string_agg(x,'|'ORDER BY x),''))INTO rev FROM(
  SELECT to_jsonb(d)::text x FROM lts_history_private_v374.document d WHERE d.user_id=u
  UNION ALL SELECT to_jsonb(c)::text FROM lts_history_private_v374.cycle c WHERE c.user_id=u
  UNION ALL SELECT to_jsonb(p)::text FROM lts_history_private_v373.pdf_parent p WHERE p.user_id=u
  UNION ALL SELECT to_jsonb(i)::text FROM lts_history_private_v373.pdf_item i WHERE i.user_id=u
 )q;
 RETURN p_base||jsonb_build_object('rows',result_rows,'version','expense-detail-documentary-v374',
  'revision',coalesce(p_base->>'revision','')||':documentary-v374:'||rev);
END;
$function$
;
