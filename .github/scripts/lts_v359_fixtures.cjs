'use strict';
const fixture=require('./lts_v309_fixtures.cjs');
function row(key,amount,macrogroup,group,category,date='2026-10-05',extra={}){return{key,amount,date,event_date:date,date_kind:'day',period:date.slice(0,7)+'-01',description:'Registro fictício '+key,property_code:'cipo396',taxonomy:{macrogroup,group,category},current_category:category,original_category:category,category:'Apartamento · CIPÓ 396',source_table:'synthetic',source_ref:key,account_source:'Conta fictícia',...extra};}
const acq=(key,amount,category,date)=>row(key,amount,'Patrimônio e financiamentos','Aquisição imobiliária',category,date);
function rows(){return[
 acq('prefix',20,'Financiamento Imobiliário','2020-06-20'),acq('tail',10,'Financiamento Imobiliário','2026-10-20'),acq('card',5,'Consórcio','2020-01-20'),acq('adjustment',-2,'Aquisição','2020-02-20'),
 ...Array.from({length:350},(_,i)=>row('work-'+i,i?0.1:3.1043333333333,'Moradia','Obra, reforma e equipamentos','Serviços',undefined,i===0?{composition:{status:'complete',count:2,nonzero_count:2},source_audit:{file:'Synthetic.xlsm',sheet:'Cartão fictício',rows:[1,2]}}:{})),
 row('housing',7,'Moradia','Uso e manutenção','Energia'),row('tax',3,'Moradia','Tributos','IPTU')];}
function wealth(native){const w=fixture.contracts(structuredClone(fixture.response('lts_browser_wealth_detail_v242')));w.wealth.cipo_reconciliation=structuredClone(native);return w;}
function matches(r,s,from,to){return r.date>=from&&r.date<=to&&(!s.property||r.property_code===s.property)&&(!s.macrogroup||r.taxonomy.macrogroup===s.macrogroup)&&(!s.group||r.taxonomy.group===s.group)&&(!s.category||r.taxonomy.category===s.category);}
const total=rows=>rows.reduce((a,r)=>a+r.amount,0);
module.exports={rows,wealth,matches,total};
