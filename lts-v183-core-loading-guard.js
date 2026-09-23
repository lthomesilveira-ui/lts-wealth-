/* Candidate-only guard for a restored Flow route before the authenticated product arrives. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return false;
      if(w.__LTS_V183_CORE_LOADING_GUARD?.installed)return true;
      const runtime=function(){
        if(window.__LTS_V183_CORE_LOADING_GUARD?.installed)return;
        const original=fluxo;
        fluxo=function(){
          if(typeof D==='undefined'||!D)return '<div class="notice" role="status">Preparando o Fluxo Diário…</div>';
          return original();
        };
        window.__LTS_V183_CORE_LOADING_GUARD={installed:true,financial_data_changed:false};
      };
      const script=d.createElement('script');script.id='v183-core-loading-guard';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_CORE_LOADING_GUARD?.installed;
    }catch{return false}
  }
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},100);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,150)});
})();
