(()=>{'use strict';
const BUILD='LTS v1.10';
const CORE_CONTRACT=['lts_browser_liquidity_movement_options_v1','lts_browser_preview_liquidity_movement_v1','lts_browser_apply_liquidity_movement_v1'];
const FLOW_CONTRACT=['lts_browser_flow_v8','v150-validated-flow-plus-v157-liquidity-v1','Histórico / período','Movimentos do dia','Dividir / substituir','inline-card-settlement-v150','RSUs futuras','Cash Awards futuros'];
const PRODUCT_CONTRACT=['Dinheiro em contas','Contas + curto prazo','RSUs vested','FGTS','Despesas (mês)','Quanto você gasta — e para quem é cada gasto.','Quanto você tem, quanto deve e quanto é seu.','Conferência de fatura, não análise de gasto.'];
const CAPABILITY_CONTRACT=['Planejamento','Entradas & compromissos','Recorrências','Simulações','Conciliação','Relatórios','Backup & restauração','Configurações & integrações','Financiamentos','Documentos'];
let modulesPromise=null;
function load(src,id){return new Promise((resolve,reject)=>{if(document.getElementById(id)){resolve();return}const s=document.createElement('script');s.id=id;s.src=src;s.async=false;s.onload=resolve;s.onerror=()=>reject(new Error('Falha ao carregar '+src));document.body.appendChild(s)})}
function canonicalReady(){return window.__LTS_CANONICAL_STATUS?.ready===true}
function mark(extra){const presentationLoaded=!!document.getElementById('canonicalPresentationV157'),capabilitiesLoaded=!!document.getElementById('canonicalCapabilitiesV161');window.__LTS_CANONICAL_RECOVERY_STATUS={ready:true,build:BUILD,core_contract:CORE_CONTRACT.length,flow_contract:FLOW_CONTRACT.length,product_contract:PRODUCT_CONTRACT.length,capability_contract:CAPABILITY_CONTRACT.length,flow_loaded:!!document.getElementById('canonicalFlowV157'),product_loaded:!!document.getElementById('canonicalProductV157'),presentation_loaded:presentationLoaded,polish_loaded:presentationLoaded,capabilities_loaded:capabilitiesLoaded,...(extra||{})}}
function ensureModules(){
  if(modulesPromise)return modulesPromise;
  modulesPromise=Promise.all([
    load('canonical-product-v157.js?v=20260908-expenses8','canonicalProductV157'),
    load('canonical-flow-v157.js?v=20260908-flow-parity9','canonicalFlowV157')
  ]).then(()=>load('canonical-presentation-v157.js?v=20260908-session6','canonicalPresentationV157')).then(()=>load('canonical-capabilities-v161.js?v=20260908-continuity7','canonicalCapabilitiesV161')).then(()=>{mark({flow_loaded:true,product_loaded:true,presentation_loaded:true,polish_loaded:true,capabilities_loaded:true});return true}).catch(e=>{modulesPromise=null;mark({error:String(e?.message||e)});throw e});
  return modulesPromise;
}
function waitReady(tryNo=0){if(canonicalReady())return ensureModules();if(tryNo>=80)return Promise.resolve(false);return new Promise(r=>setTimeout(r,250)).then(()=>waitReady(tryNo+1))}
(async()=>{try{await load('canonical-liquidity-core.js?v=20260907-v157plus-product-3','canonicalLiquidityCore');mark({flow_loaded:false,product_loaded:false,presentation_loaded:false,polish_loaded:false});waitReady(0).catch(e=>mark({error:String(e?.message||e)}))}catch(e){console.error('LTS module loader',e);window.__LTS_CANONICAL_RECOVERY_STATUS={ready:false,build:BUILD,error:String(e?.message||e)}}})();
})();
