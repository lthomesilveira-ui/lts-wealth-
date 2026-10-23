-- Synthetic JSON only. Caller owns BEGIN/ROLLBACK; this does not certify HTTP.
DO $fixtures$
DECLARE b jsonb;s jsonb;r jsonb;e jsonb;j jsonb;c jsonb;v jsonb;path text[];
 n integer:=0;passed integer:=0;ok boolean;receipt jsonb:='[]';
BEGIN
 b:='{"id":"event-a","user_id":"owner-a","account_id":"account-a","event_date":"2026-01-05","amount":-100,
 "category":"Educação","source":"user_confirmed_partial_obligation","description_raw":"Educação confirmada",
 "status":"scheduled","is_projection":true,"is_suppressed":false,"is_internal_transfer":false,"created_at":"2026-01-01T12:00:00+00:00",
 "metadata":{"obligation_amount":120,"paid_amount":20,"paid_bank_staging_id":"earlier-payment-a",
 "beneficiary":"Pessoa confirmada","schedule_evidence_files":["schedule.png"]}}';
 s:='{"id":"bank-a","user_id":"owner-a","provider_record_id":"provider-a","provider_account_ref":"checking-a",
 "institution_code":"341","posting_date":"2026-01-05","signed_amount":-100,"currency":"BRL","resource_type":"transaction",
 "raw_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","provider_deleted_at":null,
 "normalized_payload":{"status":"POSTED","account_type":"CHECKING_ACCOUNT","date":"2026-01-05","amount":-100},
 "raw_payload":{"status":"POSTED","type":"DEBIT","amount":-100,"date":"2026-01-05T12:00:00Z","paymentData":{"paymentMethod":"BOLETO","receiver":{"name":"ESCOLA TESTE LTDA",
 "documentNumber":{"type":"CNPJ","value":"00000000000000"}}}}}';
 r:='{"user_id":"owner-a","financial_event_id":"event-a","staging_id":"bank-a","bank":"Itaú",
 "expected_date":"2026-01-05","expected_amount":-100,"category":"Educação","beneficiary":"Pessoa confirmada","property_code":null}';
 e:=jsonb_build_object('version','exact-partial-obligation-v302',
 'basis','owner_confirmed_partial_obligation_and_documented_bank_schedule','bank_source_id','bank-a',
 'bank_raw_hash',s->>'raw_hash','provider_record_id','provider-a','provider_account_ref','checking-a','institution_code','341',
 'receiver_document_hash',md5('00000000000000'),'receiver_name','ESCOLA TESTE LTDA','partial_evidence_id','confirmation-a',
 'before_financial_event',b,'schedule_document',jsonb_build_object('file_name','schedule.png','library_file_id','synthetic-proof',
 'payee','Escola Teste','date','2026-01-05','amount',100));
 b:=b||jsonb_build_object('is_projection',false,'status','confirmed','metadata',b->'metadata'||jsonb_build_object(
 'bank_staging_id','bank-a','bank_reconciliation_evidence',jsonb_build_object('bank_raw_hash',s->>'raw_hash'),
 'realized_partial_obligation_v302',e-'before_financial_event'));
 j:=jsonb_build_object('event',b,'source',s,'binding',r,'evidence',e);
 FOR c IN SELECT x FROM jsonb_array_elements($cases$[
 {"name":"exact_confirmed_partial_obligation","expected":true},
 {"name":"same_instant_other_timezone","root":"event","path":["created_at"],"value":"2026-01-01T09:00:00-03:00","expected":true},
 {"name":"different_creation_instant","root":"event","path":["created_at"],"value":"2026-01-02T12:00:00+00:00","expected":false},
 {"name":"ambiguous_creation_timezone","root":"event","path":["created_at"],"value":"2026-01-01T12:00:00","expected":false},
 {"name":"provider_bookkeeping_hash_not_semantic_identity","root":"source","path":["raw_hash"],"value":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","expected":true},
 {"name":"other_provider_metadata_preserved","root":"source","path":["provider_updated_at"],"value":"2026-02-01T00:00:00Z","expected":true},
 {"name":"other_owner_event","root":"event","path":["user_id"],"value":"owner-b","expected":false},
 {"name":"other_owner_source","root":"source","path":["user_id"],"value":"owner-b","expected":false},
 {"name":"other_owner_binding","root":"binding","path":["user_id"],"value":"owner-b","expected":false},
 {"name":"wrong_event","root":"binding","path":["financial_event_id"],"value":"event-b","expected":false},
 {"name":"wrong_source","root":"source","path":["id"],"value":"bank-b","expected":false},
 {"name":"other_provider_record","root":"source","path":["provider_record_id"],"value":"provider-b","expected":false},
 {"name":"other_checking_account","root":"source","path":["provider_account_ref"],"value":"checking-b","expected":false},
 {"name":"other_bank","root":"source","path":["institution_code"],"value":"237","expected":false},
 {"name":"other_binding_bank","root":"binding","path":["bank"],"value":"Bradesco","expected":false},
 {"name":"scheduled_is_not_paid","root":"event","path":["is_projection"],"value":true,"expected":false},
 {"name":"cancelled_event","root":"event","path":["status"],"value":"cancelled","expected":false},
 {"name":"suppressed_event","root":"event","path":["is_suppressed"],"value":true,"expected":false},
 {"name":"transfer_not_expense","root":"event","path":["is_internal_transfer"],"value":true,"expected":false},
 {"name":"not_partial_obligation","root":"event","path":["source"],"value":"documented_contract_schedule","expected":false},
 {"name":"new_date_not_original_due_date","root":"event","path":["event_date"],"value":"2026-02-05","expected":false},
 {"name":"different_bank_posting_date","root":"source","path":["posting_date"],"value":"2026-02-05","expected":false},
 {"name":"different_amount","root":"source","path":["signed_amount"],"value":-99.99,"expected":false},
 {"name":"credit_is_not_debit","root":"source","path":["signed_amount"],"value":100,"expected":false},
 {"name":"foreign_currency","root":"source","path":["currency"],"value":"USD","expected":false},
 {"name":"card_is_not_checking","root":"source","path":["resource_type"],"value":"card_transaction","expected":false},
 {"name":"deleted_source","root":"source","path":["provider_deleted_at"],"value":"2026-02-01T00:00:00Z","expected":false},
 {"name":"pending_normalized_source","root":"source","path":["normalized_payload","status"],"value":"PENDING","expected":false},
 {"name":"pending_original_source","root":"source","path":["raw_payload","status"],"value":"PENDING","expected":false},
 {"name":"different_original_amount","root":"source","path":["raw_payload","amount"],"value":-99.99,"expected":false},
 {"name":"different_original_direction","root":"source","path":["raw_payload","type"],"value":"CREDIT","expected":false},
 {"name":"different_original_civil_date","root":"source","path":["raw_payload","date"],"value":"2026-01-06T12:00:00Z","expected":false},
 {"name":"different_normalized_date","root":"source","path":["normalized_payload","date"],"value":"2026-01-06","expected":false},
 {"name":"different_normalized_amount","root":"source","path":["normalized_payload","amount"],"value":-99.99,"expected":false},
 {"name":"credit_card_account","root":"source","path":["normalized_payload","account_type"],"value":"CREDIT_CARD","expected":false},
 {"name":"wrong_payment_method","root":"source","path":["raw_payload","paymentData","paymentMethod"],"value":"PIX","expected":false},
 {"name":"other_payee_document","root":"source","path":["raw_payload","paymentData","receiver","documentNumber","value"],"value":"11111111111111","expected":false},
 {"name":"wrong_payee_document_type","root":"source","path":["raw_payload","paymentData","receiver","documentNumber","type"],"value":"CPF","expected":false},
 {"name":"other_payee_name","root":"source","path":["raw_payload","paymentData","receiver","name"],"value":"OUTRA ESCOLA LTDA","expected":false},
 {"name":"wrong_category","root":"binding","path":["category"],"value":"Vestuário","expected":false},
 {"name":"person_not_in_original_confirmation","root":"binding","path":["beneficiary"],"value":"Outra pessoa","expected":false},
 {"name":"property_not_inferred","root":"binding","path":["property_code"],"value":"property-a","expected":false},
 {"name":"amount_only_basis","root":"evidence","path":["basis"],"value":"same_amount","expected":false},
 {"name":"wrong_version","root":"evidence","path":["version"],"value":"other","expected":false},
 {"name":"missing_partial_confirmation","root":"evidence","path":["partial_evidence_id"],"value":null,"expected":false},
 {"name":"no_original_schedule","root":"evidence","path":["schedule_document"],"value":null,"expected":false},
 {"name":"malformed_amount_fails_closed","root":"source","path":["signed_amount"],"value":"not a number","expected":false}
 ]$cases$::jsonb)x LOOP
  n:=n+1;v:=j;
  IF c ? 'root' THEN SELECT array_agg(x ORDER BY ord) INTO path FROM jsonb_array_elements_text(c->'path') WITH ORDINALITY p(x,ord);
   v:=jsonb_set(v,ARRAY[c->>'root']||path,c->'value',true);END IF;
  ok:=public.lts_partial_obligation_settlement_valid_v302(v->'event',v->'source',v->'binding',v->'evidence');
  IF ok IS DISTINCT FROM (c->>'expected')::boolean THEN RAISE EXCEPTION 'V302 fixture failed: %, got %',c->>'name',ok;END IF;
  passed:=passed+1;receipt:=receipt||jsonb_build_array(jsonb_build_object('case',c->>'name','pass',true));
 END LOOP;
 PERFORM set_config('lts.v302.synthetic_receipt',jsonb_build_object('cases',n,'passed',passed,'details',receipt)::text,true);
END $fixtures$;
