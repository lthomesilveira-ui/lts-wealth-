from pathlib import Path
import hashlib,json
p=Path(__file__).resolve().parent
before=(p.parent/'card_subscriptions_v468/build-after.sql').read_text()
assert hashlib.md5(before.encode()).hexdigest()=='1656f562eed0cb8936252ec8ca9381cc'
needle=' projection_result_v418:=lts_subscription_private_v468.append_result(p_user_id,p_as_of,projection_result_v418,subscription_cards_v468,baseline);'
assert before.count(needle)==1
after=before.replace(needle,needle+'\n projection_result_v418:=lts_recurring_private_v469.append_result(p_user_id,p_as_of,projection_result_v418,subscription_cards_v468,baseline);')
cl=(p/'classifier-before.sql').read_text()
# The source export can have one final newline; function digest must be exact.
while hashlib.md5(cl.encode()).hexdigest()!='4bc0f47babbba8bf30fced74161cf19a' and cl.endswith('\n'):cl=cl[:-1]
assert hashlib.md5(cl.encode()).hexdigest()=='4bc0f47babbba8bf30fced74161cf19a'
assert cl.count('SELECT coalesce((')==1 and cl.count('),p_event)\n$function$')==1
classified=cl.replace('SELECT coalesce((', 'SELECT coalesce(lts_recurring_private_v469.classification(p_user_id,p_event),coalesce((',1).replace('),p_event)\n$function$', '),p_event))\n$function$')
(p/'build-after.sql').write_text(after)
(p/'classifier-after.sql').write_text(classified)
guard="\nDO $guard$ BEGIN\n IF md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure))<>'1656f562eed0cb8936252ec8ca9381cc' OR md5(pg_get_functiondef('public.lts_flow_classification_decision_v1(uuid,jsonb)'::regprocedure))<>'4bc0f47babbba8bf30fced74161cf19a' THEN RAISE EXCEPTION 'Predecessor changed; reconcile before applying';END IF;\nEND $guard$;\n"
(p/'install.sql').write_text((p/'functions.sql').read_text()+guard+after+';\n'+classified)
manifest={'version':'v469','original_build_md5':hashlib.md5(before.encode()).hexdigest(),'installed_build_md5':hashlib.md5(after.encode()).hexdigest(),'original_classifier_md5':hashlib.md5(cl.encode()).hexdigest(),'installed_classifier_md5':hashlib.md5(classified.encode()).hexdigest(),'files':{}}
for f in ['functions.sql','build-after.sql','classifier-before.sql','classifier-after.sql','install.sql']:
 manifest['files'][f]=hashlib.sha256((p/f).read_bytes()).hexdigest()
(p/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'pass':True,'changed_builder_fragments':1,'owner_data_included':False}))
