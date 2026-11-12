'use strict';
module.exports=(year=2026,asOf='2026-11-05')=>{
 const rows=[['Habitação',500],['Mercado',1000]].map(([category,target])=>({category,reference_monthly:target,months:Array.from({length:12},(_,i)=>({month:year+'-'+String(i+1).padStart(2,'0'),target,actual:i===10&&category==='Mercado'?50:0,pending:0,target_basis:'history'}))}));
 const months=Array.from({length:12},(_,i)=>({month:year+'-'+String(i+1).padStart(2,'0'),target:1500,actual:i===10?50:0,pending:0,income_target:3000,income_regular:i<10?3000:0,income_extraordinary:0,income_bonus:0,started:year<2026||year===2026&&i<=10,complete:year<2026||year===2026&&i<10}));
 return{ok:true,version:'budget-v441',year,as_of:asOf,plan_revision:0,proposed:true,reference:{from:'2026-05-01',to:'2026-10-31',months:6,expected_months:6,salary_months:3,salary_monthly:3000},rows,months,unclassified_actual:0,actual_income_groups:[],basis:'canonical_consumption_not_card_payment',flow_provision_included:false};
};
