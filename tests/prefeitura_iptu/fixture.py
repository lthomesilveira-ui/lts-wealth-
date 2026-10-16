"""Invented data only. No production rows or identifiers are read."""
from pathlib import Path
from build_sql import GATES
H=Path(__file__).resolve().parent
OWNER='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; OTHER='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
SOURCE='11111111-1111-4111-8111-111111111111'; TARGET='22222222-2222-4222-8222-222222222222'
PENDING=['33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444']
EVENTS=['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666']
ACCOUNT='77777777-7777-4777-8777-777777777777'; EXTRA='88888888-8888-4888-8888-888888888888'
OTHER_EVENT='abababab-abab-4aba-8aba-abababababab'
OP='synthetic-exact-obligation-v1'
L=lambda x:"'"+str(x).replace("'","''")+"'"
def reset_sql():
 s="TRUNCATE public.lts_access_audit,public.lts_flow_event_operation,public.lts_reconciliation_link,public.lts_v178_review_decision,public.financial_events,public.lts_open_finance_staging,public.accounts,public.lts_v229_read_cache,public.lts_read_cache_epoch_v242 RESTART IDENTITY CASCADE;\n"
 s+=f"INSERT INTO public.accounts VALUES('{ACCOUNT}','{OWNER}','Synthetic Bank',1234.56);\n"
 for i,uid,dt,st in [(SOURCE,OWNER,'2000-07-16','POSTED'),(PENDING[0],OWNER,'2000-07-15','PENDING'),(PENDING[1],OWNER,'2000-08-15','PENDING'),(EXTRA,OTHER,'2000-07-16','POSTED')]:
  s+=f"INSERT INTO public.lts_open_finance_staging VALUES('{i}','{uid}','transaction','BANK_X','synthetic-account','synthetic-record-{i}','99999999-9999-4999-8999-999999999999','BRL','{dt}',-13.37,'Synthetic municipal bill',repeat('a',64),'{{\"status\":\"{st}\",\"provider\":\"synthetic\"}}','{{\"status\":\"{st}\",\"account_type\":\"CHECKING_ACCOUNT\"}}',NULL,NULL,'2000-07-01T12:00:00Z','2000-07-01T12:00:00Z');\n"
 for i,dt in [(TARGET,'2000-07-15'),(EVENTS[0],'2000-06-15'),(EVENTS[1],'2000-08-15'),(OTHER_EVENT,'2000-05-15')]:
  s+=f"INSERT INTO public.financial_events(id,user_id,account_id,legacy_id,event_date,description_raw,description_normalized,amount,nature,category,counterparty,source,status,is_projection,metadata,created_at) VALUES('{i}','{OWNER}','{ACCOUNT}','synthetic-{i}','{dt}','Synthetic bill','Synthetic tax',-13.37,'expense','Synthetic Property Tax','Synthetic authority','itau_scheduled','scheduled',true,'{{\"property\":\"Synthetic House\",\"payment_type\":\"IPTU\",\"evidence\":\"invented fixture\",\"preserve_nested\":{{\"x\":1}}}}','2000-07-01T12:00:00Z');\n"
 s+="INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,100); INSERT INTO public.lts_v229_read_cache VALUES('"+OWNER+"','{\"synthetic\":true}');\n"
 return s

def base_contract():
 return dict(version=1,ready=True,gates=dict.fromkeys(GATES,True),owner_id=OWNER,source_id=SOURCE,target_id=TARGET,operation_id=OP,amount='-13.37',forecast_date='2000-07-15',posted_date='2000-07-16',category='Synthetic Property Tax',property_code='synthetic_property',property_label='Synthetic House',user_message_id='synthetic_confirmed_message',decision_basis='synthetic authenticated exact identity',marker='synthetic_exact_obligation_marker',reason='synthetic exact obligation reconciliation',note='Synthetic confirmation; no provider linkage; no new payment.',audit_action='synthetic_reconcile_exact',expected_epoch_delta=3,learning=dict(kind='authenticated_nominal_obligation_identity',scope='exact_confirmed_obligation_only',source_ref=SOURCE,target_event_id=TARGET,automatic_expansion=False,may_reuse_without_new_classification=['same canonical source and obligation','unchanged evidence','no conflict'],future_occurrence_policy='Separate nominal identity and authorization required; never merchant or amount alone.'),rollback=dict(authorized=False,committed_receipt_verified=False,receipt_md5=None))
