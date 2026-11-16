"""Preserve settled C6 evidence through one explicitly reviewed issuer mode change."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
NS='lts_product_refresh_private_v415'
CYCLE='public.lts_card_cycle_settlement_v351(jsonb,jsonb)'
ANNOTATION='public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'
PROFILE=NS+'.review_profile_v450()'
HELPER=NS+'.reviewed_c6_mode_v450(jsonb,jsonb,jsonb)'
def original(name):return (ROOT/name).read_text().rstrip('\n')+'\n'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def patch(s,old,new):
 assert s.count(old)==1,(old,s.count(old));return s.replace(old,new)
def cycle():return patch(original('cycle-original.sql'),"x->>'paymentMode'='DEBIT_ACCOUNT'",NS+'.reviewed_c6_mode_v450(p_contract,p_link,x)')
def annotation():return patch(original('annotation-original.sql'),"pay->>'paymentMode'='DEBIT_ACCOUNT'",NS+'.reviewed_c6_mode_v450(p_contract,p_link,pay)')
def profile():
 s=original('profile-original.sql');m=re.search(r'\$manifest\$([\s\S]*?)\$manifest\$',s);p=json.loads(m.group(1))
 for sig,name,after in [(CYCLE,'cycle-original.sql',cycle()),(ANNOTATION,'annotation-original.sql',annotation())]:
  matches=[x for x in p['producers'] if x['signature']==sig];assert len(matches)==1
  assert matches[0]['md5']==md5(original(name));matches[0]['md5']=md5(after)
 assert not any(x['signature']==HELPER for x in p['producers']);p['producers'].append({'signature':HELPER,'md5':md5(original('helper.sql'))})
 return s[:m.start(1)]+json.dumps(p,indent=2)+'\n'+s[m.end(1):]
def dollar(s):
 assert '$replacement$'not in s;return '$replacement$'+s+'$replacement$'
def lifecycle(reverse=False):
 checks=[];changes=[]
 for sig,name,after in [(CYCLE,'cycle-original.sql',cycle()),(ANNOTATION,'annotation-original.sql',annotation()),(PROFILE,'profile-original.sql',profile())]:
  prior=original(name);a,b=(after,prior) if reverse else (prior,after)
  checks.append(f'''p:='{sig}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('{md5(a)}','{md5(b)}') OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM ARRAY['search_path=""'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'C6 reviewed reader changed concurrently: %',p;END IF;''')
  changes.append(f"IF md5(pg_get_functiondef('{sig}'::regprocedure))='{md5(a)}' THEN EXECUTE {dollar(b)};END IF;\nIF md5(pg_get_functiondef('{sig}'::regprocedure))<>'{md5(b)}' THEN RAISE EXCEPTION 'C6 reviewed reconstruction differs';END IF;")
 checks.append(f'''p:=to_regprocedure('{HELPER}');IF p IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h<>'{md5(original('helper.sql'))}' OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM ARRAY['search_path=""'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'C6 reviewed helper changed concurrently';END IF;END IF;''')
 result="BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $check$ DECLARE p regprocedure;h text;acl text;cfg text[];definer boolean;owner text;BEGIN\n"+'\n'.join(checks)+'\nEND $check$;\n'
 if not reverse:result+=original('helper.sql')+f';\nREVOKE ALL ON FUNCTION {HELPER} FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION {HELPER} TO service_role;\n'
 return result+'DO $install$ BEGIN\n'+'\n'.join(changes)+'\nEND $install$;\nCOMMIT;\n'
if __name__=='__main__':
 for n,s in [('cycle-after.sql',cycle()),('annotation-after.sql',annotation()),('profile-after.sql',profile()),('install.sql',lifecycle()),('rollback.sql',lifecycle(True))]:(ROOT/n).write_text(s)
 (ROOT/'manifest.json').write_text(json.dumps([{'signature':sig,'before':md5(original(name)),'after':md5(after),'security_changed':False,'source_writes':False} for sig,name,after in [(CYCLE,'cycle-original.sql',cycle()),(ANNOTATION,'annotation-original.sql',annotation()),(PROFILE,'profile-original.sql',profile())]],indent=2)+'\n')
