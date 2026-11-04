/* Resolves the documented card_invoice source_ref contract, never due-date month. */
(function(root){
 'use strict';
 const norm=x=>String(x??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/\s+/g,' ').trim();
 // Same precedence as lts_card_family_v226; bank is additionally checked below.
 function family(name,bank){const n=norm(name),b=norm(bank);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('bandeirado'))return'c6';if(n.includes('visa')&&b.includes('itau'))return'itau_visa';if(n.includes('visa')&&b.includes('bradesco'))return'bradesco_prime';if(n.includes('mastercard')||n.includes('mc black')||n.includes('personnalite'))return'itau_mastercard';return null;}
 const banks={aeternum:'bradesco',bradesco_prime:'bradesco',itau_mastercard:'itau',itau_visa:'itau',c6:'c6'};
 function resolve(event,data){
  const fail=reason=>({ok:false,reason});
  if(event?.source!=='card_invoice')return fail('unsupported_source');
  const m=String(event.source_ref||'').match(/^([^|]+)\|(\d{4}-(?:0[1-9]|1[0-2]))$/);
  if(!m)return fail('missing_identity');
  const f=family(m[1],event.account),month=m[2]+'-01';
  if(!f||norm(event.account)!==banks[f])return fail('conflicting_bank');
  if(event.family&&event.family!==f||event.card_family&&event.card_family!==f)return fail('conflicting_family');
  if(event.card_name&&norm(event.card_name)!==norm(m[1]))return fail('conflicting_card_name');
  for(const key of ['reference_month','competence_month'])if(event[key]&&event[key]!==month&&event[key]!==m[2])return fail('conflicting_month');
  const cards=(data?.cards||[]).filter(c=>c.family===f);
  if(cards.length!==1)return fail(cards.length?'ambiguous_card':'missing_card');
  if(norm(cards[0].bank)!==banks[f])return fail('conflicting_card_bank');
  const cycles=(cards[0].cycles||[]).filter(c=>(c.month||c.reference_month)===month);
  if(cycles.length!==1)return fail(cycles.length?'ambiguous_cycle':'missing_cycle');
  if(cycles[0].month&&cycles[0].reference_month&&cycles[0].month!==cycles[0].reference_month)return fail('conflicting_cycle_month');
  return {ok:true,family:f,month};
 }
 root.LTSFlowInvoiceTarget={resolve};
})(typeof window==='undefined'?globalThis:window);
