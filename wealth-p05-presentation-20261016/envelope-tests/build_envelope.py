"""Render private single-DO proposal only. Never connects to any database.
Fresh read-only lease mandatory; recovery also requires the installation receipt.
"""
from pathlib import Path
import argparse,copy,datetime,hashlib,json,re
from build_read import TARGET,FUNCS,TABLES,FUNCTIONS_SQL,TABLES_SQL,ROWS_SQL,DEFAULTS_SQL,lit
HERE=Path(__file__).parent
PUB=next(parent/'public' for parent in HERE.parents if (parent/'public/payment-refresh-annotation.sql').is_file())
CALLER=FUNCS[0]; PROJECTOR=FUNCS[1]
PINNED={'payment-refresh-annotation.sql':'a330d088ac4c3fc9f8e6607717d7cd80b10a43d8594576fa68f3035e4973f541','documentary-payment-presentation.sql':'e3b5e3732cffbeb03f9e9cd3cca43bb68678daaf3c5cd392e45ba0fd0900e091'}
def j(v):return lit(json.dumps(v,ensure_ascii=False,separators=(',',':')))+'::jsonb'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def extract(path,tag,create=False):
 text=path.read_text()
 if path.name in PINNED: assert hashlib.sha256(text.encode()).hexdigest()==PINNED[path.name]
 ddl=re.search(r'CREATE (?:OR REPLACE )?FUNCTION [\s\S]+?\$'+tag+r'\$;',text).group()
 body=ddl.split('$'+tag+'$')[1]
 if create:ddl=ddl.replace('CREATE OR REPLACE FUNCTION','CREATE FUNCTION',1)
 return ddl,body
PROJECTOR_DDL,PROJECTOR_BODY=extract(PUB/'payment-refresh-annotation.sql','annotation',True)
CALLER_DDL,CALLER_BODY=extract(PUB/'documentary-payment-presentation.sql','function')

def load_lease(path):
 v=json.loads(Path(path).read_text())
 if isinstance(v,list):assert len(v)==1;v=v[0]
 if 'lease' in v:v=v['lease']
 assert v['read_only']=='on'
 assert v['pilot_owner']==TARGET['user_id']
 assert type(v['epoch']) is int
 assert len(v['functions'])==len(FUNCS) and {f['signature'] for f in v['functions']}==set(FUNCS)
 assert len(v['tables'])==len(TABLES) and {t['name'] for t in v['tables']}==set(TABLES)
 for f in v['functions']:
  if f.get('absent'):assert f['signature']==PROJECTOR
  else:assert type(f['oid']) is int and f['oid']>0
 for t in v['tables']:assert type(t['oid']) is int and t['oid']>0
 assert v['rows']['contract'] and v['rows']['link'] and len(v['rows']['sources'])==2
 assert {s['id'] for s in v['rows']['sources']}=={TARGET['invoice_id'],TARGET['payment_id']}
 stamp=datetime.datetime.fromisoformat(v['checked_at'].replace('Z','+00:00')); assert stamp.tzinfo
 caller=next(f for f in v['functions'] if f['signature']==CALLER)
 assert md5(v['original_presentation_definition'])==caller['definition_md5']
 assert v['executor']==caller['owner'],'New helper is created by the existing owner; no implicit owner change'
 return v

