'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('releases/v385/lts-v183-v168-feedback-safe.js','utf8'),start=source.indexOf('    function dailyScenario('),end=source.indexOf('    function cockpitPoints',start),now='2026-10-31',horizon='2030-12-31';
const context={arr:x=>Array.isArray(x)?x:[],num:x=>x==null||x===''?null:Number.isFinite(Number(x))?Number(x):null,today:()=>now,esc:s=>String(s??''),date:s=>s?String(s).split('-').reverse().join('/'):'—',money:x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),Date,Set,Math};
vm.createContext(context);vm.runInContext(source.slice(start,end)+';this.api={dailyScenario,deficitDetail}',context);
const {dailyScenario,deficitDetail}=context.api,keys={base:'saldo_apos_d0_1',vested:'saldo_apos_rsu',fgts:'saldo_apos_fgts'};
const iso=i=>new Date(Date.parse(now+'T12:00:00Z')+i*86400000).toISOString().slice(0,10),size=Math.round((Date.parse(horizon)-Date.parse(now))/86400000)+1;
function make(fn){return{flow:{current_future:{days:Array.from({length:size},(_,i)=>({date:iso(i),fix86_columns:Object.fromEntries(Object.entries(keys).map(([key,column])=>[column,fn(i,key)]))}))}}};}
const flow=make((i,key)=>{const k=['base','vested','fgts'].indexOf(key);return i===2+k?-(k+1)*1.25:i===5+k||i===20+k?-(k+1)*1000.75:100;});
let cases=0;
for(const[key,column]of Object.entries(keys)){
 const k=['base','vested','fgts'].indexOf(key),s=dailyScenario(flow,key);
 assert.equal(s.complete,true);assert.equal(s.firstNegative.date,iso(2+k));assert.equal(s.firstAmount,-(k+1)*1.25);assert.equal(s.worstDate,iso(5+k),'earliest date of tied minimum');assert.equal(s.worstAmount,-(k+1)*1000.75);
 const html=deficitDetail(s,true);assert(html.includes('Primeiro saldo negativo'));assert(html.includes('Pior saldo projetado'));assert(html.includes('datetime="'+iso(5+k)+'"'));assert(!/<details/.test(html),'visible without a disclosure');cases++;
 const missing=structuredClone(flow);delete missing.flow.current_future.days[1].fix86_columns[column];const partial=dailyScenario(missing,key);assert.equal(partial.complete,false);const notice=deficitDetail(partial,true);assert(notice.includes('Projeção incompleta'));assert(!notice.includes('R$'));cases++;
}
const positive=dailyScenario(make(i=>i===0?0:10),'fgts');assert.equal(positive.firstNegative,null);assert.equal(positive.worstAmount,0);assert.equal(positive.worstDate,now);assert(deficitDetail(positive,true).includes('Sem saldo negativo no período'));assert(deficitDetail(positive,true).includes('Pior saldo projetado'));cases++;
const earliest=dailyScenario(make(i=>i===0?-20:10),'base');assert.equal(earliest.firstNegative.date,now);assert.equal(earliest.firstAmount,-20);cases++;
const gap=make(()=>10);gap.flow.current_future.days.splice(2,1);assert.equal(dailyScenario(gap,'base').complete,false);assert.equal(deficitDetail(dailyScenario(flow,'base'),false),'');cases++;
const bounded=structuredClone(flow);bounded.flow.current_future.days.reverse();bounded.flow.current_future.days.push({date:'2026-10-30',fix86_columns:{saldo_apos_d0_1:-999999999}},{date:'2031-01-01',fix86_columns:{saldo_apos_d0_1:-999999999}});assert.equal(dailyScenario(bounded,'base').worstAmount,-1000.75);cases++;
const declared=structuredClone(flow);declared.coverage={from:now,to:'2027-12-31',complete:true};declared.flow.current_future.days=declared.flow.current_future.days.filter(d=>d.date<=declared.coverage.to);assert.equal(dailyScenario(declared,'base').complete,true,'a complete received period must not require dates beyond its declared end');assert.equal(dailyScenario(declared,'base').lastDate,'2027-12-31');assert.equal(dailyScenario(declared,'base').worstAmount,-1000.75);cases++;
declared.flow.current_future.days.pop();assert.equal(dailyScenario(declared,'base').complete,false,'missing final requested day remains incomplete');declared.complete=false;assert.equal(dailyScenario(declared,'base').complete,false);cases++;
console.log(JSON.stringify({pass:true,cases,actual_runtime_functions:true,three_independent_scenarios:true,first_day_zero_and_no_deficit:true,earliest_tied_minimum:true,missing_values_and_dates_not_zero:true,dates_and_coverage_preserved:true}));
