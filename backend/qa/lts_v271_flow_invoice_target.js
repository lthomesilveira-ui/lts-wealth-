const assert=require('node:assert/strict');require(require('node:path').resolve('releases/v271/lts-flow-invoice-target.js'));const resolve=globalThis.LTSFlowInvoiceTarget.resolve;
const event={source:'card_invoice',source_ref:'C6 Carbon|2026-10',account:'C6',event_date:'2026-11-05',signed_amount:-100};
const data={cards:[{family:'c6',bank:'C6',cycles:[{month:'2026-10-01',due_date:'2026-11-05',amount:100},{month:'2026-11-01',due_date:'2026-12-05',amount:200}]}]};
assert.deepEqual(resolve(event,data),{ok:true,family:'c6',month:'2026-10-01'});
for(const e of [{...event,source_ref:''},{...event,source_ref:'C6 Carbon|2026-13'},{...event,account:'Itaú'},{...event,family:'itau_mastercard'},{...event,reference_month:'2026-11-01'}])assert.equal(resolve(e,data).ok,false);
assert.equal(resolve(event,{cards:[...data.cards,...data.cards]}).reason,'ambiguous_card');
assert.equal(resolve(event,{cards:[{...data.cards[0],cycles:[...data.cards[0].cycles,data.cards[0].cycles[0]]}]}).reason,'ambiguous_cycle');
assert.equal(resolve(event,{cards:[{...data.cards[0],cycles:[]}]}).reason,'missing_cycle');
assert.equal(resolve({...event,signed_amount:-101},data).ok,true); // Do not certify cash/composition equality here.
assert.equal(resolve(event,{cards:[{...data.cards[0],bank:'Bradesco'}]}).ok,false);
console.log('invoice target contract PASS');

assert.equal(resolve({...event,card_name:'Outro cartão'},data).ok,false);
assert.equal(resolve({...event,competence_month:'2026-11'},data).ok,false);
assert.equal(resolve(event,{cards:[{...data.cards[0],cycles:[{month:'2026-10-01',reference_month:'2026-11-01'}]}]}).ok,false);
for(const [name,bank,family] of [['Visa Aeternum','Bradesco','aeternum'],['Visa Infinite','Bradesco','bradesco_prime'],['Visa Infinite','Itaú','itau_visa'],['Mastercard Black','Itaú','itau_mastercard']]){
 const e={...event,account:bank,source_ref:name+'|2026-10'},d={cards:[{family,bank,cycles:data.cards[0].cycles}]};assert.deepEqual(resolve(e,d),{ok:true,family,month:'2026-10-01'});
}
