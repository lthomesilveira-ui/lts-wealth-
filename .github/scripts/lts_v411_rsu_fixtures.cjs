'use strict';
const fs=require('node:fs');
const source=JSON.parse(fs.readFileSync('backend/patches/v411/reader_contract.json','utf8'));
function policy(){return structuredClone(source);}
function wealth(base,p){
 const j=structuredClone(base),s=p.summary;
 j.as_of='2026-11-04';
 j.rsu_summary={as_of:'2026-10-01',vested_shares_brl:200,brokerage_cash_brl:100,available_total_brl:300,future_regular_brl:s.regular_gross_brl,future_regular_net_brl:s.regular_net_brl,future_cash_net_brl:s.cash_net_brl,future_considered_total_brl:s.schedule_net_brl};
 j.morgan_statement={as_of:'2026-10-01',gross_total_brl:1800,available_total_brl:300,unavailable_gross_brl:1500,available_components:{vested_shares_brl:200,brokerage_cash_brl:100},future_components:{regular_rsu_gross_brl:1000,cash_rsu_gross_brl:500,cash_rsu_after_reserve_brl:350,future_after_reserve_brl:1350},considered_total_after_reserve_brl:1650,quantities:{vested_shares:2,future_regular_rsu:10,future_cash_rsu:5},planning_schedule_reconciliation:{regular_delta_brl:0,cash_delta_brl:0}};
 j.rsu={...(j.rsu||{}),future_schedule:p.future_schedule.map(r=>({...structuredClone(r),unit_price_usd:r.gross_value_brl/r.quantity/5,fx_rate:5,anticipated_date:null}))};
 j.employment_awards={retention:{gross_total_brl:5000,installments:[]},retention_projected_events:[]};
 return j;
}
function quoteRegular(p){
 const n=structuredClone(p),r=n.future_schedule.find(x=>x.asset_type==='RSU');
 for(const k of['gross_value_brl','net_value_brl','reserve_value_brl'])r[k]*=2;
 for(const c of r.components)for(const k of['gross_value_brl','net_value_brl','reserve_value_brl'])c[k]*=2;
 Object.assign(n.summary,{regular_gross_brl:2000,regular_net_brl:1400,schedule_gross_brl:2500,schedule_net_brl:1750,schedule_reserve_brl:750});return n;
}
function netFlow(j){
 if(!j?.flow?.current_future?.days)return j;
 for(const d of j.flow.current_future.days){
  const available=d.date>='2030-04-03'?1350:d.date>='2030-02-21'?650:300;
  Object.assign(d.fix86_columns,{rsus_vested:available,saldo_apos_rsu:1200+available,saldo_apos_fgts:1700+available});
 }
 return j;
}
module.exports={policy,wealth,quoteRegular,netFlow};
