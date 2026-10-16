'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const assetPath=require('node:path').resolve(process.env.LTS_OVERDUE_ASSET || 'releases/v278/lts-v275-overdue-visibility.js');
const source=fs.readFileSync(assetPath,'utf8'),checks=[];
const check=(name,condition)=>{assert(condition,name);checks.push(name)};
class Node {
  constructor(tag,doc){this.tagName=tag;this.doc=doc;this.children=[];this.listeners={};this.open=false;this._html='';}
  set innerHTML(value){this._html=value;this.detail=value.includes('<details')?new Node('details',this.doc):null;if(this.detail)this.detail.open=value.includes('<details open>');}
  get innerHTML(){return this._html;}
  setAttribute(k,v){this[k]=v;}
  appendChild(child){this.children.push(child);if(child.id)this.doc.nodes.set(child.id,child);if(child.tagName==='script')vm.runInContext(child.textContent,this.doc.context);return child;}
  insertAdjacentElement(_,child){this.doc.nodes.set(child.id,child);}
  querySelector(sel){return sel==='details'?this.detail:null;}
  addEventListener(name,fn){this.listeners[name]=fn;}
  remove(){this.doc.nodes.delete(this.id);}
}
class Doc {
  constructor(){this.nodes=new Map();this.head=new Node('head',this);}
  createElement(tag){return new Node(tag,this);}
  getElementById(id){return this.nodes.get(id)||null;}
  querySelector(sel){return sel==='.flowbar'?this.nodes.get('ltsBankEvidence'):null;}
  reset(){this.nodes.delete('ltsFlowOverdueProjections');for(const id of ['ltsBankEvidence','v274ReceivedPosition']){const n=new Node('div',this);n.id=id;this.nodes.set(id,n);}}
}
const doc=new Doc(),micro=[],timers=[];let previousCalls=0;
const fixture={from:'2026-09-20',to:'2026-09-20',current_future:{current_anchor_date:'2026-09-20',days:[{date:'2026-09-20',fix86_columns:{saldo_final:1234.56}}]},observed_bank_movements:{pending_projections:[{source:'current_event',source_ref:'iptu',event_date:'2026-09-19',account:'Itaú',description:'IPTU fixture',signed_amount:-150.25}]}};
const original=JSON.stringify(fixture);
function deepFreeze(x){Object.freeze(x);for(const v of Object.values(x))if(v&&typeof v==='object')deepFreeze(v)}deepFreeze(fixture);
class TestDate extends Date {constructor(...args){super(...(args.length?args:['2026-09-20T04:00:00Z']))}static now(){return Date.parse('2026-09-20T04:00:00Z')}}
const frame={document:doc,Date:TestDate,Intl,Map,Set,Promise,queueMicrotask:fn=>micro.push(fn),V:'Fluxo Diário',ACC:'Consolidado',FLOWFROM:'2026-09-20',FLOWTO:'2026-09-20',FLOWLOADING:false,FLOWQ:fixture,
 __LTS_V228_FLOW:{installed:true},__LTS_V235_HISTORY:{},__LTS_V257_UI_STATE:{installed:true},
 render:function(){previousCalls++;doc.reset();return 'render-preserved'},loadError:false,
 loadFlowRange:function(){return this.loadError?Promise.reject(new Error('fixture-failure')):Promise.resolve('loaded');}};
