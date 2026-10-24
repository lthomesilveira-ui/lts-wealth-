-- Extend the existing isolated synthetic fixture. No production records.
ALTER TABLE public.lts_open_finance_staging
 ADD raw_hash text,ADD occurred_at timestamptz,ADD provider_account_ref text,ADD first_seen_at timestamptz DEFAULT now();
CREATE TABLE public.lts_v229_documentary_match(user_id uuid,staging_id uuid,source_ref text,canonical_date date,
 bank text,signed_amount numeric,evidence jsonb,created_at timestamptz DEFAULT now(),PRIMARY KEY(user_id,staging_id));
DELETE FROM public.lts_realized_bank_event_v238 WHERE financial_event_id='00000000-0000-4000-8000-000000000502';
UPDATE public.financial_events SET event_date='2020-10-05',is_projection=true,status='scheduled',
 metadata=metadata||'{"account_assignment_status":"user_confirmed","account_assignment":"Bradesco","installments_total":3}'::jsonb
 WHERE id='00000000-0000-4000-8000-000000000502';
UPDATE public.lts_open_finance_staging SET raw_hash=repeat('a',64),occurred_at='2020-10-06T10:00:00Z',
 provider_account_ref='synthetic-checking',description_raw='CONTR 000123 PARC 002/003 - synthetic installment',
 normalized_payload=normalized_payload||'{"provider_account_id":"synthetic-checking"}'::jsonb
 WHERE id='00000000-0000-4000-8000-000000000602';
INSERT INTO public.lts_open_finance_staging(id,user_id,currency,resource_type,normalized_payload,institution_code) VALUES
 ('00000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-000000000001','BRL','balance',
 '{"account_type":"CHECKING_ACCOUNT","provider_account_id":"synthetic-checking","as_of":"2020-10-24T12:00:00Z"}','237');
INSERT INTO public.lts_v229_documentary_match(user_id,staging_id,source_ref,canonical_date,bank,signed_amount,evidence) VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000602','synthetic-vehicle-2','2020-10-05','Bradesco',-25,
 jsonb_build_object('basis','owner_confirmed_exact_obligation','no_new_cash_event',true,'raw_hash',repeat('a',64),
 'nominal_due_date','2020-10-05','actual_posting_date','2020-10-06','contract','000123','installment','002/003'));
