from pathlib import Path
import hashlib,json
p=Path(__file__).resolve().parent
a=(p/'adapter-before.sql').read_text().rstrip()+'\n';c=(p/'classifier-before.sql').read_text().rstrip()+'\n'
needle='RETURN lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof);'
assert a.count(needle)==1
a2=a.replace(needle,'RETURN lts_budget_private_v470.append_result(u,asof,lts_recurring_private_v469.calculate(plan,base,calendar,paid,asof),cards,baseline);')
needle2='IF cat IS NULL THEN RETURN NULL;END IF;'
assert c.count(needle2)==1
c2=c.replace(needle2,'IF cat IS NULL THEN RETURN lts_budget_private_v470.classification(u,e);END IF;')
def md5(x):return hashlib.md5(x.encode()).hexdigest()
guard="DO $guard$ BEGIN IF md5(pg_get_functiondef('lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure))<>'"+md5(a)+"' OR md5(pg_get_functiondef('lts_recurring_private_v469.classification(uuid,jsonb)'::regprocedure))<>'"+md5(c)+"' THEN RAISE EXCEPTION 'Recurring implementation changed';END IF;END $guard$;\n"
(p/'install.sql').write_text(guard+(p/'functions.sql').read_text()+'\n'+a2+';\n'+c2+';\n')
(p/'manifest.json').write_text(json.dumps({'adapter_before_md5':md5(a),'adapter_after_md5':md5(a2),'classifier_before_md5':md5(c),'classifier_after_md5':md5(c2)},indent=2)+'\n')
