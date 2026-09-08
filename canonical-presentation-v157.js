(()=>{'use strict';
function route(){return decodeURIComponent(location.hash.slice(1))||document.querySelector('.page-title h1')?.textContent?.trim()||document.querySelector('.pv-head h1')?.textContent?.trim()||'Dashboard'}
function normalizeCount(label){for(const card of document.querySelectorAll('.pv-kpi')){const l=card.querySelector('label')?.textContent?.trim();if(l!==label)continue;const s=card.querySelector('strong');if(!s)continue;const raw=s.textContent.replace(/[^0-9,-]/g,'').replace('.','').replace(',','.');const n=Number(raw);if(Number.isFinite(n))s.textContent=Math.round(n).toLocaleString('pt-BR')}}
const UX_CONTRACT='safe-errors-accessible-controls-readable-mobile-v1';
function polish(){
  const r=route();
  if(r!=='Fluxo Diário')document.querySelector('.fv-build')?.remove();
  if(r==='Fluxo Diário')document.querySelector('.pv-build')?.remove();
  if(r==='Cartões'){
    normalizeCount('Ciclos certificados');normalizeCount('Linhas certificadas');
    for(const card of document.querySelectorAll('.pv-kpi')){
      if(card.querySelector('label')?.textContent?.trim()!=='Vencimento')continue;
      const strong=card.querySelector('strong'),small=card.querySelector('small');
      if(strong&&small&&/^\d{2}\/\d{2}\/\d{4}$/.test(small.textContent.trim())){strong.textContent=small.textContent.trim();small.textContent='próximo vencimento'}
    }
  }
  document.querySelectorAll('.pv [data-route]').forEach(b=>{if(b.dataset.v157Wired)return;b.dataset.v157Wired='1';b.addEventListener('click',e=>{e.preventDefault();document.querySelector(`.sidebar [data-route="${CSS.escape(b.dataset.route)}"],.mobile-nav [data-route="${CSS.escape(b.dataset.route)}"]`)?.click()})});
  document.querySelectorAll('[data-route]').forEach(b=>b.setAttribute('aria-current',b.classList.contains('active')?'page':'false'));
  document.querySelectorAll('[data-account],[data-preset],[data-fv-mode],[data-mg-pane]').forEach(b=>b.setAttribute('aria-pressed',b.classList.contains('active')?'true':'false'));
  document.querySelectorAll('details').forEach(d=>{const s=d.querySelector(':scope > summary');if(s)s.setAttribute('aria-expanded',d.open?'true':'false')});
  document.querySelectorAll('.fv-exp').forEach(b=>{const date=String(b.dataset.expand||'').split('-').reverse().join('/');b.setAttribute('aria-label',`${b.getAttribute('aria-expanded')==='true'?'Fechar':'Abrir'} movimentos de ${date}`)});
  const today=document.getElementById('fvToday');if(today)today.setAttribute('aria-label','Ir para hoje');
  document.querySelectorAll('.login-msg,.read-status,.ri-success,.liq-success,.doc-message.ok,.mg-message:not(.mg-error)').forEach(el=>{el.setAttribute('role','status');el.setAttribute('aria-live','polite')});
  document.querySelectorAll('.ri-error,.liq-error,.doc-message.err,.mg-error,.fv-error,.pv-empty').forEach(el=>{el.setAttribute('role','alert');el.setAttribute('aria-live','assertive')});
  const dialog=document.querySelector('#fvModalBg .fv-modal');if(dialog){dialog.tabIndex=-1;if(!dialog.dataset.focused){dialog.dataset.focused='1';dialog.focus()}}
  window.__LTS_CANONICAL_UX_STATUS={ready:true,contract:UX_CONTRACT,route:r,aria_current:document.querySelectorAll('[aria-current="page"]').length,pressed_controls:document.querySelectorAll('[aria-pressed]').length,live_regions:document.querySelectorAll('[aria-live]').length};
}
function schedule(){requestAnimationFrame(()=>requestAnimationFrame(polish));setTimeout(polish,220);setTimeout(polish,700)}
document.addEventListener('click',e=>{if(e.target.closest?.('[data-route],[data-anchor],[data-expand],[data-account],[data-preset],[data-event-actions],[data-fv-mode],[data-mg-pane],summary'))schedule()},true);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&document.getElementById('fvModalBg'))document.querySelector('#fvModalBg [data-fv-close]')?.click()});
window.addEventListener('hashchange',schedule);window.addEventListener('pageshow',schedule);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',schedule,{once:true}):schedule();
const status={ready:true,version:'presentation-polish-v2',contract:UX_CONTRACT};window.__LTS_V157_PRESENTATION_STATUS=status;window.__LTS_V157_POLISH_STATUS=status;
})();
