const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(process.env.LTS_RELEASE_DIR?process.env.LTS_RELEASE_DIR+'/lts-v226-card-composition.js':__dirname+'/lts-v226-card-composition.js','utf8');
const load=source.slice(source.indexOf('    async function loadCycles('),source.indexOf('    async function loadHistory('));
const route=source.slice(source.indexOf('    const previousSettlement='),source.indexOf('    st.openDetail=openDetail;'));
const tick=()=>new Promise(r=>setImmediate(r));
async function setup(){let resolve,reject,calls=0;const opened=[],legacy=[];const pending=new Promise((a,b)=>{resolve=a;reject=b});const st={epoch:0,cycles:null,loading:false,error:'',loadedAt:0};const ctx={st,Date,window:{LTSFlowInvoiceTarget:{resolve:()=>({ok:true,family:'c6',month:'2026-10-01'})}},V:'Fluxo Diário',today:()=> '2026-10-14',active:()=>true,paint:()=>{},rpc:()=>{calls++;return pending},document:{activeElement:null},openDetail:async(...a)=>opened.push(a),openCardSettlement:e=>legacy.push(e)};vm.createContext(ctx);vm.runInContext(load+route,ctx);return {ctx,st,opened,legacy,resolve,reject,calls:()=>calls};}
(async()=>{
 let h=await setup();const p=h.ctx.loadCycles();const q=h.ctx.openCardSettlement({source:'card_invoice'});await tick();assert.equal(h.calls(),1);assert.equal(h.opened.length,0);h.resolve({version:'card-cycles-v226',cards:[]});await Promise.all([p,q]);assert.equal(h.opened.length,1,'existing load awaited');
 h=await setup();const a=h.ctx.openCardSettlement({source:'card_invoice'});await tick();h.ctx.openCardSettlement({source:'historical_card'});h.resolve({version:'card-cycles-v226',cards:[]});await a;assert.equal(h.opened.length,0,'historic click invalidates modern pending');assert.equal(h.legacy.length,1);
 h=await setup();const b=h.ctx.openCardSettlement({source:'card_invoice'});h.st.epoch++;h.resolve({version:'card-cycles-v226',cards:[]});await b;assert.equal(h.opened.length,0,'epoch invalidates result');
 h=await setup();const c=h.ctx.loadCycles();h.reject(new Error('fixture unavailable'));await c;assert(h.st.error);assert.equal(h.st.loading,false);assert.equal(h.st.cycles,null);
 console.log('invoice async generation PASS');
})().catch(e=>{console.error(e);process.exitCode=1});
