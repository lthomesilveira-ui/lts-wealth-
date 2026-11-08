from pathlib import Path
import json
OUT=Path(__file__).parent
TARGET={'user_id':'11111111-1111-4111-8111-111111111111','payment_id':'22222222-2222-4222-8222-222222222222','invoice_id':'33333333-3333-4333-8333-333333333333'}
FUNCS=[
'public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)',
'public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)',
'public.lts_browser_card_cycles_v229()',
'public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)',
'public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)',
'public.lts_card_read_start_v269(uuid)',
'public.lts_card_read_finish_v269(uuid,text,jsonb)',
'public.lts_browser_assert_user_v1()',
'public.lts_open_finance_pilot_owner_v1()']
TABLES=['public.lts_card_documentary_payment_link_v272','public.lts_card_settlement_expense_contract_v273','public.lts_open_finance_staging','public.lts_read_cache_epoch_v242']
def lit(v):return "'"+str(v).replace("'","''")+"'"
def arr(v):return 'ARRAY['+','.join(lit(x) for x in v)+']::text[]'
FUNCTION_META="""jsonb_build_object('signature',s,'oid',p.oid::bigint,'owner',p.proowner::regrole::text,
'acl',p.proacl::text,'definition_md5',md5(pg_get_functiondef(p.oid)),'body_md5',md5(p.prosrc),
'config',to_jsonb(p.proconfig),'security_definer',p.prosecdef,'volatility',p.provolatile,'kind',p.prokind,
'parallel',p.proparallel,'returns',p.prorettype::regtype::text)"""
FUNCTIONS_SQL=f"SELECT jsonb_agg(CASE WHEN p.oid IS NULL THEN jsonb_build_object('signature',s,'absent',true) ELSE {FUNCTION_META} END ORDER BY s) FROM unnest({arr(FUNCS)}) s LEFT JOIN pg_proc p ON p.oid=to_regprocedure(s)"
TABLE_META="""jsonb_build_object('name',s,'oid',c.oid::bigint,'owner',c.relowner::regrole::text,'acl',c.relacl::text,
'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
'column_acl',coalesce((SELECT jsonb_agg(jsonb_build_object('name',a.attname,'acl',a.attacl::text) ORDER BY a.attnum) FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped AND a.attacl IS NOT NULL),'[]'::jsonb),
'policies',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.polname) FROM pg_policy x WHERE x.polrelid=c.oid),'[]'::jsonb),
'user_triggers',coalesce((SELECT jsonb_agg(jsonb_build_object('oid',t.oid::bigint,'definition',pg_get_triggerdef(t.oid),'enabled',t.tgenabled) ORDER BY t.tgname) FROM pg_trigger t WHERE t.tgrelid=c.oid AND NOT t.tgisinternal),'[]'::jsonb))"""
TABLES_SQL=f"SELECT jsonb_agg({TABLE_META} ORDER BY s) FROM unnest({arr(TABLES)}) s LEFT JOIN pg_class c ON c.oid=to_regclass(s)"
U,I,P=map(lit,[TARGET['user_id'],TARGET['invoice_id'],TARGET['payment_id']])
ROWS_SQL=f"""SELECT jsonb_build_object(
'contract', (SELECT md5(to_jsonb(c)::text) FROM public.lts_card_settlement_expense_contract_v273 c WHERE c.user_id={U}::uuid AND c.payment_source_id={P}::uuid),
'link', (SELECT md5(to_jsonb(l)::text) FROM public.lts_card_documentary_payment_link_v272 l WHERE l.user_id={U}::uuid AND l.payment_source_id={P}::uuid AND l.active),
'sources', (SELECT jsonb_agg(jsonb_build_object('id',s.id,'row_md5',md5(to_jsonb(s)::text)) ORDER BY s.id) FROM public.lts_open_finance_staging s WHERE s.user_id={U}::uuid AND s.id IN ({I}::uuid,{P}::uuid)))"""
DEFAULTS_SQL="SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.oid),'[]'::jsonb) FROM pg_default_acl d WHERE d.defaclrole=(SELECT proowner FROM pg_proc WHERE oid='public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure) AND d.defaclnamespace IN(0,'public'::regnamespace) AND d.defaclobjtype='f'"
query=f"""-- PRIVATE exact current metadata and two-row fingerprint lease. No reader RPC, expense query, history, or cache read.
BEGIN READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL statement_timeout='12s';
SET LOCAL lock_timeout='2s';
SELECT jsonb_build_object(
'checked_at',clock_timestamp(),'timezone',current_setting('TimeZone'),'read_only',current_setting('transaction_read_only'),'database',current_database(),
'executor',current_user,'pilot_owner',public.lts_open_finance_pilot_owner_v1(),
'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton),
'functions',({FUNCTIONS_SQL}),
'tables',({TABLES_SQL}),
'rows',({ROWS_SQL}),
'function_defaults',({DEFAULTS_SQL}),
'original_presentation_definition',pg_get_functiondef('public.lts_card_documentary_payment_presentation_v272(uuid,jsonb)'::regprocedure)
) AS lease;
ROLLBACK;
"""
if __name__=='__main__':
 (OUT/'fresh-lease-readonly.sql').write_text(query)
 (OUT/'target-private.json').write_text(json.dumps(TARGET,indent=2)+'\n')
 print('Prepared exact read-only lease query; not executed')
