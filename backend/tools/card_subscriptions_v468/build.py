"""Deterministic source preparation; no network or database mutations."""
from pathlib import Path
import hashlib,json
p=Path(__file__).resolve().parent
before=(p/'build-before.sql').read_text()
assert hashlib.md5(before.encode()).hexdigest()=='b5c214f5a8e1f54c7a82038bedbc03a1'
after=before
changes=[
('DECLARE received_income_v443 jsonb;', 'DECLARE subscription_cards_v468 jsonb;\n received_income_v443 jsonb;'),
("  slots:=lts_projection_private_v412.scope_slots_v416(policy,slots,public.lts_card_cycles_v226(p_user_id));",
 "  subscription_cards_v468:=public.lts_card_cycles_v226(p_user_id);\n  slots:=lts_projection_private_v412.scope_slots_v416(policy,slots,subscription_cards_v468);"),
(" projection_result_v418:=lts_projection_private_v412.calculate(policy,history,slots,p_as_of);",
 " projection_result_v418:=lts_projection_private_v412.calculate(policy,history,slots,p_as_of);\n projection_result_v418:=lts_subscription_private_v468.append_result(p_user_id,p_as_of,projection_result_v418,subscription_cards_v468,baseline);")
]
for old,new in changes:
 assert after.count(old)==1,old
 after=after.replace(old,new)
(p/'build-after.sql').write_text(after)
setup=(p/'functions.sql').read_text()
install=setup+"\nDO $guard$\nBEGIN\n IF md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure)) <> 'b5c214f5a8e1f54c7a82038bedbc03a1' THEN\n RAISE EXCEPTION 'Projection builder changed; reconcile before applying V468';END IF;\nEND $guard$;\n"+after
(p/'install.sql').write_text(install)
manifest={'version':'v468','scope':'specific owner-approved card subscriptions','original_build_md5':hashlib.md5(before.encode()).hexdigest(),'installed_build_md5':hashlib.md5(after.encode()).hexdigest(),'files':{}}
for name in ['functions.sql','build-before.sql','build-after.sql','install.sql']:
 manifest['files'][name]=hashlib.sha256((p/name).read_bytes()).hexdigest()
(p/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'pass':True,'scope':manifest['scope'],'changed_build_fragments':len(changes),'files':len(manifest['files'])}))

