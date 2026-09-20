/* Review actions use authenticated report rows; no personal constants or writes. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V178_REVIEW_ACTIONS||!window.__LTS_V178_REVIEW?.installed)return;
  const api=window.__LTS_V178_REVIEW,state=window.__LTS_V178_STATE;
  const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x)||0);
  const pending='Identificações pendentes';
  function exportPending(){
   const d=state.detail;if(!d||d.group!==pending||d.loading||d.error||d.rows.length!==d.count)return;
   const text=x=>{let s=String(x??'');if(/^[\u0000-\u0020]*[=+@-]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"'};
   const rows=[['Data','Competência','Histórico','Conta ou cartão','Pessoa','Categoria','Valor (R$)','Confirmar'].map(text).join(';')];
   for(const r of d.rows)rows.push([text(r.date_kind==='day'?r.date:''),text(String(r.period||'').slice(0,7)),text(r.description),text(r.account_source),text(r.beneficiary),text(r.category),'"'+Number(r.amount).toFixed(2).replace('.',',')+'"',text(r.review_question||'Pessoa ou classificação a confirmar')].join(';'));
   const url=URL.createObjectURL(new Blob(['\ufeff'+rows.join('\r\n')],{type:'text/csv;charset=utf-8'}));
   const a=document.createElement('a');a.href=url;a.download='LTS-identificacoes-'+d.range.from+'-a-'+d.range.to+'.csv';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  }
  function detailQuestions(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||d.group!==pending||!host)return;
   const byKey=new Map(d.rows.map(r=>[String(r.key),r]));
   host.querySelectorAll('tr[data-row-key]').forEach(tr=>{const r=byKey.get(tr.dataset.rowKey);if(!r||tr.querySelector('.v178-question'))return;const small=document.createElement('small');small.className='v178-question';small.textContent=r.review_question||'Pessoa ou classificação a confirmar';tr.children[1]?.appendChild(small)});
   let button=host.querySelector('.v178-export-pending');if(!button){button=document.createElement('button');button.className='v178-refresh v178-export-pending';button.textContent='Exportar lista';button.title='Exportar todos os itens do período';button.onclick=exportPending;host.querySelector('footer')?.appendChild(button)}
   button.disabled=Boolean(d.loading||d.error||d.rows.length!==d.count);
   const input=host.querySelector('input');if(input&&!input.dataset.reviewQuestions){input.dataset.reviewQuestions='1';input.addEventListener('input',detailQuestions)}
   const retry=host.querySelector('.v178-retry');if(retry&&!retry.dataset.reviewQuestions){retry.dataset.reviewQuestions='1';const old=retry.onclick;retry.onclick=e=>Promise.resolve(old?.call(retry,e)).finally(detailQuestions)}
  }
  async function open(group,range,expected){await api.openDetail(group,null,range,expected);detailQuestions()}
  function guardSecondaryTotals(){
   if(V!=='Dashboard')return;
   const cards=[...document.querySelectorAll('.v168-dashboard .v168-kpi')];
   const find=label=>cards.find(c=>c.querySelector('span')?.textContent.trim()===label);
   const available=label=>{const text=find(label)?.querySelector('strong')?.textContent.trim();return Boolean(text&&!/^[—–-]$/.test(text))};
   for(const [label,parts] of [['Total de posições futuras',['RSUs futuras','Cash RSUs futuras']],['Total em previdências',['Organon','Novartis']]]){
    if(parts.every(available))continue;const card=find(label);if(!card)continue;card.querySelector('strong').textContent='—';if(card.querySelector('small'))card.querySelector('small').textContent='Aguardando todas as posições';
   }
  }
  function decorate(){
   guardSecondaryTotals();
   document.querySelectorAll('[data-v178-scope]').forEach(parent=>{
    if(parent.querySelector('.v178-review-actions'))return;
    const dashboard=parent.dataset.v178Scope==='dashboard';
    const data=dashboard?state.dashboardReport.data:window.__LTS_V175_STATE?.expense?.data;if(!data)return;
    const year=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const range=dashboard?{from:year.slice(0,4)+'-01-01',to:year}:{from:data.period?.from,to:data.period?.to};if(!range.from||!range.to)return;
    const count=Number(data.summary?.pending_identification)||0,coverage=(data.management_groups||[]).find(g=>g.name==='Faturas conciliadas pelo total');
    const box=document.createElement('div');box.className='v178-review-actions';box.style.cssText='display:flex;gap:8px;flex-wrap:wrap;margin-top:12px';
    if(count){const b=document.createElement('button');b.className='v178-refresh v178-pending-open';b.textContent='Identificações pendentes · '+count;b.onclick=()=>open(pending,range,null);box.appendChild(b)}
    if(coverage&&Number(coverage.total)!==0){const b=document.createElement('button');b.className='v178-refresh v178-coverage-open';b.textContent='Faturas a detalhar · '+money(coverage.total);b.onclick=()=>open(coverage.name,range,coverage.total);box.appendChild(b)}
    parent.appendChild(box);
    if(!dashboard&&window.__LTS_V168_STATE?.expense?.tab==='categories'){
     const existing=new Set([...parent.querySelectorAll('.v178-open.title')].map(b=>b.dataset.group));
     const extra=(data.management_groups||[]).filter(g=>!existing.has(g.name)&&g.name!=='Faturas conciliadas pelo total');
     const max=Math.max(1,...(data.management_groups||[]).map(g=>Math.abs(Number(g.total)||0)));
     for(const g of extra){const row=document.createElement('div');row.className='v178-rankrow';row.innerHTML='<span>'+(existing.size+1)+'</span><div><button class="v178-open title">'+escape(g.name)+'</button><i><u style="width:'+Math.max(1,Math.abs(Number(g.total)||0)/max*100)+'%"></u></i></div><button class="v178-open amount">'+money(g.total)+'</button>';row.querySelectorAll('button').forEach(b=>{b.dataset.group=g.name;b.onclick=()=>open(g.name,range,g.total)});parent.querySelector('.v178-rank')?.appendChild(row);existing.add(g.name)}
    }
   });
   detailQuestions();
  }
  const previous=render;render=function(){const result=previous();decorate();return result};
  window.__LTS_V178_REVIEW_ACTIONS={installed:true,decorate};decorate();
 }
 let generation=0;
 function burst(){const g=++generation;let n=0;function attempt(){if(g!==generation)return;try{const w=outer.contentWindow,d=outer.contentDocument;if(w.__LTS_V178_REVIEW?.installed){if(!w.__LTS_V178_REVIEW_ACTIONS){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s)}return}}catch{}if(++n<320)setTimeout(attempt,100)}attempt()}
 outer?.addEventListener('load',burst);burst();
})();
