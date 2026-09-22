/* V183 candidate: keep relative historical ledger values out of absolute cash columns. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_CARD_PERIOD?.installed)return false;
      if(w.__LTS_V183_HISTORICAL_BALANCE_GUARD?.installed)return true;
      const runtime=function(){
        if(window.__LTS_V183_HISTORICAL_BALANCE_GUARD?.installed)return;
        const previous=render;
        function guard(){
          if(V!=='Fluxo Diário'||ACC!=='Consolidado')return;
          const relative=mergedFlowDays().filter(x=>x?.historical&&x.relative_balance_display===true);
          if(!relative.length)return;
          for(const item of relative){
            const row=document.getElementById('d-'+item.date);if(!row)continue;
            for(const index of [1,4,6,8,10]){
              const cell=row.children[index];if(!cell)continue;
              cell.textContent='—';
              cell.title='Saldo absoluto indisponível antes da abertura documental completa das contas. Movimentos do dia preservados.';
              cell.classList.remove('neg');
            }
            row.classList.add('v183-relative-history');
          }
          const controls=document.querySelector('.flow-sticky-controls');
          if(controls&&!controls.querySelector('.v183-balance-basis-note')){
            const note=document.createElement('p');note.className='v183-balance-basis-note';
            note.setAttribute('role','status');
            note.textContent='Antes da primeira abertura documental completa das contas, o histórico mostra entradas e saídas, mas não apresenta o acumulado relativo desde 2013 como saldo bancário absoluto. As posições de cada banco precisam ser conferidas na respectiva aba.';
            note.style.cssText='margin:8px 12px;padding:9px 12px;border-radius:9px;background:#fff5df;color:#60451e;font-size:12px;line-height:1.45';
            controls.appendChild(note);
          }
        }
        render=function(){const result=previous();guard();return result};
        window.__LTS_V183_HISTORICAL_BALANCE_GUARD={installed:true,policy:'hide-relative-as-absolute',finance_rows_changed:false};
        if(D&&!N.classList.contains('hidden'))render();
      };
      const script=d.createElement('script');script.id='v183-historical-balance-guard-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_HISTORICAL_BALANCE_GUARD?.installed;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
})();
