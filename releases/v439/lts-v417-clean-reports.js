/* Shorten only known process notices. Preserve failures, controls and financial content. */
(function () {
  'use strict';
  function clean(doc) {
    for (const p of doc.querySelectorAll('.v168-note.warn')) {
      const b=p.querySelector('[data-v333-actions-refresh]');
      if (!b || !p.textContent.startsWith('Não foi possível atualizar todas as ações.')) continue;
      for (const n of [...p.childNodes]) if (n.nodeType===3 && n.textContent.includes('Não foi possível atualizar todas as ações.')) n.textContent=n.textContent.replace('Não foi possível atualizar todas as ações.', 'Não foi possível atualizar as pendências.');
      b.textContent='Tentar novamente';
    }
    for (const span of doc.querySelectorAll('.v168-loadstatus span')) {
      const text=span.textContent;
      if (/^Resumo já disponível\.\s*Atualizando os detalhes sem apagar os valores exibidos…$/.test(text)) span.textContent='Atualizando…';
      if (/^Resumo preservado\.\s*\d+ leitura\(s\) não atualizaram; nenhuma informação anterior foi apagada\.$/.test(text)) span.textContent='Alguns dados não atualizaram.';
    }
  }
  if (typeof module!=='undefined' && module.exports) { module.exports={clean}; return; }
  const shell=document.getElementById('shell');
  function install() {
    try {
      const doc=shell?.contentDocument, win=shell?.contentWindow;
      if (!doc?.body || win.__LTS_V417_CLEAN_REPORTS?.body===doc.body) return;
      win.__LTS_V417_CLEAN_REPORTS?.observer?.disconnect();
      let queued=false;
      const update=()=>{queued=false;clean(doc);};
      const observer=new MutationObserver(()=>{if(!queued){queued=true;win.requestAnimationFrame(update);}});
      observer.observe(doc.body,{subtree:true,childList:true});
      win.__LTS_V417_CLEAN_REPORTS={installed:true,body:doc.body,observer,clean:()=>clean(doc)};
      update();
    } catch (_) { /* A navigation is retried at its load event. */ }
  }
  shell?.addEventListener('load',install); install();
})();
