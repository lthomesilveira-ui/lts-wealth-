(function(){
  const MARK='expense-input-dashboard-recomposition-v1';
  let reloads=0,loading=false;
  function ready(){
    try{
      if(window.LTS_V150_RECOMPOSITION===MARK)return true;
      if(!window.D||typeof window.render!=='function'||!document.head)return false;
      if(loading)return false;
      const old=document.getElementById('v150RecompositionHost');
      if(old)old.remove();
      loading=true;reloads++;
      const s=document.createElement('script');
      s.id='v150RecompositionHost';
      s.src='wip35-v150-recomposition.js?v150-auth-ready-'+reloads;
      s.onload=()=>{loading=false;try{window.__LTS_V150_AFTER_RENDER?.()}catch(e){}};
      s.onerror=()=>{loading=false};
      document.head.appendChild(s);
      return true;
    }catch(e){loading=false;return false}
  }
  window.__LTS_V150_BOOTSTRAP_RETRY=ready;
  window.__LTS_V150_BOOTSTRAP_STATUS={version:'v150-authenticated-bootstrap-v1',bounded_retry:true,permanent_polling:false,reloads:()=>reloads};
  [0,150,350,700,1200,2000,3400,5200,7800,11000,14500].forEach(ms=>setTimeout(ready,ms));
})();