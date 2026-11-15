'use strict';
// Pure candidate contract; server integration still required. No I/O or writes.
function recover({owner,bank,events,expenses,from,to,asOf}){
 const cents=x=>typeof x==='number'&&Number.isFinite(x)?Math.round(x*100):null;
 const blocked=e=>e.internal_transfer||e.is_asset_movement||e.asset_movement||e.excluded_from_spend||e.non_cash_marker||e.card_settlement||e.source==='card_invoice'||e.category==='Pagamento de fatura';
 const pairs=[];
 for(const e of events){if(e.source!=='current_event'||e.bank_confirmed!==true||blocked(e)||!e.open_finance_id||!e.source_ref)continue;
 for(const b of bank){if(b.owner!==owner||b.id!==e.open_finance_id||b.deleted||b.status!=='POSTED'||b.currency!=='BRL'||b.type!=='CHECKING_ACCOUNT'||b.internal_transfer||b.card_settlement||b.asset_movement)continue;
 if(b.date<from||b.date>to||b.date>asOf||b.date!==e.event_date||b.account!==e.account||cents(b.amount)===null||cents(b.amount)>=0||cents(b.amount)!==cents(e.signed_amount))continue;
 pairs.push({e,b});}}
 return pairs.filter(({e,b})=>pairs.filter(p=>p.b.id===b.id).length===1&&pairs.filter(p=>p.e.source_ref===e.source_ref).length===1&&!expenses.some(x=>x.source_ref===b.id||x.source_ref===e.source_ref||x.bank_id===b.id)).map(({e,b})=>({source_table:'lts_open_finance_staging',source_ref:b.id,event_date:b.date,amount:-b.amount,category:e.category,beneficiary:e.center_cost||null,description:e.description,account:e.account,matched_event_ref:e.source_ref}));
}
module.exports={recover};
