-- Complete C6 identities, whole workbook records, card-cycle JSON and a partial-month slice.
-- Only the request clock field computed_at is excluded from the card-cycle comparison.
\set ON_ERROR_STOP on
begin isolation level repeatable read;
 set local timezone='America/Sao_Paulo';
 set local statement_timeout='55s';
 set local lock_timeout='1s';
 create temp table v298_readers_before on commit drop as select (select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_c6_cycle_identity_v269(public.lts_open_finance_pilot_owner_v1()) r) c6,(select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_card_workbook_bank_rows_v1(public.lts_open_finance_pilot_owner_v1()) r) workbook,public.lts_card_cycles_v226(public.lts_open_finance_pilot_owner_v1())-'computed_at' cycles,(select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2019-04-12','2019-04-22') r) partial;

\ir ../patches/v298/review_source_lookup.sql
\ir ../patches/v298/review_normalization.sql
\ir ../patches/v298/c6_reuse.sql
\ir ../patches/v298/workbook_unchanged_row.sql
\ir ../patches/v298/card_cycle_reuse.sql
 create temp table v298_readers_after on commit drop as select (select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_c6_cycle_identity_v269(public.lts_open_finance_pilot_owner_v1()) r) c6,(select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_card_workbook_bank_rows_v1(public.lts_open_finance_pilot_owner_v1()) r) workbook,public.lts_card_cycles_v226(public.lts_open_finance_pilot_owner_v1())-'computed_at' cycles,(select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2019-04-12','2019-04-22') r) partial;
 do $$declare k text;
begin for k in select jsonb_object_keys(to_jsonb(r)) from v298_readers_before r loop if (select to_jsonb(r)->k from v298_readers_before r) is distinct from (select to_jsonb(r)->k from v298_readers_after r) then raise exception 'V298 reader mismatch: %',k;
end if;
end loop;
end$$;
 select jsonb_build_object('status','PASS','c6_rows',jsonb_array_length(c6),'workbook_rows',jsonb_array_length(workbook),'partial_rows',jsonb_array_length(partial),'c6_digest',md5(c6::text),'workbook_digest',md5(workbook::text),'cycles_digest',md5(cycles::text),'partial_digest',md5(partial::text)) as receipt from v298_readers_after;
 rollback;