frame.window=frame;vm.createContext(frame);doc.context=frame;doc.reset();
const shell={contentWindow:frame,contentDocument:doc,events:{},addEventListener:(name,fn)=>shell.events[name]=fn};
const outer={document:{getElementById:()=>shell},setTimeout:(fn,ms)=>{timers.push({fn,ms})}};outer.window=outer;vm.createContext(outer);
const flush=()=>{let n=0;while(micro.length){assert(++n<30,'no microtask loop');micro.shift()()}};
const panel=()=>doc.getElementById('ltsFlowOverdueProjections');
(async()=>{
 vm.runInContext(source,outer);flush();
 check('Outer asset installs into correct frame',frame.__LTS_FLOW_OVERDUE_PROJECTIONS.installed&&!!panel());
 check('Notice contains original unpaid forecast',panel().innerHTML.includes('19/09/2026')&&panel().innerHTML.includes('baixa ainda não vinculada no LTS'));
 const once=frame.render;vm.runInContext(source,outer);flush();check('Repeated install preserves one render wrapper',frame.render===once);
 check('One stylesheet',doc.head.children.filter(n=>n.id==='ltsOverdueForecastStyle').length===1);
 check('Render return value preserved',frame.render()==='render-preserved');flush();check('Panel restored after existing render replaces DOM',!!panel());
 // Native <details> changes .open synchronously; its toggle event can arrive later.
 const clickBeforeToggle=panel().detail;clickBeforeToggle.open=true;frame.render();flush();
 check('Immediate render preserves open before delayed toggle event',panel().detail.open);
 const oldBeforeLoading=panel().detail;frame.FLOWLOADING=true;frame.render();flush();
 oldBeforeLoading.open=false;oldBeforeLoading.listeners.toggle();
 frame.FLOWLOADING=false;frame.render();flush();
 check('Detached delayed toggle cannot erase expansion during loading',panel().detail.open);
 const oldBeforeBank=panel().detail;frame.ACC='C6';frame.render();flush();
 oldBeforeBank.open=false;oldBeforeBank.listeners.toggle();
 frame.ACC='Consolidado';frame.render();flush();
 check('Detached delayed toggle cannot erase expansion across bank switch',panel().detail.open);
 panel().detail.open=false;frame.render();flush();
 check('Immediate render also preserves closing before delayed toggle',panel().detail.open===false);
 const replacedDetails=panel().detail;panel().detail.open=true;frame.FLOWQ={...fixture,observed_bank_movements:{pending_projections:[{...fixture.observed_bank_movements.pending_projections[0],description:'Changed fixture label'}]}};
 // A loader completion can repaint the same section instead of replacing its parent.
 await frame.loadFlowRange();flush();const sameSection=panel();
 check('Loader repaint captures open state before replacing details',sameSection.detail.open&&sameSection.detail!==replacedDetails);
 replacedDetails.open=false;replacedDetails.listeners.toggle();
 frame.FLOWLOADING=true;frame.render();flush();frame.FLOWLOADING=false;frame.render();flush();
 check('Replaced details toggle cannot overwrite current expansion',panel().detail.open);
 frame.FLOWQ=fixture;
 panel().detail.open=true;panel().detail.listeners.toggle();frame.render();flush();check('Expansion preserved after complete rerender',panel().detail.open);
 const chain=frame.render;frame.render=function(){const result=chain();if(panel())panel().remove();return result};frame.render();check('Late layer can replace synchronous DOM',!panel());flush();check('One settling microtask restores after later layer',!!panel());
 frame.ACC='C6';frame.render();flush();check('Bank switch filters without totals',panel().innerHTML.includes('Nenhuma previsão vencida nesta lista recebida para C6'));
 frame.ACC='Itaú';frame.render();flush();check('Bank switch shows relevant obligation',panel().innerHTML.includes('IPTU fixture'));
 frame.V='Dashboard';frame.render();flush();check('Leaving Flow removes notice',!panel());
 frame.V='Fluxo Diário';frame.FLOWLOADING=true;frame.render();flush();check('Delayed data shows loading without stale amount',panel().innerHTML.includes('Conferindo')&&!panel().innerHTML.includes('150,25'));
 frame.FLOWLOADING=false;frame.render();flush();check('Late data renders with already installed wrappers',panel().innerHTML.includes('150,25'));
 check('Existing async loader result preserved',await frame.loadFlowRange()==='loaded');flush();
 frame.loadError=true;let error;try{await frame.loadFlowRange()}catch(e){error=e}flush();check('Existing loader errors propagate',error&&error.message==='fixture-failure');
 check('Source financial payload not mutated',JSON.stringify(fixture)===original);
 check('No installation polling after readiness',timers.length===0);
 check('Renders finish without self-triggered loops',micro.length===0&&previousCalls<40);
 // Simulate a late wrapper installation, without sleeping or launching a browser.
 const delayedDoc=new Doc(),delayedFrame={...frame,document:delayedDoc,__LTS_V235_HISTORY:null,__LTS_FLOW_OVERDUE_PROJECTIONS:null,render:function(){delayedDoc.reset();return 'new-frame'}};
 delayedFrame.window=delayedFrame;vm.createContext(delayedFrame);delayedDoc.context=delayedFrame;delayedDoc.reset();shell.contentWindow=delayedFrame;shell.contentDocument=delayedDoc;
 shell.events.load();let elapsed=0;while(elapsed<30000){const timer=timers.shift();assert(timer);elapsed+=timer.ms;timer.fn();}
 check('Installation still waits after 30s without unbounded interval',timers.length===1&&!delayedFrame.__LTS_FLOW_OVERDUE_PROJECTIONS);
 delayedFrame.__LTS_V235_HISTORY={};timers.shift().fn();flush();check('Wrappers arriving after 30s install successfully',delayedFrame.__LTS_FLOW_OVERDUE_PROJECTIONS.installed);
 shell.contentWindow={};shell.events.load();let bounded=0;while(timers.length){assert(++bounded<250);timers.shift().fn()}
 check('Installation timeout is traceable and bounded',outer.__LTS_V275_OVERDUE_INSTALL.status==='timed_out'&&outer.__LTS_V275_OVERDUE_INSTALL.attempts===240);
 check('Timeout does not claim zero pending obligations',!('pending_count' in outer.__LTS_V275_OVERDUE_INSTALL));
 const result={status:'PASS',count:checks.length,checks,limits:'Real candidate runtime in VM with a small DOM shim, not a rendered browser or all legacy assets. Full app.html browser gate remains required.'};fs.writeFileSync('qa/v278-overdue-runtime-results.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
})().catch(error=>{console.error(error);process.exitCode=1});
