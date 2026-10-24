"""Emit a leased read-only contract reader patch from its reviewed definition."""
from pathlib import Path
import hashlib,json,re,sys

ROOT=Path(__file__).resolve().parents[2]
definition=json.load(sys.stdin)['definition']
source=re.search(r'AS \$function\$([\s\S]*?)\$function\$',definition).group(1)
start=source.index('), candidates AS MATERIALIZED (')
end=source.index('), effective AS MATERIALIZED (',start)
old=source[start:end]
new=(ROOT/'backend/patches/v310/read_state_candidates.sql').read_text().rstrip()+'\n'
old_number="CASE WHEN f.metadata->>'installment_number' ~ '^[0-9]+$' THEN"
new_number="CASE WHEN f.metadata->>'installment_number' ~ '^[0-9]+$' AND pg_catalog.pg_input_is_valid(f.metadata->>'installment_number','integer') THEN"
assert source.count(old_number)==1
updated=definition.replace(source,(source[:start]+new+source[end:]).replace(old_number,new_number))
digest=lambda value:hashlib.md5(value.encode()).hexdigest()
before,after=digest(definition),digest(updated)
assert before=='626708b820a75e3db07fca3045e10ab0','Reviewed V309 definition changed'
helper=(ROOT/'backend/patches/v310/documentary_contract_payments.sql').read_text()
helper_body=re.search(r'AS \$fn\$([\s\S]*?)\$fn\$',helper).group(1)
attrs="jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile)"
print("-- V310: preserve existing documentary installment payments in the dated contract reader.")
print("DO $guard$ DECLARE p record;BEGIN")
for signature,md5 in [('public.lts_bank_posted_rows_v231(uuid)','157b74634a2584dbfb1fa063c73a91ce'),('public.lts_realized_bank_sources_v238(uuid)','02696060487b81ddf0592be23a2e044f')]:
 print(f"IF md5(pg_get_functiondef('{signature}'::regprocedure))<>'{md5}' THEN RAISE EXCEPTION 'V310 dependency changed';END IF;")
print(f"IF md5(pg_get_functiondef('public.lts_commitment_read_state_v309(uuid,date)'::regprocedure)) NOT IN('{before}','{after}') THEN RAISE EXCEPTION 'V310 target lease changed';END IF;")
print("SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.lts_documentary_contract_payments_v310(uuid,date)');")
print(f"IF FOUND AND (md5(p.prosrc)<>'{digest(helper_body)}' OR p.prosecdef OR p.proowner<>current_user::regrole::oid OR p.provolatile<>'s' OR p.proconfig IS DISTINCT FROM ARRAY['search_path=\"\"']::text[] OR has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')) THEN RAISE EXCEPTION 'V310 helper lease changed';END IF;END $guard$;")
print(helper)
print(f"""DO $patch$ DECLARE d text;s text;n text;attrs jsonb;
old_source text:=$old${old}$old$;
new_source text:=$new${new}$new$;
BEGIN
 SELECT pg_get_functiondef(p.oid),p.prosrc,{attrs} INTO d,s,attrs FROM pg_proc p
 WHERE p.oid='public.lts_commitment_read_state_v309(uuid,date)'::regprocedure;
 IF md5(d)='{after}' THEN RETURN;END IF;
 IF length(s)-length(replace(s,old_source,''))<>length(old_source) THEN RAISE EXCEPTION 'V310 source boundary changed';END IF;
 n:=replace(s,old_source,new_source);
 n:=replace(n,$old_number${old_number}$old_number$,$new_number${new_number}$new_number$);
 EXECUTE replace(d,s,n);
 IF md5(pg_get_functiondef('public.lts_commitment_read_state_v309(uuid,date)'::regprocedure))<>'{after}'
 OR attrs IS DISTINCT FROM(SELECT {attrs} FROM pg_proc p WHERE p.oid='public.lts_commitment_read_state_v309(uuid,date)'::regprocedure)
 THEN RAISE EXCEPTION 'V310 target verification failed';END IF;
END $patch$;""")
