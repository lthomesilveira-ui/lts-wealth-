"""Exclude an evidenced own outbound PIX from spending, preserving its cash leg."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
NS='lts_product_refresh_private_v415'
EXPENSE='public.lts_v229_expense_rows(uuid,date,date)'
PROFILE=NS+'.review_profile_v450()'
HELPER=NS+'.documented_own_out_v450(uuid)'
OLD=' WHERE e.source_table=r.source_table AND e.source_ref=r.source_ref)'
NEW=OLD+"""
AND NOT EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.documented_own_out_v450(p_user_id) own_out
 WHERE r.source_table='lts_open_finance_staging' AND r.source_ref=own_out.source_id::text
 AND r.coverage_mode='bank_observed_individual' AND c.category='Transferência própria'
 AND r.event_date=own_out.event_date AND r.amount=-own_out.signed_amount)"""
BODY="""SELECT s.id,s.posting_date,s.signed_amount
FROM public.lts_open_finance_staging s
JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id
 AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 AND d.category_label='Transferência própria'
WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.signed_amount<0 AND s.posting_date<=current_date
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.raw_payload->>'operationType'='PIX' AND s.raw_payload#>>'{paymentData,paymentMethod}'='PIX'
 AND s.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') ~ '^[0-9]{11}$'
 AND regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
  =regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 AND s.institution_code IS DISTINCT FROM s.raw_payload#>>'{paymentData,receiver,routingNumber}'
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.provider_deleted_at IS NULL AND b.currency='BRL'
  AND b.provider_account_ref=s.provider_account_ref AND b.institution_code=s.institution_code
  AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')
   =regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g'))
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.provider_deleted_at IS NULL AND b.currency='BRL'
  AND b.institution_code=s.raw_payload#>>'{paymentData,receiver,routingNumber}'
  AND b.normalized_payload->>'account_type' IN('CHECKING_ACCOUNT','SAVINGS_ACCOUNT')
  AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')
   =regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g'))"""
def original(name):return (ROOT/name).read_text().rstrip('\n')+'\n'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def dollar(s,tag):
 assert '$'+tag+'$' not in s
 return '$'+tag+'$'+s+'$'+tag+'$'
def helper():
 return f'''CREATE OR REPLACE FUNCTION {NS}.documented_own_out_v450(p_user_id uuid)
 RETURNS TABLE(source_id uuid, event_date date, signed_amount numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
{BODY}
$function$
'''
def expense():
 s=original('expense-original.sql');assert s.count(OLD)==1;return s.replace(OLD,NEW)
def profile():
 s=original('profile-original.sql');m=re.search(r'\$manifest\$([\s\S]*?)\$manifest\$',s);p=json.loads(m.group(1))
 matches=[x for x in p['producers'] if x['signature']==EXPENSE];assert len(matches)==1
 assert matches[0]['md5']==md5(original('expense-original.sql'));matches[0]['md5']=md5(expense())
 assert not any(x['signature']==HELPER for x in p['producers'])
 p['producers'].append({'signature':HELPER,'md5':md5(helper())})
 return s[:m.start(1)]+json.dumps(p,indent=2)+'\n'+s[m.end(1):]
def lifecycle(reverse=False):
 targets=[(EXPENSE,original('expense-original.sql'),expense()),(PROFILE,original('profile-original.sql'),profile())]
 checks=[];changes=[]
 for signature,prior,after in targets:
  a,b=(after,prior) if reverse else (prior,after)
  checks.append(f"""p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('{md5(a)}','{md5(b)}') OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM ARRAY['search_path=""'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'own-out reader changed concurrently: %',p;END IF;""")
  changes.append(f"IF md5(pg_get_functiondef('{signature}'::regprocedure))='{md5(a)}' THEN EXECUTE {dollar(b,'replacement')};END IF;\nIF md5(pg_get_functiondef('{signature}'::regprocedure))<>'{md5(b)}' THEN RAISE EXCEPTION 'own-out reconstruction differs';END IF;")
 check_helper=f"""p:=to_regprocedure('{HELPER}');IF p IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h<>'{md5(helper())}' OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'own-out helper changed concurrently';END IF;END IF;"""
 result="BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $check$ DECLARE p regprocedure;h text;acl text;cfg text[];definer boolean;owner text;BEGIN\n"+'\n'.join(checks)+check_helper+'\nEND $check$;\n'
 if not reverse:result+=helper()+f';\nREVOKE ALL ON FUNCTION {HELPER} FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION {HELPER} TO service_role;\n'
 result+='DO $install$ BEGIN\n'+'\n'.join(changes)+'\nEND $install$;\nCOMMIT;\n';return result
if __name__=='__main__':
 for n,s in [('helper.sql',helper()),('expense-after.sql',expense()),('profile-after.sql',profile()),('install.sql',lifecycle()),('rollback.sql',lifecycle(True))]:(ROOT/n).write_text(s)
 manifest=[{'signature':sig,'before':md5(original(name)),'after':md5(after),'security_changed':False,'source_writes':False} for sig,name,after in [(EXPENSE,'expense-original.sql',expense()),(PROFILE,'profile-original.sql',profile())]]
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))
