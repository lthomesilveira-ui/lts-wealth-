/* V227 restores screen ownership and the approved content; only requested order changes. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_LAYOUT)return;
  const previousRender=render;
  function dashboardLayout(){
   const root=document.querySelector('.v168-dashboard');if(!root)return;
   const current=root.querySelector('.v168-kpi-section.current');if(!current)return;
   let expense=root.querySelector('.v227-expenses');
   if(!expense){
    const cards=Array.from(root.querySelectorAll('.v168-card'));
    const liquidity=cards.find(e=>/Evolução projetada/.test(e.querySelector('h2')?.textContent||''));
    const decisions=cards.find(e=>/O que exige decisão/.test(e.querySelector('h2')?.textContent||''));
    const groups=cards.find(e=>/Principais grupos/.test(e.querySelector('h2')?.textContent||''));
    const future=cards.find(e=>/O que vem pela frente/.test(e.querySelector('h2')?.textContent||''));
    const grid=document.createElement('div');grid.className='v168-grid two v227-liquidity';
    if(liquidity)grid.appendChild(liquidity);if(decisions)grid.appendChild(decisions);current.after(grid);
    expense=document.createElement('section');expense.className='v227-expenses';expense.setAttribute('aria-label','Despesas');
    expense.innerHTML='<div class="v168-sectionhead"><h2>Despesas</h2><span>Gastos no ano, principais grupos e próximas faturas</span></div>';
    const total=Array.from(root.querySelectorAll('.v168-kpi')).find(e=>/Total de despesas do período/.test(e.querySelector('span')?.textContent||''));
    if(total)expense.appendChild(total);
    if(groups)expense.appendChild(groups);
    const restricted=root.querySelector('.v168-kpi-section.restricted')||Array.from(root.querySelectorAll('.v168-kpi-section')).find(e=>/Recursos restritos e consumo/.test(e.textContent));
    if(restricted){const heading=restricted.querySelector('h2,h3,b');if(heading&&/Recursos restritos/.test(heading.textContent))heading.textContent='Recursos restritos';const subtitle=restricted.querySelector('.v168-sectiontitle span');if(subtitle)subtitle.textContent='Posição previdenciária';}
    if(future)root.appendChild(future);
    root.appendChild(expense);
    root.querySelectorAll('.v168-grid').forEach(e=>{if(!e.children.length)e.remove();});
   }
   const upcoming=root.querySelector('.v226-upcoming');if(upcoming&&upcoming.parentElement!==expense)expense.appendChild(upcoming);
  }
  function wealthLayout(){
   if(V!=='Patrimônio')return;
   const root=document.querySelector('.v168-wealth'),s=window.__LTS_V168_STATE?.wealth;if(!root||!s||s.data)return;
   const tabs=root.querySelector('.v168-tabs');if(!tabs)return;
   let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next;}
   const box=document.createElement('div');box.className='v168-card';box.setAttribute('role','status');
   box.textContent=s.error?'Não foi possível carregar o patrimônio agora.':'Carregando patrimônio…';
   if(s.error){const retry=document.createElement('button');retry.className='v168-btn';retry.textContent='Tentar novamente';retry.onclick=()=>{s.error=null;s.loading=false;render();};box.appendChild(retry);}
   root.appendChild(box);
  }
  function after(){dashboardLayout();wealthLayout();}
  render=function(){const result=previousRender.apply(this,arguments);after();return result;};
  window.__LTS_V227_LAYOUT={installed:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V226)return false;if(!d.getElementById('v227-layout-css')){const style=d.createElement('style');style.id='v227-layout-css';style.textContent='.v227-expenses{display:grid;gap:16px;margin-top:24px;padding:20px;border-radius:18px;background:#f8f1f3;border:1px solid #eadce1}.v227-expenses>.v168-kpi{max-width:none}.v227-expenses .v168-sectionhead{display:flex;gap:12px;align-items:baseline;flex-wrap:wrap}.v227-expenses h2{margin:0}.v227-expenses .v168-sectionhead>span{color:#6c5862;font-size:13px}.v227-liquidity{margin:18px 0}@media(max-width:820px){.v227-expenses{padding:12px;gap:12px}}';d.head.appendChild(style);}if(!w.__LTS_V227_LAYOUT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_LAYOUT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
