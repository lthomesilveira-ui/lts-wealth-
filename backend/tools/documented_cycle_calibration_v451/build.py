"""Retain a documented C6 cycle when balanced issuer detail omits forecast fields."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IDENTITY = 'public.lts_c6_cycle_identity_v269(uuid)'
PROFILE = 'lts_product_refresh_private_v415.review_profile_v450()'

def original(name):
    return (ROOT/name).read_text().rstrip('\n')+'\n'

def md5(text):
    return hashlib.md5(text.encode()).hexdigest()

def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new)

def identity():
    s = original('identity-original.sql')
    s = replace_once(s, ' SELECT ci.reference_month,ci.due_date,', ' SELECT ci.reference_month,ci.due_date,ci.amount documentary_amount,')
    s = replace_once(s, ' SELECT provider_account_ref,reference_month,min(due_date) due_date,min(closing_date) closing_date,\n CASE WHEN count(forecast)=count(*)', ' SELECT provider_account_ref,reference_month,invoice_amount,min(due_date) due_date,min(closing_date) closing_date,\n CASE WHEN count(forecast)=count(*)')
    s = replace_once(s, '), anchor_groups AS MATERIALIZED (', '''), corroborated_provider_anchors_v451 AS MATERIALIZED (
 -- A processed, hash-matched full statement supplies the already established
 -- forecast offset only for the same balanced issuer cycle and account.
 -- Every known issuer forecast must agree. Keep source fields and conflicting
 -- observations unchanged; no amount, due date or forecast field is invented.
 SELECT p.provider_account_ref,p.reference_month,p.due_date,p.closing_date,
 coalesce(p.forecast,(
  SELECT d.forecast FROM documentary_anchors d
  WHERE d.provider_account_ref=p.provider_account_ref AND d.reference_month=p.reference_month
   AND d.due_date=p.due_date AND abs(d.closing_date-p.closing_date)<=1
   AND EXISTS(SELECT 1 FROM documented doc
    WHERE doc.reference_month=d.reference_month AND doc.due_date=d.due_date
     AND doc.documentary_amount=p.invoice_amount AND abs(doc.closing_date-p.closing_date)<=1)
   AND EXISTS(SELECT 1 FROM provider_rows r WHERE r.provider_account_ref=p.provider_account_ref
    AND r.reference_month=p.reference_month AND r.forecast=d.forecast)
   AND NOT EXISTS(SELECT 1 FROM provider_rows r WHERE r.provider_account_ref=p.provider_account_ref
    AND r.reference_month=p.reference_month AND r.forecast IS NOT NULL AND r.forecast<>d.forecast)
 )) forecast
 FROM provider_anchors p
), anchor_groups AS MATERIALIZED (''')
    return replace_once(s, 'SELECT * FROM documentary_anchors UNION ALL SELECT * FROM provider_anchors', 'SELECT * FROM documentary_anchors UNION ALL SELECT * FROM corroborated_provider_anchors_v451')

def profile():
    s = original('profile-original.sql')
    m = re.search(r'\$manifest\$([\s\S]*?)\$manifest\$',s)
    p = json.loads(m.group(1))
    matches = [x for x in p['producers'] if x['signature']==IDENTITY]
    assert len(matches)==1 and matches[0]['md5']==md5(original('identity-original.sql'))
    matches[0]['md5']=md5(identity())
    return s[:m.start(1)]+json.dumps(p,indent=2)+'\n'+s[m.end(1):]

def lifecycle(reverse=False):
    checks=[];changes=[]
    for signature,name,after,cfg in [
        (IDENTITY,'identity-original.sql',identity(),'''ARRAY['search_path=""','TimeZone=America/Sao_Paulo']'''),
        (PROFILE,'profile-original.sql',profile(),'''ARRAY['search_path=""']''')]:
        before=original(name);a,b=(after,before) if reverse else (before,after)
        checks.append(f'''p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('{md5(a)}','{md5(b)}') OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM {cfg} OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Documented C6 cycle changed concurrently: %',p;END IF;''')
        assert '$replacement$' not in b
        changes.append(f"IF md5(pg_get_functiondef('{signature}'::regprocedure))='{md5(a)}' THEN EXECUTE $replacement${b}$replacement$;END IF;\nIF md5(pg_get_functiondef('{signature}'::regprocedure))<>'{md5(b)}' THEN RAISE EXCEPTION 'Documented C6 cycle reconstruction differs';END IF;")
    return "BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $check$ DECLARE p regprocedure;h text;acl text;cfg text[];definer boolean;owner text;BEGIN\n"+'\n'.join(checks)+'\nEND $check$;\nDO $install$ BEGIN\n'+'\n'.join(changes)+'\nEND $install$;\nCOMMIT;\n'

if __name__=='__main__':
    assert md5(original('identity-original.sql'))=='8bb5a959015e5351c28820a39e987ca7'
    assert md5(original('profile-original.sql'))=='0fcbac491409a16786dc784f914a5179'
    for name,text in [('identity-after.sql',identity()),('profile-after.sql',profile()),('install.sql',lifecycle()),('rollback.sql',lifecycle(True))]:
        (ROOT/name).write_text(text)
    (ROOT/'manifest.json').write_text(json.dumps([{'signature':sig,'before':md5(original(name)),'after':md5(after),'source_writes':False,'security_changed':False} for sig,name,after in [(IDENTITY,'identity-original.sql',identity()),(PROFILE,'profile-original.sql',profile())]],indent=2)+'\n')
