'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-flow-period-state.js','utf8');
function harness(){
 const attrs={},table={hidden:false,style:{},setAttribute(k,v){attrs[k]=v}},select={options:[{value:'2026'}],value:'2026',appendChild(o){this.options.push(o)},setAttribute(){}};
 const ctx={window:{},V:'Fluxo Diário',FLOWFROM:'2014-02-03',FLOWTO:'2014-02-03',FLOWYEAR:2026,FLOWLOADING:true,FLOWQ:{from:'2026-09-01',to:'2026-12-31',rows:['preserved']},render(){return 'rendered'},document:{getElementById:()=>select,querySelector:()=>table,createElement:()=>({})}};
 vm.runInNewContext('('+source.slice(source.indexOf('function runtime(){'),source.indexOf('\n const shell='))+')()',ctx);
 return{ctx,table,select,attrs};
}
test('exact-day navigation synchronizes the year without dropping the requested dates',()=>{
 const h=harness();assert.equal(h.ctx.render(),'rendered');assert.equal(h.ctx.FLOWYEAR,2014);assert.equal(h.select.value,'2014');assert.equal(h.ctx.FLOWFROM,'2014-02-03');assert.equal(h.select.options.length,2);
 h.ctx.render();assert.equal(h.select.options.length,2);
});
test('old rows are hidden during loading but the financial response is preserved',()=>{
 const h=harness(),before=h.ctx.FLOWQ;h.ctx.render();assert.equal(h.table.hidden,true);assert.equal(h.table.style.display,'none');assert.equal(h.attrs['aria-busy'],'true');assert.equal(h.ctx.FLOWQ,before);assert.deepEqual(before.rows,['preserved']);
});
test('only the response belonging to the selected interval becomes visible',()=>{
 const h=harness();h.ctx.FLOWLOADING=false;h.ctx.render();assert.equal(h.table.hidden,true);
 h.ctx.FLOWQ={from:h.ctx.FLOWFROM,to:h.ctx.FLOWTO};h.ctx.render();assert.equal(h.table.hidden,false);assert.equal(h.table.style.display,'');assert.equal(h.attrs['aria-busy'],'false');
});
test('failure cannot expose old rows and a successful retry restores the table',()=>{
 const h=harness();h.ctx.FLOWLOADING=false;h.ctx.FLOWQ={error:'fixture'};h.ctx.render();assert.equal(h.table.hidden,true);
 h.ctx.FLOWLOADING=true;h.ctx.render();assert.equal(h.table.hidden,true);
 h.ctx.FLOWLOADING=false;h.ctx.FLOWQ={from:h.ctx.FLOWFROM,to:h.ctx.FLOWTO};h.ctx.render();assert.equal(h.table.hidden,false);
});
test('multi-year interval is labeled custom and returning to one year resets it',()=>{
 const h=harness();h.ctx.FLOWFROM='2024-12-15';h.ctx.FLOWTO='2025-01-15';h.ctx.render();assert.equal(h.select.value,'');assert.equal(h.select.options.at(-1).textContent,'Período personalizado');assert.equal(h.select.options.at(-1).disabled,true);
 h.ctx.FLOWFROM='2026-09-01';h.ctx.FLOWTO='2026-12-31';h.ctx.render();assert.equal(h.select.value,'2026');assert.equal(h.ctx.FLOWYEAR,2026);
});
test('other routes do not change controls or financial data',()=>{
 const h=harness();h.ctx.V='Dashboard';h.ctx.FLOWFROM='2015-01-01';h.ctx.FLOWTO='2015-12-31';h.ctx.render();assert.equal(h.ctx.FLOWYEAR,2014);assert.equal(h.select.value,'2014');
 assert.doesNotMatch(source,/S\.rpc|fetch\(|\.insert\(|\.update\(|\.delete\(/);assert.doesNotThrow(()=>new Function(source));
 assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-flow-period-state/);
});
