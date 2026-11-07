/* Presentation only. Existing readers, amounts, controls and handlers are unchanged. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V425_FLOW_OPTIONS)return;
  const previous=render;let lastView=null,queued=false;
  function materialReasons(){
   const reasons=[],p=window.__LTS_V412_PROJECTION,r=window.__LTS_V411_RSU;
   if(p?.status==='error')reasons.push('Projeções não verificadas.');
   else if(p?.model?.series?.some(s=>s.amount===null&&s.usesHistory||s.warnings?.some(w=>['unreconciled_periods','calendar_unavailable'].includes(w))))reasons.push('Há previsões incompletas.');
   if(r?.status==='error')reasons.push('Líquido das ações a conferir.');
   if(document.getElementById('v399-d01-origin')?.textContent.includes('Há um resgate a conferir no Cofrinho.'))reasons.push('Cofrinho a conferir.');
   return reasons;
  }
  function paint(){
   queued=false;
   const entering=lastView!=='Fluxo Diário';lastView=V;
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden'))return;
   const tools=document.querySelector('.v382-tools'),body=tools?.querySelector('.v382-tool-body'),controls=document.querySelector('.flow-sticky-controls');
   if(!body||!controls)return;
   tools.classList.add('v425-options');body.classList.add('v425-options-body');
   if(entering)tools.open=false;
   const summary=tools.querySelector(':scope>summary');summary.setAttribute('aria-label','Opções do Fluxo');
   function move(node,key){
    if(!node)return;
    const existing=body.querySelector('[data-v425-section="'+key+'"]');
    if(existing&&existing!==node)existing.remove();
    node.dataset.v425Section=key;
    if(node.parentElement!==body){if(node.tagName==='DETAILS')node.open=false;body.appendChild(node);}
   }
   move(controls.querySelector('.v225-balance-freshness>.lts-update-details'),'sources');
   move(document.querySelector('[data-v412-policy="flow"]'),'projection');
   move(document.querySelector('[data-v411-flow-policy]'),'rsu');
   move(document.getElementById('v399-d01-origin'),'applications');
   // Empty provenance containers occupy no vertical space. Their material
   // freshness warnings remain outside the options, with original semantics.
   for(const host of controls.querySelectorAll('.v225-balance-freshness'))host.classList.toggle('v425-empty',!host.textContent.trim());
   const reasons=materialReasons(),signature=reasons.join(' ');let notice=document.getElementById('v425-flow-attention');
   if(!signature){notice?.remove();return;}
   if(!notice){notice=document.createElement('div');notice.id='v425-flow-attention';notice.setAttribute('role','status');controls.after(notice);}
   if(notice.dataset.message!==signature){
    notice.dataset.message=signature;const text=document.createElement('span');text.textContent=signature;
    const button=document.createElement('button');button.type='button';button.textContent='Revisar';
    button.onclick=()=>{const t=document.querySelector('.v382-tools');if(!t)return;t.open=true;const target=t.querySelector('.v412-origin');if(target)target.open=true;t.querySelector(':scope>summary')?.focus();};
    notice.replaceChildren(text,button);
   }
  }
  function schedule(){if(!queued){queued=true;queueMicrotask(paint);}}
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  const observer=new MutationObserver(schedule);observer.observe(document.body,{subtree:true,childList:true});
  document.addEventListener('keydown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(event.key==='Escape'&&tools?.open){tools.open=false;tools.querySelector(':scope>summary')?.focus();event.preventDefault();}});
  document.addEventListener('pointerdown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(tools?.open&&!tools.contains(event.target))tools.open=false;});
  const style=document.createElement('style');style.textContent=`
   .v425-options>.v382-tool-body{width:380px;max-width:calc(100vw - 28px);max-height:65vh;max-height:65dvh;overflow:auto;overscroll-behavior:contain;box-sizing:border-box;text-align:left}
   .v425-options-body>[data-v425-section]{border:0!important;border-top:1px solid #e2e8f0!important;border-radius:0!important;margin:10px 0 0!important;padding:10px 0 0!important;min-width:0;max-width:100%;box-sizing:border-box}
   .v425-options-body>details>summary,.v425-options-body .v412-origin>summary{min-height:44px;display:flex;align-items:center;cursor:pointer;font-size:14px;line-height:1.4}
   .v425-options-body .v412-heading>strong{display:none}
   .v425-options-body .v412-heading{display:block}
   .v425-options-body .v412-heading button{width:100%;min-height:44px}
   .v425-options-body .v412-origin{margin-top:0}
   .v425-options-body p{overflow-wrap:anywhere}
   .v425-options-body .v225-freshness-bank{min-width:0}
   .flow-sticky-controls .v425-empty{display:none!important}
   #v425-flow-attention{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:8px 0;padding:8px 12px;border:1px solid #e7ce95;border-radius:10px;background:#fff8e8;color:#76500d;font-size:13px;line-height:1.4}
   #v425-flow-attention button{min-height:44px;flex:none;padding:8px 12px;border:1px solid #c9d5e2;border-radius:8px;background:#fff;color:#18344f;font-weight:600;cursor:pointer}
   @media(max-width:380px){.v425-options>.v382-tool-body{max-width:calc(100vw - 24px)}#v425-flow-attention{flex-wrap:wrap}}
  `;document.head.appendChild(style);
  window.__LTS_V425_FLOW_OPTIONS={installed:true,presentation_only:true,paint,materialReasons};paint();
 }
 function install(){try{
  const w=shell?.contentWindow,d=shell?.contentDocument;
  if(!w?.__LTS_V382_FLOW_LAYOUT||!w?.__LTS_V412_PROJECTION||!w?.__LTS_V399_D01)return false;
  if(w.__LTS_V425_FLOW_OPTIONS)return true;
  const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);return !!w.__LTS_V425_FLOW_OPTIONS;
 }catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100)}
 shell?.addEventListener('load',()=>{tries=0;start()});start();window.LTSV339Boot?.watch('lts-v425-flow-options.js',install);
})();
