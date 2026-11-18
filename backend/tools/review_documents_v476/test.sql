\set ON_ERROR_STOP on
begin;
create role anon;
create role authenticated;
create role service_role;
create schema storage;
create table storage.objects(bucket_id text, name text, metadata jsonb);
create table public.lts_input_inbox(id uuid default gen_random_uuid(), user_id uuid, storage_path text, context jsonb);
create function public.lts_browser_assert_user_v1() returns uuid language sql as
  $$select '00000000-0000-4000-8000-000000000001'::uuid$$;
create function public.lts_browser_register_document_v2(text,text,text,bigint,text,jsonb)
returns jsonb language sql as $$
  insert into public.lts_input_inbox(user_id,storage_path,context) values(public.lts_browser_assert_user_v1(),$1,$6)
  returning jsonb_build_object('ok',true,'inbox_id',id);
$$;
\ir install.sql
do $$
declare
  digest text := repeat('a',64);
  first_result jsonb;
  second_result jsonb;
  resumed jsonb;
begin
  first_result := public.lts_browser_review_document_file_v476(digest,'Example.pdf','application/pdf',87,'other_financial_document');
  assert first_result->>'state'='upload_required';
  assert (select count(*) from public.lts_input_inbox)=0;
  insert into storage.objects values('lts-documents', first_result->>'storage_path','{"size":87,"mimetype":"application/pdf"}');
  second_result := public.lts_browser_review_document_file_v476(digest,'Example.pdf','application/pdf',87,'other_financial_document');
  resumed := public.lts_browser_review_document_file_v476(digest,'Renamed.pdf','application/pdf',87,'other_financial_document');
  assert second_result->>'state'='received' and second_result->>'inbox_id' is not null;
  assert resumed->>'inbox_id'=second_result->>'inbox_id';
  assert (select count(*) from public.lts_input_inbox)=1;
  assert (select context#>>'{document_association,document_type}' from public.lts_input_inbox)='other_financial_document';
  begin
    perform public.lts_browser_review_document_file_v476(digest,'Example.pdf','application/pdf',1,'other_financial_document');
    raise exception 'inconsistent bytes accepted';
  exception when sqlstate '22023' then null; end;
end;
$$;
rollback;
