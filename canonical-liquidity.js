(()=>{'use strict';
const BUILD='CANONICAL v1.2 · Recovery V150+ · Mobile RSU';
const CORE_CONTRACT=['lts_browser_liquidity_movement_options_v1','lts_browser_preview_liquidity_movement_v1','lts_browser_apply_liquidity_movement_v1'];
const FLOW_CONTRACT=['lts_browser_flow_v6','WIP35-v150','Últimos 5 dias','Próximos 90 dias','Histórico / movimentos'];
let flowPromise=null;
function load(src,id){return new Promise((resolve,reject)=>{if(document.getElementById(id)){resolve();return}const s=document.createElement('script');s.id=id;s.src=src;s.async=false;s.onload=resolve;s.onerror=()=>reject(new Error('Falha ao carregar '+src));document.body.appendChild(s)})}
function canonicalReady(){return window.__LTS_CANONICAL_STATUS?.ready===true}
function mark(extra){window.__LTS_CANONICAL_RECOVERY_STATUS={ready:true,build:BUILD,core_contract:CORE_CONTRACT.length,flow_contract:FLOW_CONTRACT.length,flow_loaded:!!document.getElementById('canonicalFlowV150'),...(extra||{})}}
function normalizeFlowPayload(data){
  const flow=data?.flow||data;
  for(const bucket of ['historical','current_future']){
    const days=Array.isArray(flow?.[bucket]?.days)?flow[bucket].days:[];
    for(const day of days){
      const c=day?.fix86_columns;
      if(!c||typeof c!=='object')continue;
      if(c.saldo_anterior_operacional==null&&c.saldo_anterior!=null)c.saldo_anterior_operacional=c.saldo_anterior;
      if(c.entradas_operacionais==null&&c.entradas!=null)c.entradas_operacionais=c.entradas;
      if(c.saidas_operacionais==null&&c.saidas!=null)c.saidas_operacionais=c.saidas;
      if(c.saldo_final_operacional==null&&c.saldo_final!=null)c.saldo_final_operacional=c.saldo_final;
    }
  }
  return data;
}
function installFlowNormalizer(){
  if(window.__LTS_FLOW_V150_NORMALIZER_INSTALLED)return;
  window.__LTS_FLOW_V150_NORMALIZER_INSTALLED=true;
  window.__LTS_FLOW_V150_NORMALIZE=normalizeFlowPayload;
  const nativeFetch=window.fetch.bind(window);
  window.fetch=async function(input,init){
    const response=await nativeFetch(input,init);
    const url=typeof input==='string'?input:String(input?.url||'');
    if(!url.includes('/rest/v1/rpc/lts_browser_flow_v6')||!response.ok)return response;
    try{
      const data=normalizeFlowPayload(await response.clone().json());
      const headers=new Headers(response.headers);headers.delete('content-length');
      return new Response(JSON.stringify(data),{status:response.status,statusText:response.statusText,headers});
    }catch(_){return response}
  };
}
function ensureFlow(){
  if(flowPromise)return flowPromise;
  installFlowNormalizer();
  flowPromise=load('canonical-flow-v150.js?v=20260907-recovery-v150plus-mobile-rsu-2','canonicalFlowV150').then(()=>{mark({flow_loaded:true});return true}).catch(e=>{flowPromise=null;mark({flow_loaded:false,error:String(e?.message||e)});throw e});
  return flowPromise;
}
function waitReady(tryNo=0){if(canonicalReady())return ensureFlow();if(tryNo>=80)return Promise.resolve(false);return new Promise(r=>setTimeout(r,250)).then(()=>waitReady(tryNo+1))}
document.addEventListener('click',e=>{if(e.target.closest?.('[data-route="Fluxo Diário"]'))setTimeout(()=>{canonicalReady()?ensureFlow().catch(()=>{}):waitReady(0).catch(()=>{})},0)},true);
window.addEventListener('hashchange',()=>{if(decodeURIComponent(location.hash.slice(1))==='Fluxo Diário'){canonicalReady()?ensureFlow().catch(()=>{}):waitReady(0).catch(()=>{})}});
(async()=>{try{await load('canonical-liquidity-core.js?v=20260907-recovery-v150plus-mobile-rsu-2','canonicalLiquidityCore');mark({flow_loaded:false});waitReady(0).catch(e=>mark({flow_loaded:false,error:String(e?.message||e)}))}catch(e){console.error('LTS canonical recovery loader',e);window.__LTS_CANONICAL_RECOVERY_STATUS={ready:false,build:BUILD,error:String(e?.message||e)}}})();
})();
