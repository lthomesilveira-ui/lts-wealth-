DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_browser_future_bank_v293(date,date)'::regprocedure) INTO d;
 IF md5(d)<>'925068a2c77f595836302821024b3ef2' THEN RAISE EXCEPTION 'V293 bank-source reader changed';END IF;
 d:=replace(d,'AND s.posting_date BETWEEN p_from AND p_to),',
 $a$AND s.posting_date BETWEEN p_from AND p_to
 AND(s.posting_date>current_date OR EXISTS(SELECT 1 FROM public.audit_log a
 WHERE a.user_id=s.user_id AND a.action='confirm_scheduled_transfer_destination'
 AND a.entity_type='open_finance_schedule' AND a.entity_id=s.id::text))),$a$);
 EXECUTE d;
END $patch$;
