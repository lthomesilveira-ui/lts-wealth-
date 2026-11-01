'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
async function transport(){
 const src=fs.readFileSync('releases/v393/lts-v227-read-transport.js','utf8'),runtime=src.slice(src.indexOf(' function runtime(){'),src.indexOf(' function install(){'));
 const started=[],release=new Map(),timers=[],waiters=new Map();let active=0,maxActive=0;
 const window={fetch:(url)=>{const name=url.split('/').pop();started.push(name);active++;maxActive=Math.max(maxActive,active);waiters.get(name)?.();return new Promise(resolve=>release.set(name,()=>{active--;resolve(new Response('{"ok":true}',{status:200}));}));},dispatchEvent(){}};
 window.parent=window;
 const context={window,document:{documentElement:{setAttribute(){}}},Headers,Response,Request,AbortController,DOMException,Event,performance,
  setTimeout:(fn,ms)=>{timers.push(ms);return setTimeout(fn,ms);},clearTimeout};
 vm.runInNewContext(runtime+'\nruntime();',context);
 const ready=name=>new Promise(resolve=>waiters.set(name,resolve));
 const flowReady=ready('lts_browser_flow_v242'),monthReady=ready('lts_browser_month_overview_v393');
 const a=window.fetch('https://example.invalid/rest/v1/rpc/lts_browser_flow_v242',{body:'{}'});await flowReady;
 const b=window.fetch('https://example.invalid/rest/v1/rpc/lts_browser_month_overview_v393',{body:'{}'});
 assert.deepEqual(started,['lts_browser_flow_v242'],'monthly overview waits for existing heavy read');
 release.get('lts_browser_flow_v242')();await a;await monthReady;release.get('lts_browser_month_overview_v393')();await b;
 await window.fetch('https://example.invalid/rest/v1/rpc/lts_browser_month_overview_v393',{body:'{}'});
 assert.equal(maxActive,1);assert.deepEqual(started,['lts_browser_flow_v242','lts_browser_month_overview_v393']);assert.equal(timers.filter(x=>x===48000).length,2);
 const dayReady=ready('lts_browser_month_overview_v393');window.__LTS_V227_TRANSPORT.invalidate(false);const d=window.fetch('https://example.invalid/rest/v1/rpc/lts_browser_month_overview_v393',{body:'{}'});await dayReady;release.get('lts_browser_month_overview_v393')();await d;assert.equal(started.filter(x=>x==='lts_browser_month_overview_v393').length,2,'day invalidation cannot reuse yesterday\'s identical month request');
}
async function capability(){
 const src=fs.readFileSync('releases/v393/lts-v269-client-contract.js','utf8');let body={complete:true,source_complete:true,source_revision:'synthetic-source',source_epoch:1};const sent=[];
 const window={location:{href:'https://example.invalid/'},fetch:async(_url,init)=>{sent.push(init.headers.get('x-client-info'));return new Response(JSON.stringify(body),{status:200});}};
 vm.runInNewContext(src,{window,Headers,Request,URL});
 await window.fetch('https://tadhkamnwtsbdozwkyut.supabase.co/rest/v1/rpc/lts_browser_product_v1');
 body={...body,cash_complete:false,cash:{undated:[{amount:12.34}]}};
 await window.fetch('https://tadhkamnwtsbdozwkyut.supabase.co/rest/v1/rpc/lts_browser_month_overview_v393');
 assert.equal(window.__LTS_V269_COMPLETENESS().incomplete,false,'an undated bill is not a global C6 source failure');assert.equal(sent[1],'lts-wealth-v269-c6-completeness');
 body={...body,complete:false,source_complete:false};await window.fetch('https://tadhkamnwtsbdozwkyut.supabase.co/rest/v1/rpc/lts_browser_month_overview_v393');assert.equal(window.__LTS_V269_COMPLETENESS().incomplete,true,'real source incompleteness remains global');
}
(async()=>{await transport();await capability();console.log(JSON.stringify({pass:true,monthly_read_serialized:true,single_flight_and_cache:true,source_header_present:true,undated_bill_not_global_c6_failure:true,no_login_or_network:true}));})().catch(e=>{console.error(e);process.exitCode=1;});
