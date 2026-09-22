/* V182 homologation follow-up: period-complete monthly reading and drill-down. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V181_REGRESSION_CLOSURE?.installed||!w?.__LTS_V175_STATE)return false;
   if(w.__LTS_V182_FEEDBACK?.installed)return true;
   const run=function(){
    const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE,detail=window.__LTS_V178_REVIEW;
    const oldExpenses=despesas,oldRender=render;
    const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const n=x=>Number.isFinite(Number(x))?Number(x):0;
    const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n(x));
    const current=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const range=()=>{const s=v168.expense,t=current(),year=t.slice(0,4);let from=year+'-01-01';if(s.key==='all')from='2013-10-10';else if(s.key==='6m'||s.key==='12m'){const d=new Date(t.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));from=d.toISOString().slice(0,10)}else if(s.key==='custom')from=s.customFrom||from;return{from,to:s.key==='custom'?(s.customTo||t):t}};
    const monthText=k=>{const p=String(k).slice(0,7);return /^\d{4}-\d\d$/.test(p)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(p+'-01T12:00:00Z')).replace('.',''):p};
    function selectedMonths(data){const r=range();return (Array.isArray(data?.months)?data.months:[]).map(x=>String(x).slice(0,7)).filter(x=>x>=r.from.slice(0,7)&&x<=r.to.slice(0,7)).sort()}
    function summary(data,months){
     const values=new Map((Array.isArray(data?.monthly_totals)?data.monthly_totals:[]).map(x=>[String(x.month).slice(0,7),x]));let entries=0,expense=0,operational=0,extra=0;
     const body=months.map(k=>{const x=values.get(k)||{},rev=n(x.revenue),ex=n(x.extraordinary),out=n(x.expenses),total=rev+ex-out;entries+=rev+ex;expense+=out;operational+=rev;extra+=ex;return '<tr><th>'+safe(monthText(k))+'</th><td>'+money(rev)+'</td><td>'+money(ex)+'</td><td>'+money(rev+ex)+'</td><td>'+money(out)+'</td><td>'+money(total)+'</td></tr>'}).join('');
     const r=range(),label=r.from.split('-').reverse().join('/')+' a '+r.to.split('-').reverse().join('/');
     return '<article class="v175-section v182-months"><div class="v168-cardhead"><div><span>'+safe(label)+'</span><h2>Resumo de cada mês</h2></div><small>'+months.length+' meses no período</small></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Mês</th><th>Receitas operacionais</th><th>Extraordinárias</th><th>Entradas</th><th>Despesas</th><th>Resultado</th></tr></thead><tbody>'+body+'<tr class="v182-total"><th>Total do período</th><td>'+money(operational)+'</td><td>'+money(extra)+'</td><td>'+money(entries)+'</td><td>'+money(expense)+'</td><td>'+money(entries-expense)+'</td></tr></tbody></table></div><p>Resultado é entradas menos despesas; não é saldo bancário acumulado.</p></article>';
    }
    function matrix(title,groups,months,coverage){
     const rows=Array.isArray(groups)?groups:[],totals=months.map(()=>0),items=[];
     for(const group of rows){const lookup=new Map((group.monthly||[]).map(x=>[String(x.month).slice(0,7),n(x.amount)]));const vals=months.map((k,i)=>{const v=lookup.get(k)||0;totals[i]+=v;return v});if(vals.every(v=>Math.abs(v)<0.005))continue;items.push('<tr><th>'+safe(group.label||group.name)+'</th>'+vals.map(v=>'<td>'+(v?money(v):'—')+'</td>').join('')+'<td>'+money(vals.reduce((a,b)=>a+b,0))+'</td></tr>')}
     if(coverage){const lookup=new Map((coverage.monthly||[]).map(x=>[String(x.month).slice(0,7),n(x.amount)]));const vals=months.map((k,i)=>{const v=lookup.get(k)||0;totals[i]+=v;return v});if(vals.some(v=>Math.abs(v)>=0.005))items.push('<tr><th>Faturas sem composição individual</th>'+vals.map(v=>'<td>'+(v?money(v):'—')+'</td>').join('')+'<td>'+money(vals.reduce((a,b)=>a+b,0))+'</td></tr>')}
     return '<article class="v175-section v182-matrix"><div class="v168-cardhead"><div><span>Período selecionado</span><h2>'+safe(title)+'</h2></div></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+safe(monthText(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+items.join('')+'<tr class="v182-total"><th>Total '+safe(title.toLowerCase())+'</th>'+totals.map(v=>'<td>'+money(v)+'</td>').join('')+'<td>'+money(totals.reduce((a,b)=>a+b,0))+'</td></tr></tbody></table></div></article>';
    }
    function monthly(root){const host=root.querySelector('.v175-monthly'),data=v175?.monthly?.data;if(!host||!data)return;const months=selectedMonths(data);if(!months.length)return;
     host.querySelector('.v181-month-summary')?.remove();host.querySelector('.v175-yearbar')?.remove();host.querySelectorAll('.v175-section').forEach(x=>x.remove());
     const kpis=host.querySelector('.v168-kpis');if(!kpis)return;
     kpis.insertAdjacentHTML('afterend',summary(data,months)+matrix('Receitas operacionais',data.revenue_groups,months)+matrix('Entradas extraordinárias',data.extraordinary_groups,months)+matrix('Despesas por categoria',data.expense_groups,months,data.expense_unclassified_card_coverage));
     const tables=host.querySelectorAll('.v182-matrix');for(const table of tables){const diff=Math.abs(n(table.querySelector('.v182-total td:last-child')?.textContent.replace(/[^\d,-]/g,'').replace(/\./g,'').replace(',','.')));if(!Number.isFinite(diff))table.insertAdjacentHTML('beforeend','<p>Conferência indisponível</p>')}
    }
    despesas=function(){const t=document.createElement('template');t.innerHTML=oldExpenses();const root=t.content.querySelector('.v168-expenses');if(root&&v168.expense.tab==='monthly')monthly(root);return t.innerHTML};
    render=function(){const result=oldRender();document.querySelectorAll('.v181-release').forEach(x=>x.textContent='V182 · Homologação');if(V==='Dashboard'){document.querySelectorAll('button').forEach(button=>{const label=button.textContent.trim();if(label==='Empréstimos'||label==='Apartamento · CIPÓ 396'){button.setAttribute('aria-label','Abrir '+label+' e seus componentes');button.classList.add('v182-expand-cue')}})}return result};
    window.__LTS_V182_FEEDBACK={installed:true,version:'v182-monthly-scope',contracts:{full_selected_months:true,group_subtotals:true,source_values_unchanged:true}};
    render();
   };
   const script=d.createElement('script');script.id='v182-runtime';script.textContent='('+run.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V182_FEEDBACK?.installed;
  }catch{return false}
 }
 let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>100)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
})();
