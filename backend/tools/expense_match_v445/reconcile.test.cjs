const assert=require('node:assert/strict'),{recover}=require('./reconcile.cjs');
const b={owner:'synthetic-owner',id:'b1',status:'POSTED',currency:'BRL',type:'CHECKING_ACCOUNT',date:'2026-11-03',account:'Banco',amount:-123.45};
const e={source:'current_event',source_ref:'e1',bank_confirmed:true,open_finance_id:'b1',event_date:b.date,account:b.account,signed_amount:b.amount,category:'Educação',description:'Synthetic school'};
const input={owner:b.owner,bank:[b],events:[e],expenses:[],from:'2026-11-01',to:'2026-11-30',asOf:'2026-11-15'};
const original=JSON.stringify(input);assert.equal(recover(input)[0].amount,123.45);assert.equal(JSON.stringify(input),original);
let cases=2;
for(const edit of [{status:'PENDING'},{owner:'other'},{deleted:true},{date:'2026-11-16'},{date:'2026-10-31'},{currency:'USD'},{type:'SAVINGS_ACCOUNT'},{amount:-124},{amount:123.45},{amount:null},{internal_transfer:true},{card_settlement:true},{asset_movement:true}]){assert.equal(recover({...input,bank:[{...b,...edit}]}).length,0);cases++;}
for(const edit of [{bank_confirmed:false},{internal_transfer:true},{is_asset_movement:true},{excluded_from_spend:true},{card_settlement:true},{category:'Pagamento de fatura'},{source:'card_invoice'},{open_finance_id:'other'},{event_date:'2026-11-04'},{signed_amount:null}]){assert.equal(recover({...input,events:[{...e,...edit}]}).length,0);cases++;}
for(const existing of [{source_ref:'b1'},{source_ref:'e1'},{bank_id:'b1'}]){assert.equal(recover({...input,expenses:[existing]}).length,0);cases++;}
assert.equal(recover({...input,events:[e,{...e,source_ref:'e2'}]}).length,0);cases++;
assert.equal(recover({...input,bank:[b,b]}).length,0);cases++;
assert.equal(recover({...input,expenses:recover(input)}).length,0);cases++;
console.log(JSON.stringify({passed:cases,synthetic:true,serverIntegrated:false,published:false}));
