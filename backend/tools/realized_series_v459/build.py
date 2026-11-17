"""Preserve a documented series identity when recognizing its posted payment."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SOURCE='public.lts_realized_bank_sources_v238(uuid)'
PROFILE='lts_product_refresh_private_v415.review_profile_v450()'
OLD_SOURCE='02696060487b81ddf0592be23a2e044f'
OLD_PROFILE='61ffab594e8c04fc1c3dbb217afc2f26'
PROOF='f80d94725ee68e46300b5fbcd4f387fd'
NEEDLE='OR public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(r),r.evidence))'
REPLACEMENT="""OR public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(r),r.evidence)
OR (f.metadata->>'contract_ref'='volvo_financing_2026'
 AND f.metadata->>'bank_staging_id'=s.id::text
 AND f.metadata#>>'{bank_reconciliation_evidence,bank_raw_hash}'=s.raw_hash
 AND r.evidence->>'bank_raw_hash'=s.raw_hash
 AND r.evidence->>'contract_ref'=substring(s.description_raw FROM '(?i)CONTR[[:space:]]+([0-9]+)')
 AND r.evidence->>'installment'=substring(s.description_raw FROM '(?i)PARC[[:space:]]+([0-9]+/[0-9]+)')
 AND EXISTS(SELECT 1 FROM public.lts_documentary_contract_payments_v310(p_user_id,current_date) p
  WHERE p.financial_event_id=f.id AND p.staging_id=s.id
  AND p.paid_date=s.posting_date AND p.paid_amount=-s.signed_amount)))"""


def definition(name):
    return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'


def md5(text):
    return hashlib.md5(text.encode()).hexdigest()


def build():
    before=definition('source-original.sql');profile=definition('profile-original.sql')
    assert md5(before)==OLD_SOURCE and md5(profile)==OLD_PROFILE
    assert before.count(NEEDLE)==1 and profile.count(OLD_SOURCE)==1
    after=before.replace(NEEDLE,REPLACEMENT)
    after_profile=profile.replace(OLD_SOURCE,md5(after))
    assert md5(definition('proof.sql'))==PROOF
    (ROOT/'source-after.sql').write_text(after.rstrip()+';\n')
    (ROOT/'profile-after.sql').write_text(after_profile.rstrip()+';\n')
    targets=[(SOURCE,before,after),(PROFILE,profile,after_profile)]
    for name,reverse in [('install.sql',False),('rollback.sql',True)]:
        parts=["BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='10s';\nDO $patch$\nDECLARE target regprocedure; d text; attrs jsonb; u uuid;\nBEGIN\n",
         " IF md5(pg_get_functiondef('public.lts_documentary_contract_payments_v310(uuid,date)'::regprocedure))<>'"+PROOF+"' THEN RAISE EXCEPTION 'V459_PROOF_READER_CHANGED';END IF;\n",
         " IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V459_WORKER_ACTIVE';END IF;\n",
         " FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V459_WORKER_LOCK_BUSY';END IF;END LOOP;\n"]
        if reverse:
            parts.append(" IF EXISTS(SELECT 1 FROM public.financial_events f JOIN public.lts_realized_bank_event_v238 r ON r.user_id=f.user_id AND r.financial_event_id=f.id WHERE f.metadata->>'contract_ref'='volvo_financing_2026' AND NOT f.is_projection AND NOT f.is_suppressed) THEN RAISE EXCEPTION 'V459_STABLE_SERIES_REALIZATION_REQUIRES_DATA_REVIEW';END IF;\n")
        for signature,old,new in targets:
            if reverse:old,new=new,old
            parts.append(f""" target:='{signature}'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{md5(old)}' THEN EXECUTE $definition${new.rstrip()}$definition$;
 ELSIF md5(d)<>'{md5(new)}' THEN RAISE EXCEPTION 'V459_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'{md5(new)}' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V459_FUNCTION_CONTRACT_CHANGED';END IF;
""")
        parts.append('END $patch$;\nCOMMIT;\n');(ROOT/name).write_text(''.join(parts))
    (ROOT/'manifest.json').write_text(json.dumps({'source':SOURCE,'source_before_md5':OLD_SOURCE,
     'source_after_md5':md5(after),'profile_before_md5':OLD_PROFILE,'profile_after_md5':md5(after_profile),
     'proof_dependency_md5':PROOF,'profile_pin_changes':1,'financial_source_writes':False,
     'existing_contract_proof_required':True,'timeouts_and_permissions_preserved':True},indent=2)+'\n')


if __name__=='__main__':build()
