/* Candidate-only version identity after legacy render decorators. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_RETENTION?.installed)return false;
      if(w.__LTS_V183_VERSION?.installed)return true;
      const runtime=function(){
        const oldRender=render;
        function stamp(){
          document.querySelectorAll('.brand small').forEach(x=>{if(x.textContent!=='V183 · Homologação')x.textContent='V183 · Homologação';if(x.getAttribute('aria-label')!=='V183 · Homologação')x.setAttribute('aria-label','V183 · Homologação')});
          document.querySelectorAll('.v168-release').forEach(x=>{if(x.textContent!=='V183 · Homologação')x.textContent='V183 · Homologação';if(x.getAttribute('aria-label')!=='V183 · Homologação')x.setAttribute('aria-label','V183 · Homologação')});
          document.querySelectorAll('.v181-release').forEach(x=>x.remove());
          try{const scope=window.parent.document.getElementById('scope');if(scope){if(scope.textContent)scope.textContent='';if(scope.getAttribute('aria-label')!=='V183 · Homologação')scope.setAttribute('aria-label','V183 · Homologação')}}catch{}
        }
        render=function(){const value=oldRender();stamp();return value};
        const observer=new MutationObserver(stamp);
        observer.observe(document.body,{childList:true,subtree:true,characterData:true});
        try{observer.observe(window.parent.document.getElementById('scope'),{childList:true,subtree:true,characterData:true})}catch{}
        window.__LTS_V183_VERSION={installed:true};stamp();
      };
      const s=d.createElement('script');s.id='v183-version-runtime';s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);
      return !!w.__LTS_V183_VERSION?.installed;
    }catch{return false}
  }
  let count=0;const timer=setInterval(()=>{if(install()||++count>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{count=0;if(!install())setTimeout(install,300)});
})();
