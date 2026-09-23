/* V183: expose the existing private Retention Award schedule without inventing dates or cash. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_CARD_PERIOD?.installed||!w?.__LTS_V168_STATE)return false;
      if(w.__LTS_V183_RETENTION?.installed)return true;
      const runtime=function(){
        const state=window.__LTS_V168_STATE,oldRender=render;
        const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        const money=c=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(c/100);
        const audit=window.__LTS_V183_RETENTION={installed:true,status:'waiting'};
        function decorate(){
          if(V!=='Patrimônio')return;
          const award=state.wealth?.data?.employment_awards?.retention;
          const rows=Array.isArray(award?.installments)?award.installments:[];
          const gross=Number(award?.gross_total_brl);
          const shares=rows.map(x=>Number(x.share));
          if(!Number.isFinite(gross)||gross<=0||!rows.length||shares.some(x=>!Number.isFinite(x)||x<=0)||Math.abs(shares.reduce((a,b)=>a+b,0)-1)>0.000001){audit.status='source_incomplete';return}
          const cards=[...document.querySelectorAll('article')];
          const card=cards.find(x=>x.textContent?.includes('Retention Award')&&x.querySelector('h2')?.textContent?.includes('Acordo separado'));
          if(!card){audit.status='panel_unavailable';return}
          const grossCents=Math.round(gross*100);
          let assigned=0;
          const items=rows.map((x,i)=>{const cents=i===rows.length-1?grossCents-assigned:Math.round(grossCents*shares[i]);assigned+=cents;return {label:x.label||`Parcela ${i+1}`,detail:x.detail||'',cents}});
          if(items.some(x=>x.cents<0)||assigned!==grossCents){audit.status='sum_mismatch';return}
          const details=document.createElement('details');details.className='v183-retention-composition';
          details.style.cssText='margin:12px 0;padding:12px;border:1px solid #d8e1e9;border-radius:10px';
          details.innerHTML='<summary style="cursor:pointer;font-weight:700">Abrir composição contratual · '+rows.length+' parcelas</summary><div style="display:grid;gap:8px;margin-top:10px">'+items.map(x=>'<div style="display:flex;justify-content:space-between;gap:12px"><span><b>'+esc(x.label)+'</b><small style="display:block">'+esc(x.detail)+'</small></span><strong>'+money(x.cents)+'</strong></div>').join('')+'</div><p>Parcelas do acordo bruto, separadas das RSUs. Os marcos são relativos ao Closing; data exata, vesting e disponibilidade exigem conferência documental. Não representam entrada bancária.</p>';
          card.querySelector('.v183-retention-composition')?.remove();card.appendChild(details);
          audit.status='ready';audit.amount_cents=grossCents;audit.component_cents=assigned;audit.count=rows.length;
        }
        render=function(){const result=oldRender();queueMicrotask(decorate);return result};
        decorate();
      };
      const script=d.createElement('script');script.id='v183-retention-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_RETENTION?.installed;
    }catch{return false}
  }
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
})();
