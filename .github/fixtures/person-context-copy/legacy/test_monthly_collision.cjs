'use strict';
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=process.cwd();
const dirs={base:path.join(root,'releases/v282'),candidate:path.join(process.cwd(),'releases/v283')};
function extract(dir,file,start,end){const s=fs.readFileSync(dir+'/'+file,'utf8'),a=s.indexOf(start),b=s.indexOf(end,a);assert(a>=0&&b>a);return s.slice(a,b)}
function test(dir,simulatePreFix=false){
 const groups=[{label:'Assinatura',total:100,monthly:[{month:'2026-01-01',amount:100},{month:'2026-02-01',amount:0}]},{label:'Assinaturas',total:200,monthly:[{month:'2026-01-01',amount:0},{month:'2026-02-01',amount:200}]}],calls=[];
 const c={V:'Despesas',v168:{expense:{tab:'monthly'}},v175:{monthly:{year:2026,data:{months:['2026-01-01','2026-02-01'],expense_groups:groups}}},arr:x=>Array.isArray(x)?x:[],finite:x=>x==null?null:Number(x),sum:x=>x.reduce((a,b)=>a+Number(b),0),expenseRange:()=>({from:'2026-01-01',to:'2026-02-28'}),detailApi:{openDetail:(...a)=>calls.push(a)},safe:x=>String(x??''),monthText:x=>x,n:x=>Number(x)||0,money:x=>String(x)};c.window=c;vm.createContext(c);
 vm.runInContext(fs.readFileSync(dir+'/lts-category-display.js','utf8'),c);
 vm.runInContext(extract(dir,'lts-v183-v182-feedback-safe.js','    function detailButton(','    function detailRange(')+extract(dir,'lts-v183-v182-feedback-safe.js','    function matrix(','    function finalBalance('),c);
 const html=c.matrix('Despesas por categoria',groups,['2026-01','2026-02'],null,true);
 const rowHtml=[...html.split('<tbody>')[1].matchAll(/<tr(?: [^>]*)?><th>(.*?)<\/tr>/g)].map(x=>x[0])[0];
 const title=rowHtml.match(/<th>(.*?)<\/th>/)[1].replace(/<[^>]+>/g,'');
 const cells=[...rowHtml.matchAll(/<td>(.*?)<\/td>/g)].map(x=>({textContent:x[1].replace(/<[^>]+>/g,''),button:x[1].includes('<button')?{}:null,querySelector(){return this.button},replaceChildren(button){this.button=button}}));
 const row={dataset:{ltsCategoryKey:rowHtml.match(/data-lts-category-key="([^"]*)"/)?.[1]},querySelector:()=>({textContent:title}),querySelectorAll:()=>cells};
 const section={querySelector:()=>({textContent:'Despesas por categoria'}),querySelectorAll:()=>[row]};
 c.document={querySelectorAll:()=>[section],createElement:()=>({setAttribute(){}})};
 let binder=extract(dir,'lts-v181-regression-closure.js','  function decorateMonthlyNumbers(){','  function decorateVersion(){');if(simulatePreFix)binder=binder.replace('row.dataset.ltsCategoryKey??','');vm.runInContext(binder,c);c.decorateMonthlyNumbers();
 if(cells[1].button?.onclick)cells[1].button.onclick();
 return {visibleTitle:title,emptyFebruaryCellBecameButton:!!cells[1].button,clickCalls:calls};
}
const result={base:test(dirs.base),preFixReconstructed:test(dirs.candidate,true),candidate:test(dirs.candidate)};fs.writeFileSync(path.join(__dirname,'monthly-key-collision-results.json'),JSON.stringify({scope:'Exact matrix and binder functions, minimal synthetic DOM; pre-fix reconstructed by removing the new raw-key lookup.',...result},null,2)+'\n');console.log(JSON.stringify(result,null,2));
assert.equal(result.base.emptyFebruaryCellBecameButton,false);
assert.equal(result.preFixReconstructed.emptyFebruaryCellBecameButton,true);
assert.equal(result.preFixReconstructed.clickCalls[0][0],'Assinaturas');
assert.equal(result.preFixReconstructed.clickCalls[0][3],200);
assert.equal(result.candidate.emptyFebruaryCellBecameButton,false);console.log('REPRODUCED pre-fix collision; current candidate raw-key binding protects zero cell.');
