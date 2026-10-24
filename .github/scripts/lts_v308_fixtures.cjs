'use strict';
const base=require('./lts_v296_fixtures.cjs');
function recurring(){
 const data=base.recurring();
 data.horizon_checks.forEach((row,index)=>{
  row.period_coverage.forEach(period=>{
   if(index%3===1&&period.status==='awaiting_payment_evidence'){period.status='covered';period.future_events=1;}
   if(index%3===2&&period.status==='review'){period.status='covered';period.future_events=1;}
  });
  row.period_coverage.push(...Array.from({length:12},(_,m)=>({period_start:'2027-'+String(m+1).padStart(2,'0')+'-01',period_end:'2027-'+String(m+1).padStart(2,'0')+'-28',status:'review',actual_events:0,future_events:0})));
 });
 return data;
}
module.exports={...base,recurring};
