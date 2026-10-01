-- Match the bank already present in a historical card label. Passing NULL here
-- treated one documented cycle as absent and appended the same purchase twice.
DO $patch$
DECLARE original text; definition text;
BEGIN
 original:=pg_get_functiondef('public.lts_expense_effective_rows_v176(uuid,date,date)'::regprocedure);
 definition:=replace(original,'public.lts_card_family_v226(b.origin_name,null)','public.lts_card_family_v226(b.origin_name,b.origin_name)');
 IF definition=original THEN RAISE EXCEPTION 'Unexpected historical invoice family expression'; END IF;
 EXECUTE definition;
 original:=pg_get_functiondef('public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text)'::regprocedure);
 definition:=replace(original,'THEN public.lts_card_family_v226(p.account_source,p.account_source) END',
 'THEN coalesce(public.lts_card_family_v226(p.account_source,p.account_source),(SELECT public.lts_card_family_v226(s.normalized_payload->>''card_name'',s.institution_name) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND p.source_table=''lts_open_finance_staging'' AND s.id::text=p.source_ref LIMIT 1)) END');
 IF definition=original THEN RAISE EXCEPTION 'Unexpected detail invoice family expression'; END IF;
 EXECUTE definition;
END $patch$;
