'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function harness(release='v451',latency=1000){
 let now=0,serial=0,active=0,max=0,context;const timers=new Map(),starts=[],events=[];
 const later=(fn,ms=0)=>{const id=++serial;timers.set(id,{at:now+ms,fn});return id},clear=id=>timers.delete(id);
 const inner={parent:{LTSV384ReadPriority:require('../../releases/'+release+'/lts-v384-read-priority.js')},dispatchEvent(){},V:'Dashboard',location:{pathname:'/releases/'+release+'/index.html'},
  fetch:(url,init)=>new Promise((resolve,reject)=>{active++;max=Math.max(max,active);starts.push(url.split('/').pop());let done=false;
   const finish=error=>{if(done)return;done=true;active--;error?reject(error):resolve(new Response('{}'))};
   const t=later(()=>finish(),latency);init?.signal?.addEventListener('abort',()=>{clear(t);finish(new DOMException('Aborted','AbortError'))},{once:true});
  })};inner.window=inner;
 const doc={head:{appendChild:n=>vm.runInContext(n.textContent,context)},documentElement:{setAttribute:(k,v)=>events.push(JSON.parse(v))},getElementById:()=>null,createElement:()=>({})};inner.document=doc;
 context=vm.createContext({...inner,Headers,Response,AbortController,DOMException,Event,performance:{now:()=>now},setTimeout:later,clearTimeout:clear});
 const shell={contentWindow:inner,contentDocument:doc,addEventListener(){}};
 vm.runInNewContext(fs.readFileSync('releases/'+release+'/lts-v227-read-transport.js','utf8'),{window:{},document:{getElementById:()=>shell},setTimeout:later,clearTimeout:clear});
 const settle=async()=>{for(let i=0;i<12;i++)await Promise.resolve();await new Promise(setImmediate)};
 async function advance(ms){const end=now+ms;await settle();while(true){const next=[...timers].filter(([,x])=>x.at<=end).sort((a,b)=>a[1].at-b[1].at||a[0]-b[0])[0];if(!next)break;now=next[1].at;timers.delete(next[0]);next[1].fn();await settle()}now=end;await settle();}
 return{advance,starts,events,get max(){return max},transport:context.window.__LTS_V227_TRANSPORT,
  request:name=>context.window.fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'synthetic-only'},body:'{}'})};
}
test('a valid 28-second cockpit body survives the existing 45-second database ceiling',async()=>{
 const old=harness('v449',28000),bad=assert.rejects(old.request('lts_browser_dashboard_cockpit_v1'),{name:'AbortError'});await old.advance(30000);await bad;
 const current=harness('v451',28000),good=current.request('lts_browser_dashboard_cockpit_v1');await current.advance(30000);assert.equal((await good).status,200);assert.equal(current.max,1);
 assert.equal(current.events.at(-1).at(-1).duration_ms,28000);
});
test('cockpit and generic read execution deadlines stay bounded',async()=>{
 for(const[name,ceiling]of[['lts_browser_dashboard_cockpit_v1',48000],['lts_browser_expenses_v229',25000]]){
  const h=harness('v451',100000),p=assert.rejects(h.request(name),{name:'AbortError'});await h.advance(ceiling+100);await p;
  assert.equal(h.events.at(-1).at(-1).duration_ms,ceiling);assert.equal(h.events.at(-1).at(-1).status,'timeout');
 }
});
test('a 75-second intentional collection hold does not spend the eligible queue budget',async()=>{
 const old=harness('v449'),oldHold=old.transport.holdHeavyReads();assert.equal(await oldHold.ready,true);
 const bad=assert.rejects(old.request('lts_browser_expense_review_queue_v229'),{name:'AbortError'});await old.advance(75000);await bad;oldHold.release();
 const h=harness(),a=h.transport.holdHeavyReads(),b=h.transport.holdHeavyReads();assert.equal(await a.ready,true);assert.equal(await b.ready,true);
 const p=h.request('lts_browser_expense_review_queue_v229');await h.advance(30000);a.release();await h.advance(45000);assert.deepEqual(h.starts,[]);
 b.release();await h.advance(1100);assert.equal((await p).status,200);assert.equal(h.max,1);
 assert.equal(h.events.at(-1).at(-1).queued_ms,75000);
});
test('eligible admission still expires after 60 seconds without a collection hold',async()=>{
 const h=harness('v451',100000),flow=assert.rejects(h.request('lts_browser_flow_v242'),{name:'AbortError'});await h.advance(31);
 const wealth=assert.rejects(h.request('lts_browser_wealth_detail_v242'),{name:'AbortError'});
 const last=assert.rejects(h.request('lts_browser_expense_review_queue_v229'),{name:'AbortError'});
 await h.advance(75000);await Promise.all([flow,wealth,last]);
 assert(h.events.at(-1).some(e=>e.name==='lts_browser_expense_review_queue_v229'&&e.status==='admission_timeout'&&e.queued_ms===60000));assert.equal(h.max,1);
 assert(!JSON.stringify(h.events).includes('synthetic-only'));
});
