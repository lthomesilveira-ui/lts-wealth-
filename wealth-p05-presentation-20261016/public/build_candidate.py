from pathlib import Path
import difflib,hashlib,json
root=Path(__file__).parent
reference=(root/'economic-guard-reference.sql').read_text()
assert hashlib.sha256(reference.encode()).hexdigest()=='6b44f46bf53a2671cfe2144162a0582052d4311b4ab21b922fc02f1c8e91c52c'
a=reference.index('(CASE WHEN p_contract');b=reference.index(' END)',a)+5;predicate=reference[a:b]
assert hashlib.sha256(predicate.encode()).hexdigest()=='ae48a8c0dd8b1771090beaad96f4b46fd68c651ebe117682e99ec757b0b1f00b'
template=(root/'payment-refresh-annotation.template.sql').read_text();assert template.count('__SHARED_INVOICE_PREDICATE__')==1
helper=template.replace('__SHARED_INVOICE_PREDICATE__',predicate);(root/'payment-refresh-annotation.sql').write_text(helper)
reader=(root/'documentary-payment-presentation.sql').read_text()
(root/'candidate-rollback-default.sql').write_text('-- Candidate only: not authorized for production.\nBEGIN;\nSET LOCAL statement_timeout=\'15s\';\nSET LOCAL lock_timeout=\'2s\';\n'+helper+'\n'+reader+'\nROLLBACK;\n')
s=(root/'v280-card-composition.original.js').read_text();raw=s.encode();assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()=='25472d021a29726fe15427928ce8a91098562614'
note=(root/'documentary-payment-note.cjs').read_text().split("'use strict';\n",1)[1].split('module.exports',1)[0];a=s.index('function documentaryPaymentNote(');b=s.index('    const v233Formatters',a);out=s[:a]+note+s[b:]
old="(cycle.payment_status==='payment_not_reported'?' · pagamento não informado':cycle.payment_status==='payment_reported'?' · pagamento informado':cycle.payment_status==='paid'?' · pagamento confirmado':'')"
old='source(cycle.basis)+'+old
new="documentaryPaymentNote(cycle,null,null,'label',source(cycle.basis))"
assert out.count(old)==1;out=out.replace(old,new)
# Reverting only the helper and summary expression must reconstruct the exact V280 bytes.
x=out.index('function documentaryPaymentNote(');y=out.index('    const v233Formatters',x)
reconstructed=(out[:x]+s[a:b]+out[y:]).replace(new,old)
assert reconstructed.encode()==raw
(root/'lts-v226-card-composition.js').write_text(out)
(root/'browser-note.patch').write_text(''.join(difflib.unified_diff(s.splitlines(True),out.splitlines(True),fromfile='releases/v280/lts-v226-card-composition.js',tofile='isolated-candidate/lts-v226-card-composition.js')))
original=(root/'original-presentation-helper.sql').read_text();a=original.index('CREATE FUNCTION public.lts_card_documentary_payment_presentation_v272');b=original.index('-- The authenticated',a)
(root/'presentation-helper.patch').write_text(''.join(difflib.unified_diff(original[a:b].splitlines(True),reader.splitlines(True),fromfile='existing/documentary_payment_presentation.sql',tofile='candidate/documentary-payment-presentation.sql')))
(root/'rebase-receipt.json').write_text(json.dumps({'base_ref':'a0181d50c81154f43f753a4f46cfaa18dc346da0','base_release':'v280','source_blob_sha':'25472d021a29726fe15427928ce8a91098562614','source_sha256':hashlib.sha256(raw).hexdigest(),'candidate_sha256':hashlib.sha256(out.encode()).hexdigest(),'changes':['documentaryPaymentNote','summary source+payment label expression'],'byte_reconstruction_verified':True,'release_asset_modified':False},indent=2)+'\n')
print('Generated restricted candidate from exact V280 asset and installed invoice predicate.')
