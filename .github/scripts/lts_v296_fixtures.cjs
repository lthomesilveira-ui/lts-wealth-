'use strict';
// Synthetic shapes, deliberately populated. Never export private account data.
const base=require('./lts_boot_recovery_fixtures.cjs');
const title='Compromisso fictício com descrição extensa para conferir a quebra de linhas e a separação entre os textos, os valores e os botões de revisão';
function recurring(){return{horizon_checks:Array.from({length:17},(_,i)=>({key:'synthetic-series-'+i,title:title+' '+(i+1),description:title,direction:i%3?'expense':'income',cadence:'monthly',review_kind:'planning_review',observed_median_amount_brl:100+i,period_coverage:Array.from({length:12},(_,m)=>({period_start:'2026-'+String(m+1).padStart(2,'0')+'-01',period_end:'2026-'+String(m+1).padStart(2,'0')+'-28',status:m===9?'awaiting_payment_evidence':m>9?'review':'covered',actual_events:m<9?1:0,future_events:0}))})),items:[]};}
function product(){const p=JSON.parse(JSON.stringify(base.product()));p.dashboard_cockpit.work={actionable_count:4,top_actions:Array.from({length:4},(_,i)=>({key:'synthetic-action-'+i,title:title,detail:'Conferir o período e os lançamentos correspondentes.',impact_amount:100+i}))};return p;}
module.exports={...base,product,recurring};
