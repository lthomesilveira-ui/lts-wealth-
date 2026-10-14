const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const calls=[],base='https://tadhkamnwtsbdozwkyut.supabase.co',cap='lts-wealth-v269-c6-completeness';
let nextPayload=null,closed=0;
const w={document:{querySelectorAll:()=>[{close(){closed++}}]},location:{href:'https://app.example/'},fetch:async(input,init)=>{calls.push({input,init});return nextPayload===null?{ok:true}:new Response(JSON.stringify(nextPayload),{status:200})}};
vm.runInNewContext(fs.readFileSync('releases/v269/lts-v269-client-contract.js','utf8'),{window:w,URL,Headers,Request});
(async()=>{
const prepared=w.__LTS_V269_PRESENTATION.prepared;assert.equal(prepared.length,5);
for(const name of prepared){await w.fetch(base+'/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'synthetic-auth'},body:'{}'});const c=calls.at(-1);assert.equal(c.init.headers.get('x-client-info'),cap);assert.equal(c.init.headers.get('Authorization'),'synthetic-auth');assert.equal(c.init.body,'{}');}
for(const url of ['https://other.example/rest/v1/rpc/lts_browser_product_v1',base+'/auth/v1/token',base+'/rest/v1/rpc/lts_browser_dashboard_cockpit_v1',base+'/rest/v1/rpc/lts_browser_cash_today_v242',base+'/rest/v1/rpc/lts_browser_product_v1/extra']){const opts={method:'POST',body:'{}'};await w.fetch(url,opts);assert.equal(calls.at(-1).input,url);assert.equal(calls.at(-1).init,opts);}
const req=new Request(base+'/rest/v1/rpc/lts_browser_flow_v241',{method:'POST',headers:{Authorization:'synthetic-auth','x-test':'preserved'},body:JSON.stringify({p_from:'2026-01-01',p_to:'2026-02-01'})});await w.fetch(req,{headers:{'x-override':'yes'}});let c=calls.at(-1);assert.equal(c.input.url,base+'/rest/v1/rpc/lts_browser_flow_v242');assert.equal(await c.input.text(),JSON.stringify({p_from:'2026-01-01',p_to:'2026-02-01'}));assert.equal(c.init.headers.get('Authorization'),'synthetic-auth');assert.equal(c.init.headers.get('x-test'),'preserved');assert.equal(c.init.headers.get('x-override'),'yes');
nextPayload={ok:true,complete:true,source_complete:true,source_epoch:1,source_revision:'rev1'};await w.fetch(base+'/rest/v1/rpc/lts_browser_product_v1');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,false);
nextPayload={complete:false,source_complete:false,source_epoch:2,source_revision:'rev2'};await w.fetch(base+'/rest/v1/rpc/lts_browser_card_cycles_v229');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,true);assert.equal(closed,1);
nextPayload={ok:true};await w.fetch(base+'/rest/v1/rpc/lts_browser_card_detail_v226');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,true);
await w.fetch(base+'/rest/v1/rpc/lts_browser_flow_v242');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,true);
nextPayload={complete:true,source_complete:true,source_epoch:1,source_revision:'old'};await w.fetch(base+'/rest/v1/rpc/lts_browser_product_v1');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,true);
nextPayload={complete:true,source_complete:true,source_epoch:3,source_revision:'rev3'};await w.fetch(base+'/rest/v1/rpc/lts_browser_product_v1');assert.equal(w.__LTS_V269_COMPLETENESS().incomplete,false);
console.log('PASS: five prepared readers; external/auth/cash/auxiliary untouched; request body and auth preserved; v241 remapped.');
})().catch(e=>{console.error(e);process.exitCode=1});
