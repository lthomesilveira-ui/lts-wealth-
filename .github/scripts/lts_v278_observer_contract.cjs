'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve('releases/v278'),baseline=path.resolve('releases/v277');
const names=['lts-v183-v168-feedback-safe.js','lts-v170-v169-review.js'];
const read=(file,old=false)=>fs.readFileSync(path.join(old?baseline:root,file),'utf8');
const stamp168=read(names[0]).match(/    function stamp\(\)\{[^\n]+/)[0];
const decorate170=read(names[1]).split('    function decorateFlow(){')[1].split('    function bind()')[0];
const observer170=read(names[1]).split('\n').find(line=>line.includes('const observer=new MutationObserver'));
const checks=[];function check(name,fn){try{fn();checks.push({name,pass:true})}catch(e){checks.push({name,pass:false,error:e.message})}}
function harness({route='Fluxo Diário',headers=true,controls=true,note=true,owner=false}={}){
 const h={writes:0,frames:[],observers:[],route};
 class Element{
  constructor(html=''){this.html=html;this.children=[];this.dataset={};}
  get textContent(){return this.html.replace(/<[^>]+>/g,'')}
  set textContent(v){this.html=String(v);h.writes++}
  get innerHTML(){return this.html}
  set innerHTML(v){this.html=String(v);h.writes++}
  insertAdjacentHTML(_,html){h.note=new Element(html.replace(/^<div[^>]*>|<\/div>$/g,''));h.writes++}
 }
 h.Element=Element;h.brand=new Element('<b>V169</b> · Homologação');h.scope=new Element('old');h.note=note?new Element('old note'):null;h.controls=controls?new Element():null;
 h.header=headers?new Element():null;if(h.header)h.header.children=Array.from({length:11},(_,i)=>new Element('untouched financial column '+i));
 const frozen={current_future:{days:[{date:'2031-02-14',Itaú:{balance:-123.45},C6:{balance:0}}],events:[{signed_amount:13.37}]}};function freeze(x){Object.freeze(x);for(const v of Object.values(x))if(v&&typeof v==='object')freeze(v)}freeze(frozen);h.financial=frozen;
 const doc={body:{},querySelectorAll(sel){return sel==='.brand small'?[h.brand]:sel==='.fx87-cons.fx87-head'&&h.header?[h.header]:[]},querySelector(sel){return sel==='.v168-history-note'?h.note:sel==='.flow-sticky-controls'?h.controls:null}};
 h.c={document:doc,V:route,FLOWQ:frozen,window:{parent:{__LTS_TOP_CANDIDATE_VERSION:'v277',document:{getElementById:()=>h.scope}},__LTS_V169_V168_FEEDBACK:owner?{installed:true}:undefined},stamp(){h.scope.dataset.route=h.c.V},requestAnimationFrame(fn){h.frames.push(fn);return h.frames.length},MutationObserver:class{constructor(fn){this.fn=fn;h.observers.push(this)}observe(node,options){this.node=node;this.options=options}}};
 vm.createContext(h.c);h.run=code=>vm.runInContext(code,h.c);h.flush=()=>{const q=h.frames.splice(0);for(const fn of q)fn()};return h;
}
check('V168 respects installed V169 despite newer outer release marker',()=>{const h=harness({owner:true});h.run(stamp168+';stamp()');assert.equal(h.writes,0);assert.equal(h.brand.textContent,'V169 · Homologação')});
check('V168 standalone still stamps brand and route, then becomes idempotent',()=>{const h=harness();h.run(stamp168+';stamp()');assert.equal(h.brand.textContent,'V168 · Homologação');assert.equal(h.scope.textContent,'V168 · Fluxo de caixa · Homologação');const n=h.writes;h.run('stamp();stamp()');assert.equal(h.writes,n);h.c.V='Patrimônio';h.run('stamp()');assert.equal(h.scope.textContent,'V168 · Patrimônio · Homologação')});
check('Legacy v169 outer marker remains respected before runtime ownership',()=>{const h=harness();h.c.window.parent.__LTS_TOP_CANDIDATE_VERSION='v169-v168-feedback-closure';h.run(stamp168+';stamp()');assert.equal(h.writes,0)});
check('A noninstalled V169 marker does not disable standalone V168',()=>{const h=harness();h.c.window.__LTS_V169_V168_FEEDBACK={installed:false};h.run(stamp168+';stamp()');assert.equal(h.brand.textContent,'V168 · Homologação')});
const install=h=>h.run('function decorateFlow(){'+decorate170+'\n'+observer170);
check('V170 changes only two intended headers and the note',()=>{const h=harness(),before=h.header.children.map(x=>x.innerHTML);install(h);h.run('decorateFlow()');for(let i=0;i<11;i++)if(![7,8].includes(i))assert.equal(h.header.children[i].innerHTML,before[i]);assert.equal(h.header.children[7].textContent,'Morgan disponível');assert.equal(h.header.children[8].textContent,'Saldo c/ Morgan');assert.match(h.note.innerHTML,/Histórico auditável/)});
check('Same V170 note and headers cause no repeated DOM writes',()=>{const h=harness();install(h);h.run('decorateFlow()');const n=h.writes;h.run('decorateFlow();decorateFlow();decorateFlow()');assert.equal(h.writes,n)});
check('Replacement note and header nodes are decorated again',()=>{const h=harness();install(h);h.run('decorateFlow()');const expected=h.note.innerHTML;h.note=new h.Element('new node');h.header.children=Array.from({length:11},()=>new h.Element('replacement'));h.run('decorateFlow()');assert.equal(h.note.innerHTML,expected);assert.equal(h.header.children[7].textContent,'Morgan disponível')});
check('Missing note is recreated and then becomes stable',()=>{const h=harness({note:false});install(h);h.run('decorateFlow()');assert(h.note);const n=h.writes;h.run('decorateFlow()');assert.equal(h.writes,n)});
check('Missing controls and short/absent headers do not throw',()=>{const h=harness({note:false,controls:false,headers:false});install(h);h.run('decorateFlow()');assert.equal(h.writes,0);h.header=new h.Element();h.header.children=[new h.Element('short')];h.run('decorateFlow()');assert.equal(h.writes,0)});
check('Outside Flow the decorator leaves DOM untouched',()=>{const h=harness({route:'Dashboard'});install(h);h.run('decorateFlow()');assert.equal(h.writes,0)});
check('Mutation observer remains attached to body childList/subtree',()=>{const h=harness();install(h);assert.equal(h.observers.length,1);assert.equal(h.observers[0].node,h.c.document.body);assert.deepEqual(JSON.parse(JSON.stringify(h.observers[0].options)),{childList:true,subtree:true})});
check('A mutation burst creates one pending frame and later bursts still work',()=>{const h=harness();install(h);for(let i=0;i<100;i++)h.observers[0].fn();assert.equal(h.frames.length,1);h.flush();h.observers[0].fn();assert.equal(h.frames.length,1);const n=h.writes;h.flush();assert.equal(h.writes,n)});
check('Queued frame uses current route rather than modifying a departed Flow',()=>{const h=harness();install(h);h.observers[0].fn();h.c.V='Dashboard';h.flush();assert.equal(h.writes,0);h.c.V='Fluxo Diário';h.observers[0].fn();h.flush();assert(h.writes>0)});
check('Financial payload remains frozen and byte-identical',()=>{const h=harness(),before=JSON.stringify(h.financial);install(h);h.run('decorateFlow()');for(let i=0;i<20;i++)h.observers[0].fn();h.flush();assert.equal(JSON.stringify(h.financial),before)});
check('All changes stay in the three approved UI functions and observer declaration',()=>{for(const name of names){const normalize=s=>s.split('\n').map(line=>{if(name===names[0]&&/^    function stamp\(|^  function install\(/.test(line))return '__APPROVED_UI_FUNCTION__';if(name===names[1]&&(line.includes("if(V!=='Fluxo Diário')return;document.querySelectorAll('.fx87-cons.fx87-head')")||line.includes('const observer=new MutationObserver')))return '__APPROVED_DECORATOR__';return line}).join('\n');assert.equal(normalize(read(name)),normalize(read(name,true)),name)}});

const install168=read(names[0]).split('\n').find(line=>line.startsWith('  function install(){'));
function installHarness({owner=false,ready166=true,ready168=false,top='v277'}={}){
 const h=harness({owner});h.appended=[];h.gate={hidden:false};
 const w={__LTS_V169_V168_FEEDBACK:{installed:owner},__LTS_V166_FEEDBACK:{installed:ready166},__LTS_V168_COMPLETE_REVIEW:{installed:ready168}};
 const d={querySelectorAll:()=>[h.brand],getElementById:()=>null,createElement:()=>({}),head:{appendChild(node){h.appended.push(node);w.__LTS_V168_COMPLETE_REVIEW.installed=true}}};
 Object.assign(h.c,{frame:()=>({w,d}),scope:h.scope,gate:h.gate,runtime:function runtime(){}});h.c.window.__LTS_TOP_CANDIDATE_VERSION=top;h.w=w;h.run(install168);return h;
}
check('Outer V168 installer respects V169 ownership without skipping runtime installation',()=>{const h=installHarness({owner:true});assert.equal(h.run('install()'),true);assert.equal(h.writes,0);assert.equal(h.appended.length,1);assert.equal(h.appended[0].id,'lts-v168-runtime');assert.equal(h.gate.hidden,true)});
check('Outer standalone V168 installer stamp is idempotent across retries',()=>{const h=installHarness({ready168:true});h.run('install()');assert.equal(h.brand.textContent,'V168 · Homologação');assert.equal(h.scope.textContent,'V168 · Homologação');const n=h.writes;h.run('install();install()');assert.equal(h.writes,n);assert.equal(h.appended.length,0)});
check('Outer V168 installer still waits for V166 and recovers on later retry',()=>{const h=installHarness({owner:true,ready166:false});assert.equal(h.run('install()'),false);assert.equal(h.appended.length,0);assert.equal(h.gate.hidden,false);h.w.__LTS_V166_FEEDBACK.installed=true;assert.equal(h.run('install()'),true);assert.equal(h.appended.length,1)});
check('Late V169 ownership prevents further V168 writes on later install bursts',()=>{const h=installHarness({ready168:true});h.run('install()');h.w.__LTS_V169_V168_FEEDBACK.installed=true;h.brand.innerHTML='<b>V169</b> · Homologação';h.scope.textContent='V169 · route';const n=h.writes;h.run('install()');assert.equal(h.writes,n);assert.equal(h.scope.textContent,'V169 · route')});

const out={passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass),checks,hashes:Object.fromEntries(names.map(n=>[n,crypto.createHash('sha256').update(read(n)).digest('hex')])),scope:'Independent minimal DOM and actual candidate function/observer bodies; no browser, SQL or network; full-stack parity still required'};
fs.mkdirSync('qa',{recursive:true});fs.writeFileSync('qa/v278-independent-observer-results.json',JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify(out,null,2));if(out.failed.length)process.exitCode=1;
