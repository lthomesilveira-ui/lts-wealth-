/* Candidate-only: explicit transaction navigation owns its requested date. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_EXACT_FLOW_NAVIGATION)return;
  const baseRender=render;
  function bind(){
   document.querySelectorAll('[data-v168-search-flow],[data-v168-search-edit],[data-v168-flow-row]').forEach(button=>{
    const previous=button.onclick;
    if(typeof previous!=='function'||previous.__v183ExactFlow)return;
    function explicitNavigation(event){
     // V162 and V170 enqueue default ranges when entering Flow. During this
     // synchronous handler only, suppress those defaults; keep the original
     // exact-date loader, row focus, edit permissions and editor untouched.
     const recovery=window.__LTS_V162_FLOW_RECOVERY_STATUS,review=window.__LTS_V170_STATE;
     const applied=recovery?.default_range_applied,last=review?.lastRoute;
     if(recovery)recovery.default_range_applied=false;
     if(review)review.lastRoute='Fluxo Diário';
     try{return previous.call(this,event)}
     finally{
      if(recovery)recovery.default_range_applied=applied;
      if(review&&V!=='Fluxo Diário')review.lastRoute=last;
     }
    }
    explicitNavigation.__v183ExactFlow=true;button.onclick=explicitNavigation;
   });
  }
  render=function(){const result=baseRender.apply(this,arguments);bind();return result};
  window.__LTS_V183_EXACT_FLOW_NAVIGATION={installed:true};bind();
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_SEARCH_COMPLETE?.installed)return false;if(w.__LTS_V183_EXACT_FLOW_NAVIGATION)return true;const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V183_EXACT_FLOW_NAVIGATION}catch{return false}}
 function burst(){let count=0;const timer=setInterval(()=>{if(install()||++count>160)clearInterval(timer)},150)}
 shell?.addEventListener('load',burst);burst();
})();
