/* Disclose pending bank evidence on demand; never insert a cash movement. */
(function(){'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){'use strict';
  if(window.__LTS_V423_CLARITY)return;
  const M=parent.LTSV423Clarity;let memo=null,flight=null,ticket=0,product=D,identity=BOOT?.generation;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n),date=d=>String(d||'').split('-').reverse().join('/');
  const oldTitle=flowSemanticTitle,oldMeta=flowSemanticMeta;
  flowSemanticTitle=function(e){return M.cardLabel(e)?.title||oldTitle(e)};
  flowSemanticMeta=function(e){return M.cardLabel(e)?.note||oldMeta(e)};
  const style=document.createElement('style');style.textContent='.v423-subgroups{padding:12px 16px;border-bottom:1px solid #dbe3ec}.v423-subgroups h3{margin:0 0 9px;font-size:15px}.v423-group-list{display:grid;gap:7px;max-height:220px;overflow:auto}.v423-group-list button{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left;background:#f6f8fa;border:1px solid #dbe3ec;border-radius:9px;padding:10px 12px;min-height:44px;color:inherit}.v423-group-list button[aria-pressed=true]{border-color:#2563eb;background:#eef5ff}.v423-group-list span{min-width:0;overflow-wrap:anywhere}.v423-group-list strong{white-space:nowrap}.v423-group-list small{display:block;font-size:12px;color:#64748b;margin-top:4px}.v423-bank-evidence .v365-pair small{display:block}.v423-bank-evidence p{font-size:13px;margin:9px 0}.v423-bank-evidence details{font-size:12px}.v423-bank-evidence h3{font-size:15px}.v423-bank-evidence .v365-pair{gap:12px}.v423-bank-evidence .v365-pair span{min-width:0;overflow-wrap:anywhere}';document.head.appendChild(style);
  function clear(){ticket++;memo=null;flight=null;}
  const status=window.__LTS_V423_CLARITY={installed:true,financialWrites:0,clear};
  function renderEvidence(day,root){
   if(!memo)return;
   for(const bank of ['Itaú','Bradesco','C6']){
    if(ACC!=='Consolidado'&&ACC!==bank)continue;
    const b=M.bridge(day,memo,bank);if(!b)continue;
    const old=[...root.querySelectorAll('.v365-bridge')].find(x=>x.querySelector('h3')?.textContent.startsWith(bank+' ·'));
    if(!old)continue;
    old.classList.add('v423-bank-evidence');old.dataset.v423='pending';
    const line=(label,value,when='')=>'<div class="v365-pair"><span>'+esc(label)+(when?'<small>'+esc(when)+'</small>':'')+'</span><b>'+money(value)+'</b></div>';
    old.innerHTML='<h3>'+esc(bank)+' · movimentos em confirmação</h3>'+line('Saldo calculado antes da conciliação',b.opening)+b.movements.map(m=>line(m.description,m.amount,date(m.date))).join('')+line('Saldo informado pelo banco',b.observed)+'<p>Os valores explicam a diferença. A confirmação dos lançamentos pelo banco ainda está pendente.</p><details><summary>Origem</summary><p>Posição bancária de '+esc(date(b.sourceDate))+'. Estes movimentos ainda não foram marcados como liquidados.</p></details>';
    const row=document.getElementById('d-'+day.date);const note=row?.querySelector('.v365-balance-status');if(note)note.textContent='Movimentos em confirmação';
   }
  }
  function update(){
   if(product!==D||identity!==BOOT?.generation){product=D;identity=BOOT?.generation;clear();}
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden'))return;
   const d=mergedFlowDays().find(x=>x.date===today());if(!d?.cash_position_guard||!EXP.has(d.date))return;
   const root=document.getElementById('d-'+d.date)?.nextElementSibling;if(!root?.classList.contains('fx89-details'))return;
   if(memo){renderEvidence(d,root);return;}
   if(flight)return;
   const id=++ticket,day=d.date,owner=BOOT?.generation;
   flight=Promise.resolve(S.rpc('lts_browser_pending_bank_evidence_v423',{})).then(({data,error})=>{
    if(id!==ticket||owner!==BOOT?.generation||day!==today()||!D||N.classList.contains('hidden'))return;
    if(error||data?.version!=='pending-bank-evidence-v423'||data.as_of!==day)return;
    memo=data;update();
   }).catch(()=>{}).finally(()=>{if(id===ticket)flight=null});
  }
  const previous=render;render=function(...args){const value=previous.apply(this,args);update();return value;};
  for(const name of ['signOut','signInWithPassword']){const prior=S.auth[name];if(typeof prior==='function')S.auth[name]=function(...a){clear();return prior.apply(this,a)};}
  update();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V365?.installed||!w.__LTS_V178_REVIEW?.installed)return false;if(!w.__LTS_V423_CLARITY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V423_CLARITY;}catch{return false}}
 function burst(){const k=++generation;let n=0;function step(){if(k!==generation)return;if(!install()&&++n<320)setTimeout(step,100)}step();}
 outer?.addEventListener('load',burst);burst();
})();
