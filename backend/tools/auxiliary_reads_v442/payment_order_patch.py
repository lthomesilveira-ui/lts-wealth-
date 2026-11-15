"""Preserve exact reviewed settlement evidence across payment-array reordering."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[3];P=ROOT/'backend/patches/v442'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def build():
 sql=(P/'payment_order.sql').read_text();guards=[];changed=[]
 for name,signature in [('payment_validator','public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'),('payment_refresh','public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)')]:
  old=(P/(name+'_before.sql')).read_text()
  marker="ELSE ((p_invoice->'raw_payload') - 'updatedAt')=p_contract->'invoice_canonical_payload' END"
  replacement="WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) "+marker
  payments="ELSE p_invoice#>'{raw_payload,payments}'=p_contract->'issuer_payments' END"
  replacement_payments="WHEN p_contract->>'issuer_settlement_policy'='one_full_payment_in_cycle_v301' THEN public.lts_invoice_payment_order_equal_v442(p_invoice,p_contract) "+payments
  assert old.count(marker)==1 and old.count(payments)==1
  new=old.replace(marker,replacement).replace(payments,replacement_payments)
  assert new.replace(replacement,marker).replace(replacement_payments,payments)==old
  (P/(name+'_candidate.sql')).write_text(new)
  changed.append("md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+md5(new)+"'")
  guards.append("DO $patch$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure;IF md5(s)='"+md5(new)+"' THEN RETURN;END IF;IF md5(s)<>'"+md5(old)+"' THEN RAISE EXCEPTION 'V442 payment evidence predecessor changed';END IF;EXECUTE $candidate$"+new+"$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure) OR md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+md5(new)+"' THEN RAISE EXCEPTION 'V442 payment evidence attributes changed';END IF;END $patch$;")
  (P/(name+'_rollback.sql')).write_text("DO $rollback$ BEGIN IF md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+md5(new)+"' THEN RAISE EXCEPTION 'V442 evidence reader changed';END IF;EXECUTE $previous$"+old+"$previous$;END $rollback$;\n")
  print(name,md5(old),md5(new))
 # Source facts stay immutable. A derived-cache epoch change is required once.
 body=sql.split('AS $function$',1)[1].split('$function$;',1)[0]
 helper="to_regprocedure('public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)')"
 (P/'payment_order_install.sql').write_text("DO $migration$ DECLARE applied boolean:=false;BEGIN IF "+helper+" IS NULL THEN applied:=true;ELSIF (SELECT prosrc FROM pg_proc WHERE oid="+helper+")IS DISTINCT FROM $body$"+body+"$body$ OR (SELECT provolatile<>'i' OR prosecdef OR prorettype<>'boolean'::regtype FROM pg_proc WHERE oid="+helper+")THEN RAISE EXCEPTION 'V442 existing payment helper changed';END IF;applied:=applied OR "+' OR '.join(changed)+";EXECUTE $helper$"+sql+"$helper$;"+'\n'.join(guards)+"IF applied THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;END IF;END $migration$;\n")
if __name__=='__main__':build()