def render(lease,mode='apply',installation=None,original=None):
 recovery=mode=='recovery'
 funcs={f['signature']:f for f in lease['functions']}
 assert not funcs[CALLER].get('security_definer')
 if not recovery:assert funcs[PROJECTOR].get('absent') is True,'Initial helper absence required'
 else:
  assert installation is not None and original is not None
  # A later fresh read cannot legitimize replacement/recreation since installation.
  for name in (CALLER,PROJECTOR):
   installed=next(f for f in installation['functions'] if f['signature']==name)
   assert funcs[name]==installed,'Installed object changed: recovery must be reconciled'
  assert funcs[CALLER]['body_md5']==md5(CALLER_BODY)
  assert funcs[PROJECTOR]['body_md5']==md5(PROJECTOR_BODY)
  assert md5(original['original_presentation_definition'])==next(f for f in original['functions'] if f['signature']==CALLER)['definition_md5']
 owner=funcs[CALLER]['owner']
 U,I,P=map(lit,[TARGET['user_id'],TARGET['invoice_id'],TARGET['payment_id']])
 expected=copy.deepcopy(lease); expected.pop('original_presentation_definition')
 # No evidence payload embedded in the DO or function catalogue: only private lease hashes.
 script=f"""-- PRIVATE DRAFT. Rendering is not approval to apply. One atomic DO; no source/contract writes.
-- Mandatory read-only lease TTL: 10 minutes. Production execution and UI publication are separate gates.
DO $presentation_migration$
DECLARE expected constant jsonb := {j(expected)};
 actual_functions jsonb; actual_tables jsonb; actual_rows jsonb; defaults_now jsonb;
 before_functions jsonb; after_functions jsonb; epoch_before bigint; affected integer;
 v_contract jsonb; v_link jsonb; v_invoice jsonb; v_payment jsonb; probe jsonb; result jsonb; annotation jsonb;
 new_oid oid; new_acl jsonb; grantee record; receipt jsonb; owner_name text := {lit(owner)};
BEGIN
 PERFORM pg_catalog.set_config('search_path','pg_catalog',true);
 PERFORM set_config('lock_timeout','2s',true);
 PERFORM set_config('TimeZone','America/Sao_Paulo',true);
 IF clock_timestamp() < (expected->>'checked_at')::timestamptz - interval '5 seconds'
 OR clock_timestamp() > (expected->>'checked_at')::timestamptz + interval '10 minutes'
 THEN RAISE EXCEPTION 'fresh lease required'; END IF;
 IF current_database() IS DISTINCT FROM expected->>'database' OR current_user IS DISTINCT FROM expected->>'executor'
 OR public.lts_open_finance_pilot_owner_v1()::text IS DISTINCT FROM expected->>'pilot_owner'
 THEN RAISE EXCEPTION 'database, executor or pilot owner lease changed'; END IF;
 -- Cooperates with the already-installed financial migration; no financial call is made.
 PERFORM pg_advisory_xact_lock(hashtext('lts_p05_timestamp_invariance_20261016'));
 PERFORM pg_advisory_xact_lock(hashtext('lts_p05_presentation_20261016'));
 SELECT epoch INTO STRICT epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR UPDATE;
 IF epoch_before IS DISTINCT FROM (expected->>'epoch')::bigint THEN RAISE EXCEPTION 'epoch lease changed'; END IF;
 PERFORM payment_source_id FROM public.lts_card_settlement_expense_contract_v273
 WHERE user_id={U}::uuid AND payment_source_id={P}::uuid FOR SHARE;
 PERFORM id FROM public.lts_card_documentary_payment_link_v272
 WHERE user_id={U}::uuid AND payment_source_id={P}::uuid AND active FOR SHARE;
 PERFORM id FROM public.lts_open_finance_staging WHERE user_id={U}::uuid AND id IN({I}::uuid,{P}::uuid) ORDER BY id FOR SHARE;
 SELECT ({FUNCTIONS_SQL}) INTO actual_functions;
 SELECT ({TABLES_SQL}) INTO actual_tables;
 SELECT ({ROWS_SQL}) INTO actual_rows;
 SELECT ({DEFAULTS_SQL}) INTO defaults_now;
 IF actual_functions IS DISTINCT FROM expected->'functions' OR actual_tables IS DISTINCT FROM expected->'tables'
 OR actual_rows IS DISTINCT FROM expected->'rows' OR defaults_now IS DISTINCT FROM expected->'function_defaults'
 THEN RAISE EXCEPTION 'function, table, row or default ACL lease changed'; END IF;
 before_functions:=actual_functions;
 IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.lts_read_cache_epoch_v242'::regclass AND NOT tgisinternal)
 THEN RAISE EXCEPTION 'epoch must have no unreviewed trigger effects'; END IF;
 IF has_function_privilege('anon',{lit(CALLER)},'EXECUTE') OR has_function_privilege('authenticated',{lit(CALLER)},'EXECUTE')
 THEN RAISE EXCEPTION 'presentation helper must already be private'; END IF;
 IF has_any_column_privilege('anon','public.lts_card_settlement_expense_contract_v273','SELECT,INSERT,UPDATE,REFERENCES')
 OR has_any_column_privilege('authenticated','public.lts_card_settlement_expense_contract_v273','SELECT,INSERT,UPDATE,REFERENCES')
 OR has_table_privilege('service_role','public.lts_card_settlement_expense_contract_v273','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
 THEN RAISE EXCEPTION 'private contract privilege boundary changed'; END IF;
 SELECT to_jsonb(x) INTO STRICT v_contract FROM public.lts_card_settlement_expense_contract_v273 x WHERE user_id={U}::uuid AND payment_source_id={P}::uuid;
 SELECT to_jsonb(x) INTO STRICT v_link FROM public.lts_card_documentary_payment_link_v272 x WHERE user_id={U}::uuid AND payment_source_id={P}::uuid AND active;
 SELECT to_jsonb(x) INTO STRICT v_invoice FROM public.lts_open_finance_staging x WHERE user_id={U}::uuid AND id={I}::uuid;
 SELECT to_jsonb(x) INTO STRICT v_payment FROM public.lts_open_finance_staging x WHERE user_id={U}::uuid AND id={P}::uuid;
 IF v_contract->'active' IS DISTINCT FROM 'true'::jsonb OR (v_link-'created_at') IS DISTINCT FROM v_contract->'payload'->'link_contract'
 THEN RAISE EXCEPTION 'original documentary link or active contract changed'; END IF;
 probe:=jsonb_build_object('probe_marker','presentation-only','cards',jsonb_build_array(jsonb_build_object('cycles',jsonb_build_array(jsonb_build_object(
 'invoice_source_id',{I},'due_date',v_link->'expected_due_date','amount',v_link->'expected_amount','payment_status','probe_original_status','month','probe_original_month','items','[]'::jsonb)))));
"""
 if not recovery:
  script+=f""" IF to_regprocedure({lit(PROJECTOR)}) IS NOT NULL THEN RAISE EXCEPTION 'new helper must be absent'; END IF;
 EXECUTE $new_definition${PROJECTOR_DDL}$new_definition$;
 SELECT to_regprocedure({lit(PROJECTOR)}) INTO new_oid;
 -- New functions inherit default privileges. Remove every inherited grantee, including PUBLIC,
 -- before granting the exact two roles. Never ALTER DEFAULT PRIVILEGES or touch existing ACLs.
 FOR grantee IN SELECT DISTINCT a.grantee FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE p.oid=new_oid
 LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION {PROJECTOR} FROM %s',CASE WHEN grantee.grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(grantee.grantee)) END);
 END LOOP;
 EXECUTE format('GRANT EXECUTE ON FUNCTION {PROJECTOR} TO %I,service_role',owner_name);
 SELECT jsonb_agg(jsonb_build_object('grantee',pg_get_userbyid(a.grantee),'grantor',pg_get_userbyid(a.grantor),'privilege',a.privilege_type,'grantable',a.is_grantable) ORDER BY pg_get_userbyid(a.grantee)) INTO new_acl
 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid=new_oid;
 IF new_acl IS DISTINCT FROM (SELECT jsonb_agg(x ORDER BY x->>'grantee') FROM jsonb_array_elements(jsonb_build_array(
 jsonb_build_object('grantee',owner_name,'grantor',owner_name,'privilege','EXECUTE','grantable',false),
 jsonb_build_object('grantee','service_role','grantor',owner_name,'privilege','EXECUTE','grantable',false))) x)
 OR has_function_privilege('anon',new_oid,'EXECUTE') OR has_function_privilege('authenticated',new_oid,'EXECUTE')
 THEN RAISE EXCEPTION 'new helper effective ACL is not exact'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=new_oid AND proowner::regrole::text=owner_name AND NOT prosecdef AND provolatile='i' AND prokind='f' AND proparallel='u'
 AND proconfig=ARRAY['search_path=""'] AND prorettype='jsonb'::regtype AND md5(prosrc)={lit(md5(PROJECTOR_BODY))})
 THEN RAISE EXCEPTION 'new helper identity, body or attributes mismatch'; END IF;
 EXECUTE $caller_definition${CALLER_DDL}$caller_definition$;
 annotation:=public.lts_card_payment_refresh_annotation_v273({U}::uuid,v_link,v_invoice,v_payment,v_contract->'payload',current_date);
 IF annotation IS DISTINCT FROM jsonb_build_object('status','identified_in_statement','basis','reviewed_original_link_and_exact_issuer_refresh',
 'payment_date',v_link->'expected_payment_date','bank_posting_date',v_link->'expected_payment_date','bank_posting_status','POSTED',
 'issuer_payment_date',left(v_contract#>>'{{payload,issuer_payments,0,paymentDate}}',10),'issuer_payment_type','FULL_PAYMENT',
 'amount',v_link->'expected_amount','currency','BRL','cash_effect','none')
 THEN RAISE EXCEPTION 'allowlisted annotation projection failed'; END IF;
 result:=public.lts_card_documentary_payment_presentation_v272({U}::uuid,probe);
 IF result#>'{{cards,0,cycles,0,documentary_payment_evidence}}' IS DISTINCT FROM annotation
 OR (result#-'{{cards,0,cycles,0,documentary_payment_evidence}}') IS DISTINCT FROM probe
 OR public.lts_card_documentary_payment_presentation_v272({U}::uuid,result) IS DISTINCT FROM result
 THEN RAISE EXCEPTION 'presentation projection changed non-annotation fields or is not idempotent'; END IF;
"""
 else:
  old=original['original_presentation_definition']
  script+=f""" IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc p WHERE p.oid NOT IN({lit(CALLER)}::regprocedure,{lit(PROJECTOR)}::regprocedure) AND position('lts_card_payment_refresh_annotation_v273' in p.prosrc)>0)
 THEN RAISE EXCEPTION 'later textual caller adopted projector; reconcile recovery'; END IF;
 EXECUTE $restore_caller${old}$restore_caller$;
 -- Never CASCADE. New dependents make the entire DO fail and roll back restoration.
 EXECUTE 'DROP FUNCTION {PROJECTOR} RESTRICT';
 IF to_regprocedure({lit(PROJECTOR)}) IS NOT NULL THEN RAISE EXCEPTION 'projector was not removed'; END IF;
 IF md5(pg_get_functiondef({lit(CALLER)}::regprocedure)) IS DISTINCT FROM {lit(md5(old))}
 THEN RAISE EXCEPTION 'restored presentation definition mismatch'; END IF;
"""
 script+=f""" SELECT ({FUNCTIONS_SQL}) INTO after_functions;
 -- Every function outside the two presentation helpers remains byte-identical, including RPC,
 -- generation guards and the financial guard. Metadata reads only, never expense execution.
 IF (SELECT jsonb_agg(x ORDER BY x->>'signature') FROM jsonb_array_elements(after_functions) x WHERE x->>'signature' NOT IN({lit(CALLER)},{lit(PROJECTOR)}))
 IS DISTINCT FROM (SELECT jsonb_agg(x ORDER BY x->>'signature') FROM jsonb_array_elements(before_functions) x WHERE x->>'signature' NOT IN({lit(CALLER)},{lit(PROJECTOR)}))
 THEN RAISE EXCEPTION 'untouched dependency changed'; END IF;
 IF (SELECT x-'definition_md5'-'body_md5' FROM jsonb_array_elements(after_functions) x WHERE x->>'signature'={lit(CALLER)})
 IS DISTINCT FROM (SELECT x-'definition_md5'-'body_md5' FROM jsonb_array_elements(before_functions) x WHERE x->>'signature'={lit(CALLER)})
 THEN RAISE EXCEPTION 'caller OID, owner, ACL or attributes changed'; END IF;
 IF (SELECT x->>'body_md5' FROM jsonb_array_elements(after_functions) x WHERE x->>'signature'={lit(CALLER)}) IS DISTINCT FROM {lit(md5(CALLER_BODY) if not recovery else next(f for f in original['functions'] if f['signature']==CALLER)['body_md5'])}
 THEN RAISE EXCEPTION 'caller body mismatch'; END IF;
 SELECT ({TABLES_SQL}) INTO actual_tables;
 SELECT ({ROWS_SQL}) INTO actual_rows;
 SELECT ({DEFAULTS_SQL}) INTO defaults_now;
 IF actual_tables IS DISTINCT FROM expected->'tables' OR actual_rows IS DISTINCT FROM expected->'rows' OR defaults_now IS DISTINCT FROM expected->'function_defaults'
 THEN RAISE EXCEPTION 'table, evidence row or default ACL changed'; END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton AND epoch=epoch_before;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 OR (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) IS DISTINCT FROM epoch_before+1
 THEN RAISE EXCEPTION 'epoch CAS failed'; END IF;
 receipt:=jsonb_build_object('status','{mode}_verified','checked_at',clock_timestamp(),'epoch_before',epoch_before,'epoch_after',epoch_before+1,
 'functions',after_functions,'evidence_rows_unchanged',true,'tables_unchanged',true,'function_defaults_unchanged',true,
 'annotation_allowlisted',{str(not recovery).lower()},'financial_guard_unchanged',true,'reader_rpc_executed',false);
 RAISE NOTICE 'P05_PRESENTATION_RECEIPT %',receipt;
END $presentation_migration$;
"""
 return script

def main():
 a=argparse.ArgumentParser();a.add_argument('--lease',required=True);a.add_argument('--mode',choices=['apply','recovery'],default='apply');a.add_argument('--installation-receipt');a.add_argument('--original-lease');a.add_argument('--output',required=True);args=a.parse_args()
 lease=load_lease(args.lease)
 installation=json.loads(Path(args.installation_receipt).read_text()) if args.installation_receipt else None
 original=load_lease(args.original_lease) if args.original_lease else None
 sql=render(lease,args.mode,installation,original)
 Path(args.output).write_text(sql)
 print(json.dumps({'mode':args.mode,'sha256':hashlib.sha256(sql.encode()).hexdigest(),'lease_checked_at':lease['checked_at'],'applied':False}))
if __name__=='__main__':main()
