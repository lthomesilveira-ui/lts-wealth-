(()=>{'use strict';
const BUILD='LTS v1.21';
const CORE_CONTRACT=['lts_browser_liquidity_movement_options_v1','lts_browser_preview_liquidity_movement_v1','lts_browser_apply_liquidity_movement_v1'];
const FLOW_CONTRACT=['lts_browser_flow_v8','v150-validated-flow-plus-v157-liquidity-v1','historical-closed-date-label-close-only-v1','projection-edit-postpone-duplicate-split-cancel-v1','Histórico / período','Histórico / movimentos','Editar','Postergar','Duplicar','Dividir / substituir','inline-card-settlement-v150','RSUs futuras','Cash Awards futuros'];
const PRODUCT_CONTRACT=['Dinheiro em contas','Contas + curto prazo','RSUs vested','FGTS','Despesas (mês)','Quanto você gasta — e para quem é cada gasto.','Quanto você tem, quanto deve e quanto é seu.','Conferência de fatura, não análise de gasto.'];
const CAPABILITY_CONTRACT=['Planejamento','Entradas & compromissos','Recorrências','Simulações','Conciliação','Relatórios','Relatório executivo','evidence-backed-executive-report-v1','Backup & restauração','Configurações & integrações','Financiamentos','Documentos'];
const REVIEWED_INPUT_CONTRACT=['Lançamento por texto','review-before-explicit-apply-v1','lts_browser_apply_reviewed_input_v1'];
const UPDATES_CONTRACT=['classification-first-guided-document-intake-v1','lts_browser_register_document_v2','lts-documents','no-auto-post'];
const DOCUMENT_REVIEW_CONTRACT=['v149-evidence-review-readonly-canonical-v1','lts_browser_document_review_queue_v1','read-only','no-financial-writer'];
const DASHBOARD_DENSITY_CONTRACT=['approved-1312x1199-single-screen-v1'];
const PLANNING_DECISION_CONTRACT=['v151-first-negative-management-separation-v1'];
const PRODUCT_LANGUAGE_CONTRACT='user-facing-product-language-v1';
const UX_CLOSURE_CONTRACT='safe-errors-accessible-controls-readable-mobile-v1';
let modulesPromise=null;
function load(src,id){return new Promise((resolve,reject)=>{if(document.getElementById(id)){resolve();return}const s=document.createElement('script');s.id=id;s.src=src;s.async=false;s.onload=resolve;s.onerror=()=>reject(new Error('Falha ao carregar '+src));document.body.appendChild(s)})}
function canonicalReady(){return window.__LTS_CANONICAL_STATUS?.ready===true}
function mark(extra){const presentationLoaded=!!document.getElementById('canonicalPresentationV157'),capabilitiesLoaded=!!document.getElementById('canonicalCapabilitiesV161'),reviewedInputLoaded=!!document.getElementById('canonicalReviewedInputV112');window.__LTS_CANONICAL_RECOVERY_STATUS={ready:true,build:BUILD,core_contract:CORE_CONTRACT.length,flow_contract:FLOW_CONTRACT.length,product_contract:PRODUCT_CONTRACT.length,capability_contract:CAPABILITY_CONTRACT.length,reviewed_input_contract:REVIEWED_INPUT_CONTRACT.length,updates_contract:UPDATES_CONTRACT.length,document_review_contract:DOCUMENT_REVIEW_CONTRACT.length,dashboard_density_contract:DASHBOARD_DENSITY_CONTRACT.length,planning_decision_contract:PLANNING_DECISION_CONTRACT.length,product_language_contract:PRODUCT_LANGUAGE_CONTRACT,ux_closure_contract:UX_CLOSURE_CONTRACT,flow_loaded:!!document.getElementById('canonicalFlowV157'),product_loaded:!!document.getElementById('canonicalProductV157'),presentation_loaded:presentationLoaded,polish_loaded:presentationLoaded,capabilities_loaded:capabilitiesLoaded,reviewed_input_loaded:reviewedInputLoaded,...(extra||{})}}
function ensureModules(){
  if(modulesPromise)return modulesPromise;
  modulesPromise=Promise.all([
    load('canonical-product-v157.js?v=20260908-ux19','canonicalProductV157'),
    load('canonical-flow-v157.js?v=20260908-flow20','canonicalFlowV157')
  ]).then(()=>load('canonical-presentation-v157.js?v=20260908-ux19','canonicalPresentationV157')).then(()=>load('canonical-capabilities-v161.js?v=20260909-reports21','canonicalCapabilitiesV161')).then(()=>load('canonical-reviewed-input-v112.js?v=20260908-ux19','canonicalReviewedInputV112')).then(()=>{mark({flow_loaded:true,product_loaded:true,presentation_loaded:true,polish_loaded:true,capabilities_loaded:true,reviewed_input_loaded:true});return true}).catch(e=>{modulesPromise=null;mark({error:String(e?.message||e)});throw e});
  return modulesPromise;
}
function waitReady(tryNo=0){if(canonicalReady())return ensureModules();if(tryNo>=80)return Promise.resolve(false);return new Promise(r=>setTimeout(r,250)).then(()=>waitReady(tryNo+1))}
(async()=>{try{await load('canonical-liquidity-core.js?v=20260908-ux19','canonicalLiquidityCore');mark({flow_loaded:false,product_loaded:false,presentation_loaded:false,polish_loaded:false});waitReady(0).catch(e=>mark({error:String(e?.message||e)}))}catch(e){console.error('LTS module loader',e);window.__LTS_CANONICAL_RECOVERY_STATUS={ready:false,build:BUILD,error:String(e?.message||e)}}})();
})();
