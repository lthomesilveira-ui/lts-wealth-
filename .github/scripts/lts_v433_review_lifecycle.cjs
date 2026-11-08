'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const results=[];
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const flush=()=>new Promise(r=>setImmediate(r));
function harness(release){
 const source=fs.readFileSync('releases/'+release+'/lts-v181-regression-closure.js','utf8');
 const rpc=source.slice(source.indexOf('  async function rpc('),source.indexOf('  function optionRows('));
 const start=source.indexOf(release==='v425'?'  async function ensureReview(':'  const reviewGeneration=');
 const load=source.slice(start,source.indexOf('  async function ensureReconciliation(',start));
 const requests=[],timers=new Map();let timerId=0;
 const context={state:{review:{status:'idle',data:null,key:'',offset:0,query:'',drafts:new Map()}},BOOT:{generation:'owner-a'},D:{},window:{__LTS_V227_TRANSPORT:{installed:true}},today:()=> '2026-11-08',render:()=>{},setTimeout:(fn,ms)=>{const id=++timerId;timers.set(id,{fn,ms});return id;},clearTimeout:id=>timers.delete(id),S:{rpc:(name,args)=>{const p=deferred();requests.push({name,args,...p});return p.promise;}}};
 vm.createContext(context);vm.runInContext(rpc+'\n'+load,context);
 return{context,requests,timers,advance:ms=>{for(const[id,t]of [...timers])if(t.ms<=ms){timers.delete(id);t.fn();}},load:force=>vm.runInContext('ensureReview('+!!force+')',context),sync:()=>vm.runInContext('syncReviewSession()',context)};
}
function packet(req,count=0){return{from:req.args.p_from,to:req.args.p_to,offset:req.args.p_offset,row_count:count,matched_count:count,rows:count?[{key:'synthetic-row',description:'Synthetic expense',source_ref:'fixture-only'}]:[],next_offset:null};}
(async()=>{
 // Reproduce the production timing boundary without sleeping or real requests.
 for(const release of ['v425','v433']){
  const h=harness(release),done=h.load();h.advance(23000);await flush();
  assert.equal(h.context.state.review.status,release==='v425'?'error':'loading');
  h.requests[0].resolve({data:packet(h.requests[0]),error:null});await done;
  assert.equal(h.context.state.review.status,release==='v425'?'error':'ready');
  results.push({case:'queued-valid-response',release,result:h.context.state.review.status});
 }
 {
  const h=harness('v433'),a=h.load();h.context.state.review.status='idle';h.context.state.review.query='new search';const b=h.load(true);
  h.requests[0].resolve({data:packet(h.requests[0],1)});await a;
  assert.equal(h.context.state.review.status,'loading');assert.equal(h.context.state.review.data,null);
  h.requests[1].resolve({data:packet(h.requests[1])});await b;assert.equal(h.context.state.review.status,'ready');assert.equal(h.context.state.review.data.row_count,0);
  results.push({case:'superseded-query',pass:true});
 }
 {
  const h=harness('v433'),a=h.load();h.context.BOOT.generation='owner-b';h.sync();
  h.requests[0].resolve({data:packet(h.requests[0],1)});await a;
  assert.equal(h.context.state.review.status,'idle');assert.equal(h.context.state.review.data,null);assert.equal(h.context.state.review.query,'');
  results.push({case:'session-change-does-not-retain-private-list',pass:true});
 }
 for(const mutate of [d=>null,d=>({...d,rows:null}),d=>({...d,row_count:-1}),d=>({...d,from:'2019-01-01'}),d=>({...d,offset:25}),d=>({...d,matched_count:1,rows:[],row_count:0})]){
  const h=harness('v433'),a=h.load();h.requests[0].resolve({data:mutate(packet(h.requests[0]))});await a;
  assert.equal(h.context.state.review.status,'error');assert.equal(h.context.state.review.data,null);
 }
 results.push({case:'malformed-response-does-not-become-zero',cases:6,pass:true});
 {
  const h=harness('v433'),a=h.load();h.requests[0].resolve({data:packet(h.requests[0],1)});await a;
  const old=h.context.state.review.data,b=h.load(true);h.requests[1].resolve({error:{message:'Synthetic failure'}});await b;
  assert.equal(h.context.state.review.status,'error');assert.equal(h.context.state.review.data,old);
  const c=h.load(true);h.requests[2].resolve({data:packet(h.requests[2])});await c;assert.equal(h.context.state.review.status,'ready');
  results.push({case:'failed-refresh-preserves-known-list-and-retry',pass:true});
 }
 for(const name of ['lts_browser_expense_review_decision_v229','lts_browser_invoice_flow_reconciliation_v181']){
  const h=harness('v433'),p=vm.runInContext('rpc('+JSON.stringify(name)+',{})',h.context);h.advance(23000);await assert.rejects(p);assert.equal(h.requests.length,1);
 }
 {
  const h=harness('v433');h.context.window.__LTS_V227_TRANSPORT.installed=false;const p=h.load();h.advance(23000);await p;assert.equal(h.context.state.review.status,'error');
 }
 results.push({case:'write-other-rpc-and-no-transport-timeouts-preserved',pass:true});
 const source=fs.readFileSync('releases/v433/index.html','utf8');
 const text=source.slice(source.indexOf('function flowInternalTransferTitle('),source.indexOf('function flowSemanticTitle('));
 const c={mergedFlowEvents:()=>[],num:Number};vm.createContext(c);vm.runInContext(text,c);
 for(const field of ['category','description'])assert.equal(c.flowInternalTransferTitle({asset_movement:true,internal_transfer:true,[field]:'Resgate FGTS',account:'Itaú'}),'Resgate FGTS');
 for(const e of [{category:'Resgate FGTS'},{asset_movement:false,description:'Resgate FGTS'},{asset_movement:true,description:'TED CAIXA'},{asset_movement:true,description:'Resgate de aplicação'}])assert.equal(c.flowInternalTransferTitle({...e,account:'Itaú'}),'Movimentação entre contas · Itaú');
 results.push({case:'only-confirmed-fgts-caption',positive:2,negative:4,pass:true});
 fs.mkdirSync('qa/v433',{recursive:true});fs.writeFileSync('qa/v433/lifecycle.json',JSON.stringify({pass:true,results,real_credentials:false,financial_writes:0},null,2));console.log(JSON.stringify({pass:true,results}));
})().catch(e=>{console.error(e);process.exitCode=1;});
