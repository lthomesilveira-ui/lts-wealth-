"""Each mutation invalidates a specific documentary identity and runs in ROLLBACK."""
EVENT="'00000000-0000-4000-8000-000000000502'"
SOURCE="'00000000-0000-4000-8000-000000000602'"
BALANCE="'00000000-0000-4000-8000-000000000610'"
def event(setter):return f'UPDATE public.financial_events SET {setter} WHERE id={EVENT};'
def bank(setter):return f'UPDATE public.lts_open_finance_staging SET {setter} WHERE id={SOURCE};'
def balance(setter):return f'UPDATE public.lts_open_finance_staging SET {setter} WHERE id={BALANCE};'
def binding(setter):return f'UPDATE public.lts_v229_documentary_match SET {setter} WHERE staging_id={SOURCE};'
def ev(key,value):return binding(f"evidence=jsonb_set(evidence,'{{{key}}}','{value}')")
def meta(key,value):return event(f"metadata=jsonb_set(metadata,'{{{key}}}','{value}')")
CASES=[
 ('pending bank',bank("normalized_payload=jsonb_set(normalized_payload,'{status}','\"PENDING\"')")),
 ('deleted bank',bank('provider_deleted_at=now()')),
 ('wrong currency',bank("currency='USD'")),
 ('wrong resource',bank("resource_type='card_transaction'")),
 ('not checking',bank("normalized_payload=jsonb_set(normalized_payload,'{account_type}','\"SAVINGS\"')")),
 ('wrong amount',bank('signed_amount=-26')),
 ('wrong posting date',bank("posting_date='2020-10-07'")),
 ('wrong bank',bank("institution_code='341'")),
 ('foreign bank owner',bank("user_id='00000000-0000-4000-8000-000000000002'")),
 ('changed source hash',bank("raw_hash=repeat('b',64)")),
 ('empty hash',bank("raw_hash=''")),
 ('missing occurred timestamp',bank('occurred_at=NULL')),
 ('different provider account',bank("normalized_payload=jsonb_set(normalized_payload,'{provider_account_id}','\"other\"')")),
 ('wrong bank contract',bank("description_raw='CONTR 000124 PARC 002/003'")),
 ('wrong bank installment',bank("description_raw='CONTR 000123 PARC 001/003'")),
 ('wrong bank total term',bank("description_raw='CONTR 000123 PARC 002/004'")),
 ('foreign event owner',event("user_id='00000000-0000-4000-8000-000000000002'")),
 ('suppressed event',event('is_suppressed=true')),
 ('canceled event',event("status='canceled'")),
 ('own transfer',event('is_internal_transfer=true')),
 ('not expense',event("nature='income'")),
 ('wrong event account',event("account_id='00000000-0000-4000-8000-000000000199'")),
 ('wrong series contract',meta('contract_ref','"unrelated-contract"')),
 ('wrong event installment',meta('installment_number','1')),
 ('invalid installment',meta('installment_number','"not-numeric"')),
 ('overflow installment',meta('installment_number','"999999999999999999"')),
 ('wrong total term',meta('installments_total','4')),
 ('missing account confirmation',meta('account_assignment_status','"unconfirmed"')),
 ('wrong assigned bank',meta('account_assignment','"Itaú"')),
 ('foreign binding owner',binding("user_id='00000000-0000-4000-8000-000000000002'")),
 ('wrong binding reference',binding("source_ref='unrelated-event'")),
 ('wrong binding date',binding("canonical_date='2020-10-04'")),
 ('wrong binding amount',binding('signed_amount=-26')),
 ('wrong binding bank',binding("bank='Itaú'")),
 ('wrong binding basis',ev('basis','"amount_date_only"')),
 ('cash-creation binding',ev('no_new_cash_event','false')),
 ('missing binding hash',binding("evidence=evidence-'raw_hash'")),
 ('wrong documented contract',ev('contract','"000124"')),
 ('wrong documented installment',ev('installment','"001/003"')),
 ('wrong documented nominal date',ev('nominal_due_date','"2020-10-04"')),
 ('wrong documented actual date',ev('actual_posting_date','"2020-10-07"')),
 ('foreign balance owner',balance("user_id='00000000-0000-4000-8000-000000000002'")),
 ('deleted balance',balance('provider_deleted_at=now()')),
 ('wrong balance bank',balance("institution_code='341'")),
 ('wrong balance currency',balance("currency='USD'")),
 ('wrong balance account',balance("normalized_payload=jsonb_set(normalized_payload,'{provider_account_id}','\"other\"')")),
 ('position predates payment',balance("normalized_payload=jsonb_set(normalized_payload,'{as_of}','\"2020-10-05T12:00:00Z\"')")),
 ('invalid position timestamp',balance("normalized_payload=jsonb_set(normalized_payload,'{as_of}','\"not-a-time\"')")),
 ('two bank debits claim same installment',f"""INSERT INTO public.lts_open_finance_staging
 SELECT (jsonb_populate_record(NULL::public.lts_open_finance_staging,to_jsonb(s)||jsonb_build_object('id','00000000-0000-4000-8000-000000000603','raw_hash',repeat('b',64)))).*
 FROM public.lts_open_finance_staging s WHERE id={SOURCE};
 INSERT INTO public.lts_v229_documentary_match SELECT user_id,'00000000-0000-4000-8000-000000000603',source_ref,canonical_date,bank,signed_amount,
 jsonb_set(evidence,'{{raw_hash}}',to_jsonb(repeat('b',64))),created_at FROM public.lts_v229_documentary_match WHERE staging_id={SOURCE};"""),
]
ASSERTION="""DO $$ DECLARE s jsonb;BEGIN
 s:=public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24');
 IF s#>>'{volvo,confirmed_loaded_paid_count}'<>'0' OR (s#>>'{volvo,unconfirmed_past_count}')::integer NOT IN(1,2)
 OR s#>>'{volvo,future_count}'<>'1'
 OR EXISTS(SELECT 1 FROM public.lts_documentary_contract_payments_v310('00000000-0000-4000-8000-000000000001','2020-10-24'))
 THEN RAISE EXCEPTION 'Invalid documentary proof accepted';END IF;
 END $$;"""
