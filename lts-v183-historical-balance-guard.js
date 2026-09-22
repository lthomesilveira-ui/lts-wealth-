/* V183 candidate: suppress derived totals when the bank basis is unavailable. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V182_FEEDBACK?.installed)return false;
      if(d.getElementById('v183-historical-balance-guard-runtime'))return true;
      const runtime=function(){
        const explanation='Sem abertura documental completa das contas nesta data, o saldo bancário consolidado e os totais que dependem dele não estão disponíveis. Entradas e saídas do dia permanecem visíveis; confira cada banco na respectiva aba.';
        let pending=false;
        function guard(){
          pending=false;
          const rows=document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]');
          let masked=0;
          for(const row of rows){
            const cells=row.children;
            if(cells.length<11||cells[1].textContent.trim()!=='—'||cells[4].textContent.trim()!=='—')continue;
            for(const index of [6,8,10]){
              const cell=cells[index];
              if(cell.textContent.trim()==='—')continue;
              cell.textContent='—';cell.title=explanation;cell.classList.remove('neg','pos');
            }
            row.classList.add('v183-relative-history');masked++;
          }
          if(masked){
            const controls=document.querySelector('.flow-sticky-controls');
            let note=controls?.querySelector('.v183-balance-basis-note');
            if(controls&&!note){note=document.createElement('p');note.className='v183-balance-basis-note';note.setAttribute('role','status');note.style.cssText='margin:8px 12px;padding:9px 12px;border-radius:9px;background:#fff5df;color:#60451e;font-size:12px;line-height:1.45';controls.appendChild(note)}
            if(note&&note.textContent!==explanation)note.textContent=explanation;
            const old=document.querySelector('.v168-history-note');
            if(old&&old.textContent!==explanation)old.textContent=explanation;
          }else{
            document.querySelector('.v183-balance-basis-note')?.remove();
          }
        }
        const observer=new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(guard)}});
        observer.observe(document.body,{childList:true,subtree:true,characterData:true});
        window.__LTS_V183_HISTORICAL_BALANCE_GUARD={installed:true,policy:'hide-derived-totals-without-bank-basis',finance_rows_changed:false};
        guard();
      };
      const script=d.createElement('script');script.id='v183-historical-balance-guard-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return true;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
})();
