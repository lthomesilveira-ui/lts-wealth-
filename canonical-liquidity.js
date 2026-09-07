(()=>{'use strict';
const BUILD='CANONICAL v1.1 · Recovery V150+';
const CORE_CONTRACT=['lts_browser_liquidity_movement_options_v1','lts_browser_preview_liquidity_movement_v1','lts_browser_apply_liquidity_movement_v1'];
const FLOW_CONTRACT=['lts_browser_flow_v6','WIP35-v150','Últimos 5 dias','Próximos 90 dias','Histórico / movimentos'];
function load(src,id){return new Promise((resolve,reject)=>{if(document.getElementById(id)){resolve();return}const s=document.createElement('script');s.id=id;s.src=src;s.async=false;s.onload=resolve;s.onerror=()=>reject(new Error('Falha ao carregar '+src));document.body.appendChild(s)})}
(async()=>{try{await load('canonical-liquidity-core.js?v=20260907-recovery-v150plus-1','canonicalLiquidityCore');await load('canonical-flow-v150.js?v=20260907-recovery-v150plus-1','canonicalFlowV150');window.__LTS_CANONICAL_RECOVERY_STATUS={ready:true,build:BUILD,core_contract:CORE_CONTRACT.length,flow_contract:FLOW_CONTRACT.length}}catch(e){console.error('LTS canonical recovery loader',e);window.__LTS_CANONICAL_RECOVERY_STATUS={ready:false,build:BUILD,error:String(e?.message||e)}}})();
})();
