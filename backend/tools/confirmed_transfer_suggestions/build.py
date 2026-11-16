"""Restore confirmed-repeat suggestions without assigning a purpose from a name."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SIGNATURE='public.lts_review_suggestions_v231(uuid,jsonb)'
BASE_HASH='53070bc75bfd490be7d501c3171e2b26'
REPEAT_CTES="""), confirmed_transfer_history AS MATERIALIZED (
 SELECT t.source_table,t.source_ref,h.id prior_id,h.posting_date prior_date,
 h.description_raw prior_description,abs(h.signed_amount) prior_amount,d.category_label category
 FROM targets t JOIN public.lts_open_finance_staging s
 ON t.source_table='lts_open_finance_staging' AND s.user_id=p_user_id AND s.id::text=t.source_ref
 JOIN public.lts_open_finance_staging h
 ON h.user_id=s.user_id AND h.id<>s.id AND h.provider=s.provider
 AND h.institution_code=s.institution_code AND h.provider_account_ref=s.provider_account_ref
 AND h.currency=s.currency AND h.signed_amount=s.signed_amount
 AND h.posting_date BETWEEN s.posting_date-365 AND s.posting_date-1
 AND h.resource_type='transaction' AND h.provider_deleted_at IS NULL
 AND h.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND h.normalized_payload->>'status'='POSTED'
 AND h.normalized_payload->>'operation_type'=s.normalized_payload->>'operation_type'
 AND h.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(h.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
     =regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
 JOIN public.lts_v178_review_decision d ON d.user_id=h.user_id
 AND d.source_table='lts_open_finance_staging' AND d.source_ref=h.id::text
 AND d.decision_basis IN('authenticated_user_v181','authenticated_user_v229','authenticated_detail_v232')
 WHERE t.person_transfer AND t.question_kind='classification'
 AND t.description=s.description_raw AND t.amount=abs(s.signed_amount) AND t.event_date=s.posting_date
 AND s.resource_type='transaction' AND s.provider_deleted_at IS NULL AND s.signed_amount<0
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.normalized_payload->>'status'='POSTED'
 AND nullif(s.provider,'') IS NOT NULL AND nullif(s.institution_code,'') IS NOT NULL
 AND nullif(s.provider_account_ref,'') IS NOT NULL AND nullif(s.currency,'') IS NOT NULL
 AND length(regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g'))=11
 AND nullif(trim(d.category_label),'') IS NOT NULL
 AND public.lts_v178_norm(d.category_label) NOT IN('a classificar','sem categoria','nao identificado')
), confirmed_transfers AS MATERIALIZED (
 SELECT source_table,source_ref,min(category) category,count(DISTINCT prior_id) evidence_count,
 (jsonb_agg(jsonb_build_object('source_table','lts_open_finance_staging','source_ref',prior_id,
 'date',prior_date,'description',prior_description,'amount',prior_amount,'category',category)
 ORDER BY prior_date DESC,prior_id))->0 evidence
 FROM confirmed_transfer_history h GROUP BY source_table,source_ref
 HAVING count(DISTINCT category)=1 AND bool_and(EXISTS(
 SELECT 1 FROM public.lts_category_catalog c WHERE c.user_id=p_user_id AND c.active AND c.category=h.category))
), raw_history AS MATERIALIZED ("""
REPEAT_CASE=""" CASE WHEN t.person_transfer AND t.question_kind='classification' AND ct.category IS NOT NULL THEN
 jsonb_build_object('category',ct.category,'basis','confirmed_recipient_amount_history',
 'evidence_count',ct.evidence_count,'evidence',ct.evidence,'requires_confirmation',true,
 'note','Mesmo destinatário, valor e conta de uma transferência já confirmada por você. Confira a finalidade antes de salvar.')
 WHEN t.person_transfer AND t.question_kind='classification' THEN"""
def patch(s):
    changes=[('), raw_history AS MATERIALIZED (',REPEAT_CTES),
      (" CASE WHEN t.person_transfer AND t.question_kind='classification' THEN",REPEAT_CASE),
      ('FROM targets t LEFT JOIN best b USING(source_table,source_ref)',
       'FROM targets t LEFT JOIN best b USING(source_table,source_ref)\nLEFT JOIN confirmed_transfers ct USING(source_table,source_ref)')]
    for a,b in changes:
        assert s.count(a)==1,a
        s=s.replace(a,b)
    return s
def installer(new,expected):
    return f"""-- Read-only suggestion correction; no financial facts, decisions or release-pointer writes.
BEGIN;
DO $guard$
DECLARE actual text:=md5(pg_get_functiondef('{SIGNATURE}'::regprocedure));
BEGIN
 IF actual NOT IN ('{expected}','{hashlib.md5(new.encode()).hexdigest()}') THEN
  RAISE EXCEPTION 'Suggestion function changed concurrently; installation stopped';
 END IF;
 EXECUTE $definition${new}$definition$;
END $guard$;
COMMIT;
"""
def build():
    original=(ROOT/'original.sql').read_text()
    assert hashlib.md5(original.encode()).hexdigest()==BASE_HASH
    new=patch(original)
    (ROOT/'install.sql').write_text(installer(new,BASE_HASH))
    (ROOT/'rollback.sql').write_text(installer(original,hashlib.md5(new.encode()).hexdigest()))
    return new
if __name__=='__main__':
    new=build();print({'original_md5':BASE_HASH,'new_md5':hashlib.md5(new.encode()).hexdigest(),'financial_writes':False,'ui_promotion':False})
