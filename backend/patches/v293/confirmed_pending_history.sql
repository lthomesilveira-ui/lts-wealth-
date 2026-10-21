DO $scope$ DECLARE d text;old text;new text;u uuid;j jsonb;BEGIN
 SELECT pg_get_functiondef('public.lts_browser_future_bank_v293(date,date)'::regprocedure) INTO d;
 IF md5(d)<>'2edee60aad8004b47186078fc6720a27' THEN RAISE EXCEPTION 'Pending schedule history reader changed';END IF;
 old:=$a$AND s.posting_date BETWEEN p_from AND p_to
 AND(s.posting_date>current_date OR EXISTS(SELECT 1 FROM public.audit_log a
 WHERE a.user_id=s.user_id AND a.action='confirm_scheduled_transfer_destination'
 AND a.entity_type='open_finance_schedule' AND a.entity_id=s.id::text)))$a$;
 new:=$b$AND((s.posting_date>current_date AND s.posting_date BETWEEN p_from AND p_to)
 OR(s.posting_date<=current_date AND EXISTS(SELECT 1 FROM public.audit_log a
 WHERE a.user_id=s.user_id AND a.action='confirm_scheduled_transfer_destination'
 AND a.entity_type='open_finance_schedule' AND a.entity_id=s.id::text))))$b$;
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Pending schedule scope anchor changed';END IF;
 d:=replace(d,old,new);
 EXECUTE d;
 FOR u IN SELECT DISTINCT user_id FROM public.audit_log WHERE action='confirm_scheduled_transfer_destination' LOOP
  PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
  j:=public.lts_browser_future_bank_v293(current_date,current_date+365);
  IF jsonb_typeof(j->'rows') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Schedule history endpoint unavailable';END IF;
 END LOOP;
END $scope$;
