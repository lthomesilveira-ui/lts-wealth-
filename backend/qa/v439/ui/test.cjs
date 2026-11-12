const assert = require('node:assert/strict');
const fs = require('node:fs');
const candidate = require('./lts-v412-projection-policy.js');
const baseline = require('./baseline.js');
const { chromium, webkit } = process.env.RUN_BROWSER ? require('playwright') : {};
function fixture(asOf='2027-01-31') {
 const year=Number(asOf.slice(0,4));
 return {version:'projection-policy-v412', enabled:true, schema_version:1, card_method:'total_budget_floor',outliers_excluded:false,missing_months_assumed_zero:false,financial_sources_modified:false, as_of:asOf,horizon_end:(year+5)+'-12-31',next_review_on:(year+1)+'-01-01',history_window:{from:'2026-10-01',to:'2026-12-31'},warnings:[],series:[{series_key:'card_example',description:'Cartão exemplo',method:'history_total_budget',direction:'expense',expected_months:3,coverage_months:3,observed_months:3,months_with_spend:3,outlier_months:[],warnings:[],annual_totals:[],reference_stale:false,annual_rate:0,reference_window:{from:'2026-10-01',to:'2026-12-31'},reference_amount_brl:'8000.00',uses_history:true}]};
}
function withProvision(asOf) {
 const f=fixture(asOf); f.series[0].new_spend_provision={starts_on:'2027-02-01',amount_brl:'7500.00',source_ref:'synthetic-private-marker'};
 if(asOf>='2027-02-01') Object.assign(f.series[0],{uses_history:false,reference_amount_brl:'7500.00',coverage_months:0,observed_months:0,months_with_spend:0});
 return f;
}
for(const date of ['2027-01-01','2027-01-31','2027-02-01','2027-03-01']) assert.deepEqual(candidate.build(fixture(date)),baseline.build(fixture(date)));
const pre=candidate.build(withProvision('2027-01-31')),post=candidate.build(withProvision('2027-02-01'));
assert.equal(pre.series[0].usesHistory,true); assert.equal(pre.series[0].amount,800000);
assert.equal(post.series[0].usesHistory,false);assert.equal(post.series[0].amount,750000);assert.equal(post.series[0].covered,0);
assert(!JSON.stringify(pre).includes('synthetic-private-marker'));assert(!JSON.stringify(post).includes('source_ref'));
const ending=fixture();ending.series[0].ends_on='2027-01-31';
assert.equal(candidate.build(ending).series[0].endsOn,'2027-01-31');
for(const value of ['2027-02-30',null,42]){const f=fixture();f.series[0].ends_on=value;assert.throws(()=>candidate.build(f));}
const mutations=[
 r=>r.new_spend_provision.starts_on='2027-01-15',
 r=>r.new_spend_provision.amount_brl='100000000.01',
 r=>r.new_spend_provision=null,r=>r.new_spend_provision=[],
 r=>r.new_spend_provision.starts_on='2027-02-30',r=>r.new_spend_provision.starts_on='2027-2-01',
 r=>delete r.new_spend_provision.starts_on,
 r=>r.new_spend_provision.amount_brl='-1',r=>r.new_spend_provision.amount_brl='1.001',
 r=>r.new_spend_provision.amount_brl=null,r=>r.new_spend_provision.amount_brl='9007199254740992',
 r=>r.method='fixed',r=>r.direction='income',r=>r.series_key='salary',
 r=>r.uses_history=true,r=>r.reference_amount_brl='14999.00',
 r=>r.expected_months=2,r=>r.reference_window.to='2026-12-30',
];
for(const mutate of mutations){const f=withProvision('2027-02-01');mutate(f.series[0]);assert.throws(()=>candidate.build(f),/Invalid projection response/);}
for(const f of [fixture(),withProvision('2027-01-31')]) {f.series[0].coverage_months=0;assert.throws(()=>candidate.build(f));}
const zero=withProvision('2027-02-01');zero.series[0].new_spend_provision.amount_brl='0.00';zero.series[0].reference_amount_brl='0';assert.throws(()=>candidate.build(zero));
const source=fs.readFileSync(__dirname+'/lts-v412-projection-policy.js','utf8');
const helpers=source.slice(source.indexOf('    const date = value'),source.indexOf('    function reset()'));
const renderer=source.slice(source.indexOf('    function message(text)'),source.indexOf('    function panel(compact)'));
// Isolated DOM construction checks are not browser or full-app acceptance.
class Node {
 constructor(tag){this.tag=tag;this.children=[];this.attrs={};this._text='';}
 set textContent(value){this._text=String(value);}
 get textContent(){return this._text+this.children.map(n=>n.textContent).join(' ');}
 append(...nodes){this.children.push(...nodes);}
 setAttribute(key,value){this.attrs[key]=value;}
}
const context={document:{createElement:tag=>new Node(tag)},Intl};
require('node:vm').createContext(context);
require('node:vm').runInContext(helpers+renderer+';this.origin=origin;',context);
assert(context.origin(candidate.build(ending)).textContent.includes('Projeção de novos gastos até 31/01/2027; parcelas já existentes continuam.'));
for (const [label,model] of [['before',pre],['after',post]]) {
 const rendered=context.origin(model),text=rendered.textContent;
 assert.equal(rendered.tag,'details');assert.equal(rendered.attrs.open,undefined);
 assert(text.includes('7.500,00/mês a partir de 01/02/2027, além das parcelas.'));
 assert.equal(text.includes('Média de 3 meses'),label==='before');
 assert.equal(text.includes('Janela da média:'),label==='before');
 assert(!/source_ref|synthetic-private-marker|new_spend_provision|history_total_budget/.test(text));
}
(async()=>{
 const results=[];
 for(const [engine,type] of Object.entries(process.env.RUN_BROWSER ? {chromium,webkit} : {})) {
  let browser;
  try{browser=await type.launch({headless:true,...(engine==='chromium'?{executablePath:'/usr/bin/chromium',args:['--no-sandbox']}:{})});}catch(e){results.push({engine,blocked:e.message});continue;}
  for(const width of [390,1365]) {
   const page=await browser.newPage({viewport:{width,height:900}});
   for(const [label,model] of [['before',pre],['after',post]]) {
    await page.setContent('<html lang="pt-BR"><body><details id="options"><summary>Opções</summary><div id="host"></div></details></body></html>');
    await page.addScriptTag({content:helpers+renderer+'\nwindow.renderOrigin = origin;'});
    await page.evaluate(model=>document.getElementById('host').append(window.renderOrigin(model)),model);
    assert.equal(await page.locator('.v412-origin').getAttribute('open'),null);
    assert(!(await page.locator('body').innerText()).includes('Novos gastos'));
    const closed=await page.locator('#options').boundingBox(); assert(closed.height<60);
    await page.locator('#options>summary').click(); await page.locator('.v412-origin>summary').click();
    const text=await page.locator('body').innerText();
    assert(text.includes('7.500,00/mês a partir de 01/02/2027, além das parcelas.'));
    assert(!/source_ref|synthetic-private-marker|new_spend_provision|history_total_budget/.test(text));
    assert.equal(text.includes('Média de 3 meses'),label==='before');
    assert.equal(text.includes('Janela da média:'),label==='before');
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    await page.screenshot({path:__dirname+'/'+engine+'-'+width+'-'+label+'.png',fullPage:true});
    results.push({engine,width,label,closedHeight:closed.height,passed:true});
   }
   await page.close();
  }
  await browser.close();
 }
 fs.writeFileSync(__dirname+'/test-results.json',JSON.stringify({unit:'passed',invalidCases:mutations.length,isolatedPremissasRendering:results,browserStatus:process.env.RUN_BROWSER?'attempted':'not rerun; prior socket restriction and missing WebKit',fullAppAcceptance:'not run',production:'unchanged'},null,2));
 console.log(JSON.stringify(results,null,2));
})();
