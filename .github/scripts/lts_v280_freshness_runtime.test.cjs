'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),src=fs.readFileSync(path.join(root,'releases/v280/lts-v225-open-finance.js'),'utf8');
const runtime=src.slice(src.indexOf('  function runtime() {'),src.indexOf('\n  let attempts=0;'))+'\nruntime();';
const checks=[];const check=(name,test)=>{assert(test,name);checks.push(name)};
class Node{
 constructor(tag,doc){this.tagName=tag;this.doc=doc;this.children=[];this.dataset={};this.className='';this.textContent='';this.parent=null;this.open=false;this._html='';this.style={};this.attrs={};}
 appendChild(n){n.remove();n.parent=this;this.children.push(n);return n;}
 insertAdjacentElement(_,n){const p=this.parent;if(!p)return; n.remove();n.parent=p;p.children.splice(p.children.indexOf(this)+1,0,n);}
 setAttribute(k,v){this.attrs[k]=v;}
 get innerHTML(){return this._html;}set innerHTML(v){this._html=v;this.children=[];if(v.includes('<button')){const b=new Node('button',this.doc);this.appendChild(b);}}
 querySelector(sel){return this.querySelectorAll(sel)[0]||null;}
 querySelectorAll(sel){const out=[];for(const c of this.children){if(sel==='button'&&c.tagName==='button'||sel==='span'&&c.tagName==='span'||sel[0]==='.'&&c.className.split(' ').includes(sel.slice(1)))out.push(c);out.push(...c.querySelectorAll(sel));}return out;}
 remove(){if(this.parent){const p=this.parent;p.children=p.children.filter(n=>n!==this);this.parent=null;}}
 addEventListener(){}
}
class Doc{
 constructor(){this.body=new Node('body',this);this.head=new Node('head',this);this.hidden=false;}
 createElement(tag){return new Node(tag,this)}
 getElementById(id){const walk=n=>n.id===id?n:n.children.map(walk).find(Boolean);return walk(this.body)||walk(this.head)||null;}
 querySelector(sel){if(sel==='.v168-dashboard .v168-headmeta, .v168-updates .v168-headmeta')return this.host;return this.querySelectorAll(sel)[0]||null;}
 querySelectorAll(sel){if(sel==='.v168-dashboard .v168-kpi')return this.dashboard?this.kpis:[];return this.body.querySelectorAll(sel);}
 addEventListener(){}
 reset(view){this.body.children=[];this.dashboard=view==='Dashboard';this.host=new Node('div',this);this.host.className='v168-headmeta';this.body.appendChild(this.host);if(view==='Dashboard'){this.grid=new Node('div',this);this.grid.className='v168-kpis';this.body.appendChild(this.grid);this.kpis=['Total disponível hoje','Contas correntes hoje','FGTS','RSU','Outros'].map(text=>{const card=new Node('div',this);card.className='v168-kpi';this.grid.appendChild(card);const label=new Node('span',this);label.textContent=text;card.appendChild(label);const value=new Node('strong',this);value.textContent='R$ 100,00';card.appendChild(value);return card;});this.kpi=this.kpis[1];}if(view==='Fluxo Diário'){const p=new Node('div',this);p.id='v274ReceivedPosition';p.textContent='Last received fixture 100';this.body.appendChild(p);}}
}
const now='2026-09-20T13:00:00Z';class TestDate extends Date{constructor(...args){super(...(args.length?args:[now]))}static now(){return Date.parse(now)}}
const banks=[['341','Itaú',80],['237','Bradesco',20],['336','C6',0]];
const cash={status:'ready',date:'2026-09-20',data:{status:'complete',as_of:'2026-09-20',cash:100,day:Object.fromEntries(banks.map(([,bank,balance])=>[bank,{balance,net:null}])),bank_positions:banks.map(([institution_code,institution,balance],i)=>({institution_code,institution,balance,as_of:'2026-09-19T18:00:00Z',source_id:'synthetic-position-'+i}))}};
function snapshot(time='2026-09-20T12:00:00Z',origin='2026-09-19T18:00:00Z'){return {connections:banks.map(([institution_code],i)=>({id:'synthetic-connection-'+i,provider:'synthetic-provider',institution_code,status:'connected',last_success_at:time,provider_item_updated_at:origin}))}}
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject};}
const doc=new Doc(),queue=[],calls=[],timers=[],micro=[];let renders=0,refreshes=0;
const frame={window:null,document:doc,Intl,Date:TestDate,Map,Set,Promise,BOOT:{generation:1},D:{synthetic:true},N:{classList:{contains:()=>false}},V:'Dashboard',ACC:'Consolidado',FLOWLOADING:false,
 render(){renders++;doc.reset(frame.V);return 'original-render-result'},
 setTimeout(fn,ms){timers.push({fn,ms});return timers.length},clearTimeout(){},queueMicrotask(fn){micro.push(fn)},
 sessionStorage:{getItem(){return null},setItem(){}},S:{rpc(name){calls.push(name);const item=queue.shift();assert(item,'queued response for '+name);return item.promise||Promise.resolve({data:item,error:null});},auth:{}},
 __LTS_V178_STATE:{cash},__LTS_V178_REVIEW:{ready:async()=>{},refresh:async()=>{refreshes++},cashComplete:c=>c.status==='ready'&&c.date==='2026-09-20'},__LTS_V168_STATE:{updates:{}},
};frame.window=frame;vm.createContext(frame);doc.reset(frame.V);
(async()=>{
 const before=JSON.stringify(cash);vm.runInContext(runtime,frame);const state=frame.__LTS_V225;
 check('Real candidate installs with legacy auth shim lacking onAuthStateChange',state.installed);
 let panel=doc.querySelector('.v225-balance-freshness');check('Compact metadata is a grid sibling immediately after bank KPI',panel&&panel.parent===doc.grid&&doc.grid.children.indexOf(panel)===doc.grid.children.indexOf(doc.kpi)+1&&!panel.innerHTML.includes('<details'));
 check('Metadata is never nested inside any numeric KPI',doc.kpis.every(card=>card.querySelector('.v225-balance-freshness')===null));
 check('Panel title explicitly limits its dates to checking accounts',panel.innerHTML.includes('Contas correntes · posição do provedor (BRT)'));
 check('Bank-specific dates are shown without altering balance',panel.innerHTML.includes('19/09/2026, 15:00 BRT')&&doc.kpi.children.find(n=>n.tagName==='strong').textContent==='R$ 100,00');
 check('Today label no longer masquerades as provider-current balance',doc.kpi.querySelector('span').textContent==='Contas correntes · posição recebida');
 const first=deferred();queue.push(first);const a=state.readStatus(),b=state.readStatus();check('Concurrent consumers share existing in-flight status RPC',calls.length===1);first.resolve({data:snapshot(),error:null});await Promise.all([a,b]);
 check('Current authenticated status accepted',state.status.connections.length===3);
 queue.push(snapshot('2026-09-20T12:15:00Z'));await state.readStatus();check('Same origin / new receipt tracked',state.observations.values().next().value.change==='unchanged');
 const wrapper=frame.render;vm.runInContext(runtime,frame);check('Repeated install does not stack render wrappers',frame.render===wrapper);
 check('Original render result preserved',frame.render()==='original-render-result');panel=doc.querySelector('.v225-balance-freshness');check('Full DOM replacement restores exactly one compact panel',!!panel&&doc.querySelectorAll('.v225-balance-freshness').length===1);
 frame.V='Fluxo Diário';frame.ACC='Itaú';frame.render();panel=doc.querySelector('.v225-balance-freshness');check('Flow bank selection scopes timestamp beside received position',panel.innerHTML.includes('Itaú')&&!panel.innerHTML.includes('Bradesco')&&doc.body.children.indexOf(panel)===doc.body.children.indexOf(doc.getElementById('v274ReceivedPosition'))+1);
 frame.ACC='C6';frame.render();check('Repeated bank switch cannot retain another account timestamp',doc.querySelector('.v225-balance-freshness').innerHTML.includes('C6')&&!doc.querySelector('.v225-balance-freshness').innerHTML.includes('Itaú'));
 frame.__LTS_V178_STATE.cash.status='error';frame.render();check('Cached metadata in error state is never a bank-position timestamp',doc.querySelector('.v225-balance-freshness').innerHTML.includes('indisponível'));
 frame.__LTS_V178_STATE.cash.status='ready';frame.V='Dashboard';frame.render();
 const old=deferred();queue.push(old);const oldRead=state.readStatus();frame.BOOT.generation++;frame.D={synthetic:'new-login'};old.resolve({data:snapshot('2026-09-20T12:30:00Z'),error:null});await oldRead;
 check('Logout/login before old response discards it even with no intervening render or auth event',state.status===null&&state.statusRead===null&&state.observations.size===0);
 queue.push(snapshot());await state.readStatus();check('New generation can load normally after stale read',state.status.connections[0].last_success_at==='2026-09-20T12:00:00Z');
 const refreshRequest=deferred();queue.push(refreshRequest);const refresh=state.refresh();for(let i=0;i<12&&calls.at(-1)!=='lts_browser_open_finance_refresh_v1';i++)await Promise.resolve();assert.equal(calls.at(-1),'lts_browser_open_finance_refresh_v1');frame.BOOT.generation++;frame.D={synthetic:'third-login'};const requests=calls.length;refreshRequest.resolve({data:{ok:true,requested_at:'2026-09-20T12:50:00Z'},error:null});await refresh;
 check('Obsolete refresh response cannot start polling new session',calls.length===requests&&state.requestedAt===null);
 frame.render();queue.push(snapshot());await state.readStatus();queue.push({ok:true,requested_at:'2026-09-20T12:50:00Z'},snapshot('2026-09-20T12:55:00Z'));await state.refresh();
 check('Successful collection distinguishes receipt from same connection origin',state.message.includes('mesma origem de conexão')&&!state.message.includes('saldo atualizado'));
 check('Completion refreshes existing screen pipeline rather than adding one',refreshes>=1&&!state.syncing);
 check('No financial payload mutation',JSON.stringify(cash)===before);
 frame.V='Patrimônio';frame.render();check('Leaving balance views removes provenance panel',!doc.querySelector('.v225-balance-freshness'));
 check('Render model schedules no recurring timers beyond existing watch/poll',timers.every(t=>t.ms===60000||t.ms===5000));
 delete frame.BOOT;queue.push(snapshot());await state.readStatus();
 const withoutBoot=deferred();queue.push(withoutBoot);const fallbackRead=state.readStatus();frame.D={synthetic:'fallback-new-product'};withoutBoot.resolve({data:snapshot('2026-09-20T12:58:00Z'),error:null});await fallbackRead;
 check('Without BOOT, local product-object replacement invalidates old response without asserting user identity',state.status===null&&state.statusRead===null);
 const report={passed:checks.length,checks,scope:'Candidate runtime in VM with minimal DOM shim and synthetic RPCs; no browser or live integration executed.'};fs.writeFileSync(path.join(root,'runtime-results.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1});
