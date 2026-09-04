(()=>{'use strict';
const TEST=new URLSearchParams(location.search).get('runtimeFixture')==='1';
const ROUTES=['Dashboard','Fluxo Diário','Despesas','Patrimônio','Cartões','Atualizações'];
const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ').trim().toLowerCase();
const finite=v=>{if(v===null||v===undefined||v==='')return null;const n=Number(v);return Number.isFinite(n)?n:null};
const money=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:2}).format(Number(v));
const frame=document.getElementById('routeFrame'),dash=document.getElementById('dashboard');
let requested='Dashboard',observerBusy=false;
function deep(){
  try{
    let d=frame?.contentDocument,w=frame?.contentWindow,last=d&&w?{d,w}:null;
    for(let i=0;i<32&&d&&w;i++){
      const nf=d.getElementById('shell')||d.getElementById('routeFrame')||d.querySelector('iframe#app')||d.querySelector('iframe');
      if(!nf)break;
      try{if(!nf.contentDocument||!nf.contentWindow)break;d=nf.contentDocument;w=nf.contentWindow;last={d,w}}catch(e){break}
    }
    return last;
  }catch(e){return null}
}
function nativeClick(dest,z){
  if(!z?.d)return false;const target=norm(dest);
  const nodes=[...z.d.querySelectorAll('button,a,[role="button"],[data-view],[data-route]')];
  const hit=nodes.find(x=>norm(x.textContent)===target)||nodes.find(x=>norm(x.getAttribute('data-view'))===target)||nodes.find(x=>norm(x.getAttribute('data-route'))===target);
  if(!hit)return false;try{hit.click();return true}catch(e){return false}
}
function forceRoute(dest,z){
  if(!z?.w)return false;
  try{z.w.V=dest;z.w.renderNav?.();z.w.render?.();z.w.__LTS_V151_AFTER_RENDER?.();z.w.__LTS_V151_LEDGER_SEARCH_AFTER_RENDER?.();return String(z.w.V||'')===dest}catch(e){return false}
}
function show(dest){
  requested=dest;document.querySelectorAll('[data-route]').forEach(b=>b.classList.toggle('active',b.dataset.route===dest));
  if(dest==='Dashboard'){if(dash)dash.style.display='block';if(frame)frame.style.display='none';window.__LTS_V155_ROUTE_STATE={dest,ok:true,via:'outer'};return true}
  if(dash)dash.style.display='none';if(frame)frame.style.display='block';return false;
}
function navigate(dest,attempt=0){
  if(!ROUTES.includes(dest))return;if(show(dest))return;
  const z=deep(),clicked=nativeClick(dest,z),forced=forceRoute(dest,z);
  if((clicked||forced)&&String(z?.w?.V||'')===dest){window.__LTS_V155_ROUTE_STATE={dest,ok:true,attempt,via:clicked?'click':'force'};return}
  if(attempt<28)setTimeout(()=>navigate(dest,attempt+1),Math.min(80+attempt*30,450));else window.__LTS_V155_ROUTE_STATE={dest,ok:false,attempt,via:'failed'};
}
function installNavigation(){
  if(document.__ltsV155Nav)return;document.__ltsV155Nav=true;
  document.addEventListener('click',e=>{const b=e.target.closest?.('[data-route],[data-route2]');if(!b)return;const dest=b.dataset.route||b.dataset.route2;if(!ROUTES.includes(dest))return;e.preventDefault();e.stopImmediatePropagation();navigate(dest)},true);
  frame?.addEventListener('load',()=>{if(requested!=='Dashboard')setTimeout(()=>navigate(requested),120)});
}
function recoverThrough(l){
  const bank=finite(l?.bank_cash),d0=finite(l?.d0),d3=finite(l?.d3_vested),explicit=finite(l?.through_d3),parts=[bank,d0,d3].filter(v=>v!=null),derived=parts.length?parts.reduce((a,b)=>a+b,0):null;
  return {value:(explicit==null||explicit===0)&&derived!=null&&derived!==0?derived:explicit,source:(explicit==null||explicit===0)&&derived!=null&&derived!==0?'components':'explicit',derived};
}
function normalizeSource(){
  if(TEST)return false;const z=deep();if(!z?.w)return false;const D=z.w.D||{},c=D.dashboard_cockpit||{},l=c.liquidity||{},work=c.work||{};let changed=false;
  const recovered=recoverThrough(l);if(recovered.source==='components'&&finite(l.through_d3)!==recovered.value){l.through_d3=recovered.value;changed=true}
  if(c.expenses?.current_month&&c.expenses.current_month.spend===null){c.expenses.current_month.spend=undefined;changed=true}
  const topActions=Array.isArray(work.top_actions)?work.top_actions.length:0,raw=finite(work.actionable_count);if(topActions>0&&(raw==null||raw===0)){work.actionable_count=topActions;changed=true}
  window.__LTS_V155_SOURCE_STATE={ok:true,changed,through_d3:finite(l.through_d3),expense_missing:c.expenses?.current_month?.spend===undefined,actions:finite(work.actionable_count)};return changed;
}
function fixtureModel(){return {through:40000,throughSource:'components',actions:2,updates:23,expenses:null,previous:62000,net:3590703,cards:33328.6}}
function model(){
  if(TEST)return fixtureModel();normalizeSource();const z=deep();if(!z?.w)return null;const D=z.w.D||{},c=D.dashboard_cockpit||{},l=c.liquidity||{},work=c.work||{},r=recoverThrough(l);
  const topActions=Array.isArray(work.top_actions)?work.top_actions.length:null,rawActions=finite(work.actionable_count),actions=topActions!=null&&topActions>0&&(rawActions==null||rawActions===0)?topActions:rawActions,updates=Array.isArray(D.updates?.items)?D.updates.items.length:0;
  return {through:r.value,throughSource:r.source,actions,updates,expenses:finite(c.expenses?.current_month?.spend),previous:finite(c.expenses?.previous_month?.spend),net:finite(c.wealth?.net_worth_central??D.wealth_executive?.summary?.net_worth_central),cards:finite(c.cards?.open_cycles_total??D.card_operating?.open_cycles_total)};
}
function sameText(el,text){if(!el)return;const t=String(text);if(el.textContent!==t)el.textContent=t}
function kpi(label){return [...document.querySelectorAll('.kpi')].find(x=>norm(x.querySelector('label')?.textContent)===norm(label))||null}
function setKpi(label,value,meta){const el=kpi(label);if(!el)return false;sameText(el.querySelector('strong'),value);if(meta!=null)sameText(el.querySelector('.meta'),meta);return true}
function patchData(){
  if(observerBusy)return;observerBusy=true;
  try{
    const m=model();if(!m)return;
    setKpi('Disponível D+3',money(m.through),m.throughSource==='components'?'liquidez real · contas + D0 + RSU D+3':'liquidez realizável');
    setKpi('Despesas (mês)',m.expenses==null?'—':money(m.expenses),m.expenses==null?'dado mensal não carregado · não assumir R$ 0,00':(m.previous?`${((m.expenses-m.previous)/Math.abs(m.previous)*100).toFixed(1).replace('.',',')}% vs. mês anterior`:'comparação indisponível'));
    setKpi('Ações pendentes',m.actions==null?'—':String(m.actions),`${m.updates} atualizações em fila`);
    if(m.net==null)setKpi('Patrimônio Líquido','—','posição consolidada indisponível');if(m.cards==null)setKpi('Cartões em aberto','—','posição atual indisponível');
    const bankTotal=document.querySelector('.bank-total b');if(bankTotal)sameText(bankTotal,money(m.through));
    const hero=[...document.querySelectorAll('.panel-title h2')].find(x=>norm(x.textContent)==='despesas do mes')?.closest('.panel')?.querySelector('.expense-hero');if(hero&&m.expenses==null){sameText(hero.querySelector('strong'),'—');sameText(hero.querySelector('span'),'dado mensal não carregado')}
    const updatesPanel=[...document.querySelectorAll('.panel-title h2')].find(x=>norm(x.textContent)==='atualizacoes pendentes')?.closest('.panel');const firstAction=updatesPanel?.querySelector('.update-row b');if(firstAction)sameText(firstAction,m.actions==null?'Ações priorizadas indisponíveis':`${m.actions} ações priorizadas`);
    window.__LTS_V155_DATA_STATE={ok:true,...m};
  }finally{observerBusy=false}
}
function installDataGuard(){const obs=new MutationObserver(()=>requestAnimationFrame(patchData));if(dash)obs.observe(dash,{childList:true,subtree:true});setInterval(()=>{normalizeSource();patchData()},500);patchData()}
function brand(){document.title='LTS Wealth · Homologação v155';const b=document.querySelector('.candidate-badge');if(b)b.textContent='CANDIDATA v155 · dados + navegação'}
installNavigation();installDataGuard();brand();
window.__LTS_V155_STATUS={version:'v155-real-data-navigation-fix-v4',public_index_changed:false,authenticated_e2e_claimed:false,all_route_retry:true,false_zero_guard:true,d3_component_recovery:true,source_normalization:true,direct_visual_shell:true};
})();
