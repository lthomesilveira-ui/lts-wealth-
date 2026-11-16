"""Narrow only posted checking-account decision validation; never writes source rows."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parent
SIGNATURE='public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'
BASE_HASH='56e9806983eab4effd105fdf5ee302e8'
DAY_SCOPE_HASH='2dafdd9285b9e5ed7252c2ec3e3d9cc3'
def patch(s):
    def once(a,b):
        nonlocal s
        assert s.count(a)==1,a
        s=s.replace(a,b)
    once("v_scope_from date:=date '2013-10-10'; v_source_date date;", "v_scope_from date:=date '2013-10-10'; v_scope_to date:=current_date; v_source_date date; v_posted_bank boolean:=false;")
    once("INTO v_source_date FROM public.lts_open_finance_staging s WHERE s.user_id=v_uid AND s.id::text=v_source_ref;", """,s.resource_type='transaction' AND s.provider_deleted_at IS NULL
      AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
      AND s.normalized_payload->>'status'='POSTED'
    INTO v_source_date,v_posted_bank FROM public.lts_open_finance_staging s WHERE s.user_id=v_uid AND s.id::text=v_source_ref;""")
    once("IF v_source_date IS NOT NULL THEN v_scope_from:=greatest(date '2013-10-10',date_trunc('month',v_source_date)::date); END IF;", """IF v_source_date IS NOT NULL THEN v_scope_from:=greatest(date '2013-10-10',date_trunc('month',v_source_date)::date); END IF;
  -- A posted bank occurrence has an exact civil date. Validate both the pending
  -- occurrence and its resolution in that same day; retain the original month
  -- scope for card, monthly, legacy and incomplete provider observations.
  IF coalesce(v_posted_bank,false) AND v_source_date IS NOT NULL THEN
    v_scope_from:=greatest(date '2013-10-10',v_source_date);
    v_scope_to:=least(current_date,v_source_date);
  END IF;""")
    assert s.count('public.lts_v229_review_rows(v_uid,v_scope_from,current_date)')==3
    s=s.replace('public.lts_v229_review_rows(v_uid,v_scope_from,current_date)', 'public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to)')
    old="""if v_category is not null and not exists (
    select 1 from jsonb_array_elements_text(coalesce(public.lts_browser_card_category_options_v226()->'categories','[]'::jsonb)) option_category(value)
    where option_category.value=v_category
  ) and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from public.lts_category_catalog allowed_category
    where allowed_category.user_id=v_uid and allowed_category.active and allowed_category.category=v_category
  )"""
    new="""if v_category is not null and not exists (
    select 1 from public.lts_category_catalog allowed_category
    where allowed_category.user_id=v_uid and allowed_category.active and allowed_category.category=v_category
  ) and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from jsonb_array_elements_text(coalesce(public.lts_browser_card_category_options_v226()->'categories','[]'::jsonb)) option_category(value)
    where option_category.value=v_category
  )"""
    once(old,new)
    return s
def bank_reader_patch(s):
    before="""  select * into v_target
  from public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to) r
  where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  order by r.event_date desc
  limit 1;"""
    after="""  -- Posted checking-account facts cannot originate in the future-card union.
  -- Read the same expense component directly so a decision's cache invalidation
  -- does not rebuild unrelated card history during the atomic resolution check.
  IF coalesce(v_posted_bank,false) THEN
    select * into v_target
    from public.lts_v229_expense_rows(v_uid,v_scope_from,v_scope_to) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
    order by r.event_date desc limit 1;
  ELSE
"""+before+"""
  END IF;"""
    assert s.count(before)==1
    s=s.replace(before,after)
    before="""  select not exists(
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  ) into v_resolved;"""
    after="""  IF coalesce(v_posted_bank,false) THEN
    select not exists(
      select 1 from public.lts_v229_expense_rows(v_uid,v_scope_from,v_scope_to) r
      where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
    ) into v_resolved;
  ELSE
"""+before+"""
  END IF;"""
    assert s.count(before)==1
    return s.replace(before,after)
def installer(original,new,expected):
    return f"""-- Guarded function-only correction. No financial source or release-pointer writes.
BEGIN;
DO $guard$
DECLARE actual text:=md5(pg_get_functiondef('{SIGNATURE}'::regprocedure));
BEGIN
 IF actual NOT IN ('{expected}','{hashlib.md5(new.encode()).hexdigest()}') THEN
  RAISE EXCEPTION 'Review decision changed concurrently; installation stopped';
 END IF;
 EXECUTE $definition${new}$definition$;
END $guard$;
COMMIT;
"""
def build():
    original=(ROOT/'original.sql').read_text()
    assert hashlib.md5(original.encode()).hexdigest()==BASE_HASH
    day_scope=patch(original)
    assert hashlib.md5(day_scope.encode()).hexdigest()==DAY_SCOPE_HASH
    new=bank_reader_patch(day_scope)
    (ROOT/'install.sql').write_text(installer(day_scope,new,DAY_SCOPE_HASH))
    rollback=installer(new,day_scope,hashlib.md5(new.encode()).hexdigest()).replace('installation stopped','rollback stopped')
    (ROOT/'rollback.sql').write_text(rollback)
    return new
if __name__=='__main__':
    new=build();print({'scope':'posted checking-account review decisions','original_md5':BASE_HASH,'new_md5':hashlib.md5(new.encode()).hexdigest(),'source_writes':False,'ui_pointer_changed':False})
