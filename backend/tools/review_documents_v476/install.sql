-- The authenticated owner may register a private document for manual review.
create or replace function public.lts_browser_review_document_file_v476(
  p_sha256 text, p_original_name text, p_mime_type text, p_size_bytes bigint, p_document_type text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := public.lts_browser_assert_user_v1();
  object_path text;
  existing_id uuid;
  stored_metadata jsonb;
  registered jsonb;
begin
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' or
     coalesce(p_size_bytes, 0) not between 1 and 52428800 or
     nullif(trim(p_original_name), '') is null or
     p_document_type is null or p_document_type not in
       ('other_financial_document', 'bank_statement', 'card_statement', 'financing_statement') then
    raise exception 'invalid document parameters' using errcode = '22023';
  end if;
  object_path := owner_id::text || '/documents/' || p_sha256;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(object_path, 476));
  select metadata into stored_metadata from storage.objects
    where bucket_id = 'lts-documents' and name = object_path;
  if not found then
    return jsonb_build_object('ok', true, 'state', 'upload_required', 'storage_path', object_path);
  end if;
  if (stored_metadata->>'size')::bigint is distinct from p_size_bytes then
    raise exception 'document size mismatch' using errcode = '22023';
  end if;
  select id into existing_id from public.lts_input_inbox
    where user_id = owner_id and storage_path = object_path limit 1;
  if existing_id is not null then
    return jsonb_build_object('ok', true, 'state', 'received', 'inbox_id', existing_id);
  end if;
  registered := public.lts_browser_register_document_v2(
    object_path, p_original_name, coalesce(nullif(stored_metadata->>'mimetype',''), p_mime_type),
    p_size_bytes, null, jsonb_build_object('source','updates_document_review',
    'document_type',p_document_type,'document_association',jsonb_build_object('document_type',p_document_type),
    'requested_action','ingest_reconcile','sha256',p_sha256));
  return registered || jsonb_build_object('state','received');
end;
$$;
revoke all on function public.lts_browser_review_document_file_v476(text,text,text,bigint,text)
  from public, anon, authenticated, service_role;
grant execute on function public.lts_browser_review_document_file_v476(text,text,text,bigint,text)
  to authenticated;
