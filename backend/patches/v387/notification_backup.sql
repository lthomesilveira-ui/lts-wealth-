-- Extend the existing daily supplement. Archived 29-table bundles remain valid.
-- This installs readers only; it neither takes a new backup nor changes its schedule.
DO $patch$
DECLARE export_def text:=pg_get_functiondef('public.lts_backup_modern_export_v380(uuid)'::regprocedure);
 read_def text:=pg_get_functiondef('public.lts_backup_bundle_read_v380(uuid,date)'::regprocedure);
 take_def text:=pg_get_functiondef('public.lts_backup_snapshot_take_v380(uuid,date)'::regprocedure);
 marker text:='V387 notification journals';
BEGIN
 IF position(marker IN export_def)>0 AND position(marker IN read_def)>0 AND position(marker IN take_def)>0 THEN RETURN;END IF;
 IF md5(export_def)<>'68ab93961437dfe436ee3a59dafbfd6a'
 OR md5(read_def)<>'9691e21fc6f545933699a2655dc5e2bf'
 OR md5(take_def)<>'7e5f084f13806810b69cb463f453d642'
 THEN RAISE EXCEPTION 'Backup readers changed; review before extending notification coverage';END IF;
 export_def:=replace(export_def,'select jsonb_build_object','select /* V387 notification journals */ jsonb_build_object');
 export_def:=replace(export_def,$old$'usuario',coalesce((select$old$,$new$
'lts_cash_alert_private_v377.delivery',coalesce((select jsonb_agg(to_jsonb(t) order by t.sent_at,t.token) from lts_cash_alert_private_v377.delivery t where t.user_id=p_user_id),'[]'::jsonb),
'lts_account_reminder_private_v387.delivery',coalesce((select jsonb_agg(to_jsonb(t) order by t.sent_at,t.token) from lts_account_reminder_private_v387.delivery t where t.user_id=p_user_id),'[]'::jsonb),
'usuario',coalesce((select$new$);
 export_def:=replace(export_def,'''selected_tables'',29','''selected_tables'',31,''notification_delivery_journals'',true');
 export_def:=replace(export_def,'order by c.table_name,c.ordinal_position','order by c.table_schema,c.table_name,c.ordinal_position');
 -- Append schema metadata for the two private journals to the original scoped list.
 export_def:=replace(export_def,$old$'lts_open_finance_sync_run','usuario')));$old$,$new$'lts_open_finance_sync_run','usuario')
 or(c.table_schema in('lts_cash_alert_private_v377','lts_account_reminder_private_v387')and c.table_name='delivery')));$new$);
 read_def:=replace(read_def,E'begin\n',E'begin\n -- V387 notification journals\n');
 read_def:=replace(read_def,$old$if v_counts is distinct from s.counts or (select count(*) from jsonb_each(s.payload->'tables'))<>29 then$old$,$new$if v_counts is distinct from s.counts
 or (select count(*) from jsonb_each(s.payload->'tables')) not in(29,31)
 or (s.payload#>>'{coverage,selected_tables}')::int is distinct from(select count(*)::int from jsonb_each(s.payload->'tables'))
 or((s.payload#>>'{coverage,selected_tables}')::int=31 and not(s.payload->'tables'?'lts_cash_alert_private_v377.delivery'and s.payload->'tables'?'lts_account_reminder_private_v387.delivery'))then$new$);
 take_def:=replace(take_def,E'begin\n',E'begin\n -- V387 notification journals\n');
 take_def:=replace(take_def,'if v_n<>29 then','if v_n<>31 then');
 IF position(marker IN export_def)=0 OR position(marker IN read_def)=0 OR position(marker IN take_def)=0
 OR position('notification_delivery_journals'IN export_def)=0 OR position('not in(29,31)'IN read_def)=0 OR position('if v_n<>31 then'IN take_def)=0
 THEN RAISE EXCEPTION 'Expected notification backup anchors unavailable';END IF;
 EXECUTE export_def;EXECUTE read_def;EXECUTE take_def;
END $patch$;
