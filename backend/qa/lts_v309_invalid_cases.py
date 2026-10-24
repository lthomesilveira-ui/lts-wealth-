"""Synthetic mutations of one proved obligation; each runs inside ROLLBACK."""
TARGET="'00000000-0000-4000-8000-000000000206'"
SOURCE="'00000000-0000-4000-8000-000000000606'"
def event(setter):return f'UPDATE public.financial_events SET {setter} WHERE id={TARGET};'
def bank(setter):return f'UPDATE public.lts_open_finance_staging SET {setter} WHERE id={SOURCE};'
CASES=[
 ('pending bank',bank("normalized_payload=jsonb_set(normalized_payload,'{status}','\"PENDING\"')")),
 ('deleted bank',bank("provider_deleted_at=now()")),
 ('wrong currency',bank("currency='USD'")),
 ('wrong resource',bank("resource_type='card_transaction'")),
 ('savings account',bank("normalized_payload=jsonb_set(normalized_payload,'{account_type}','\"SAVINGS\"')")),
 ('wrong actual amount',bank("signed_amount=-81")),
 ('wrong bank date',bank("posting_date='2020-10-21'")),
 ('foreign source owner',bank("user_id='00000000-0000-4000-8000-000000000002'")),
 ('foreign event owner',event("user_id='00000000-0000-4000-8000-000000000002'")),
 ('suppressed event',event("is_suppressed=true")),
 ('still projected',event("is_projection=true")),
 ('not confirmed',event("status='scheduled'")),
 ('own transfer',event("is_internal_transfer=true")),
 ('wrong expected amount',f"UPDATE public.lts_realized_bank_event_v238 SET expected_amount=-80 WHERE financial_event_id={TARGET};"),
 ('wrong original obligation',event("metadata=jsonb_set(metadata,'{documentary_schedule_amount}','81')")),
 ('invalid numeric evidence',event("metadata=jsonb_set(metadata,'{documentary_schedule_amount}','\"not-numeric\"')")),
 ('wrong original due',event("metadata=jsonb_set(metadata,'{documentary_schedule_due_date}','\"2020-10-21\"')")),
 ('wrong installment',event("metadata=jsonb_set(metadata,'{installment_number}','7')")),
 ('wrong contract',event("metadata=jsonb_set(metadata,'{contract_ref}','\"UNRELATED\"')")),
 ('wrong bank routing',bank("institution_code='341'")),
 ('two candidate events',f"""INSERT INTO public.financial_events SELECT (jsonb_populate_record(NULL::public.financial_events,to_jsonb(f)||jsonb_build_object('id','00000000-0000-4000-8000-000000000207'))).* FROM public.financial_events f WHERE id={TARGET};
 INSERT INTO public.lts_realized_bank_event_v238 SELECT (jsonb_populate_record(NULL::public.lts_realized_bank_event_v238,to_jsonb(r)||jsonb_build_object('financial_event_id','00000000-0000-4000-8000-000000000207'))).* FROM public.lts_realized_bank_event_v238 r WHERE financial_event_id={TARGET};"""),
]
ASSERTION="""DO $$ DECLARE s jsonb;BEGIN
 s:=public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24');
 IF s#>>'{cipo_396,confirmed_loaded_paid_count}'<>'1' OR s#>>'{cipo_396,unconfirmed_past_count}'<>'1'
 THEN RAISE EXCEPTION 'Invalid evidence was accepted';END IF;
 END $$;"""
