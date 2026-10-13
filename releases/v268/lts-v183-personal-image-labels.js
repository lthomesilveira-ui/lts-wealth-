/* Candidate-only category labels. Stored categories and drilldown keys stay intact. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V183_PERSONAL_IMAGE_LABELS)return;
  const displayName='Imagem e cuidados pessoais';
  const category=/^(\s*(?:(?:Lucas|Larissa|Benjamin)\s*[-—–]\s*)?)Vestu[aá]rio(\s*)$/i;
  const word=/\bVestu[aá]rio\b/gi;
  function label(text){return String(text).replace(category,(_,prefix,suffix)=>prefix+displayName+suffix)}
  function decorate(){
   const walk=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
   for(let node=walk.nextNode();node;node=walk.nextNode()){
    const parent=node.parentElement;
    if(!parent||parent.closest('script,style,textarea,input,code,pre,[contenteditable]'))continue;
    let next=label(node.nodeValue);
    if(parent.closest('.v181-lead,.v181-review-fact small'))next=next.replace(word,displayName);
    if(next===node.nodeValue)continue;
    // An option without an explicit value derives its submitted value from its label.
    const option=parent.closest('option');
    if(option&&!option.hasAttribute('value'))option.setAttribute('value',option.value);
    node.nodeValue=next;
   }
   for(const element of document.querySelectorAll('[data-group],[data-v181-detail-group],#v178DetailTitle')){
    for(const attribute of ['aria-label','title']){
     const old=element.getAttribute(attribute);
     if(old){const next=old.replace(word,displayName);if(next!==old)element.setAttribute(attribute,next)}
    }
   }
  }
  const previous=render;
  render=function(){const result=previous();decorate();return result};
  let scheduled=false;
  new MutationObserver(()=>{
   if(scheduled)return;
   scheduled=true;
   requestAnimationFrame(()=>{scheduled=false;decorate()});
  }).observe(document.body,{childList:true,subtree:true,characterData:true});
  window.__LTS_V183_PERSONAL_IMAGE_LABELS={installed:true,displayName,label,source_categories_unchanged:true};
  decorate();
 }
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V181_REGRESSION_CLOSURE?.installed)return false;
   if(w.__LTS_V183_PERSONAL_IMAGE_LABELS)return true;
   const script=d.createElement('script');script.id='v183-personal-image-runtime';
   script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
   return !!w.__LTS_V183_PERSONAL_IMAGE_LABELS;
  }catch{return false}
 }
 let generation=0;
 function burst(){const current=++generation;let tries=0;function step(){if(current!==generation)return;if(!install()&&++tries<160)setTimeout(step,150)}step()}
 shell?.addEventListener('load',burst);burst();
})();
