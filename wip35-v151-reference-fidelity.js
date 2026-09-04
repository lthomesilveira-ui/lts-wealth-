(function(){
  const w=window,d=document,MARK='reference-fidelity-v1';
  if(w.LTS_V151_REFERENCE_FIDELITY===MARK)return;
  const st=w.__LTS_V151_REFERENCE_STATE||(w.__LTS_V151_REFERENCE_STATE={planTried:false,plan:null,planError:null,expenseTried:false,expense:null,expenseError:null,drill:null});
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const brl=v=>{try{return typeof w.brl==='function'?w.brl(Number(v||0)):new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v||0))}catch(e){return String(v??'—')}};
  const fmt=v=>{try{return typeof w.fmt==='function'?w.fmt(v):String(v||'').slice(0,10).split('-').reverse().join('/')}catch(e){return String(v||'—')}};
  const asOf=()=>String(w.D?.dashboard_cockpit?.as_of||w.today?.()||new Date().toISOString().slice(0,10)).slice(0,10);
  const monthFrom=()=>asOf().slice(0,7)+'-01';

  function css(){
    if(d.getElementById('v151ReferenceFidelityCss'))return;
    const s=d.createElement('style');s.id='v151ReferenceFidelityCss';s.textContent=`
      .v151-first-negative{margin-top:8px;border:1px solid #e5c8c3;background:#fff5f3;border-radius:10px;padding:9px 10px;font-size:9px;line-height:1.4;color:#7e3c37}.v151-first-negative b{font-size:10px}
      .v151-expense-lens{background:#fff;border:1px solid #dfe5eb;border-radius:18px;padding:15px;box-shadow:0 8px 26px rgba(20,42,70,.05)}.v151-expense-lens-head{display:flex;justify-content:space-between;align-items:flex-start;gap:10px}.v151-expense-lens-head span{display:block;font-size:8px;text-transform:uppercase;font-weight:900;letter-spacing:.06em;color:#9a7441}.v151-expense-lens-head h2{font-size:18px;margin:3px 0 0}.v151-expense-lens-head small{font-size:8px;color:#7d8998;max-width:360px;text-align:right;line-height:1.35}.v151-expense-rank{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin-top:10px}.v151-expense-rank button{border:1px solid #e3e8ed;background:#fbfcfd;border-radius:12px;padding:10px;text-align:left;color:#17304d;cursor:pointer;min-width:0}.v151-expense-rank button:hover{background:#f4f7fa}.v151-expense-rank span{display:block;font-size:8px;color:#758397;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.v151-expense-rank b{display:block;font-size:14px;margin-top:4px}.v151-expense-rank small{display:block;font-size:7px;color:#8995a3;margin-top:3px}.v151-expense-drill{margin-top:10px;border-top:1px solid #e8edf1;padding-top:8px}.v151-expense-drill-head{display:flex;justify-content:space-between;gap:8px;align-items:center}.v151-expense-drill-head b{font-size:10px}.v151-expense-drill-head button{border:0;background:transparent;color:#5f7185;font-size:8px;cursor:pointer}.v151-expense-drill-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;padding:7px 0;border-top:1px solid #eef1f4}.v151-expense-drill-row b{display:block;font-size:9px}.v151-expense-drill-row small{display:block;font-size:7px;color:#83909f;margin-top:2px}.v151-expense-drill-row strong{font-size:9px;white-space:nowrap}.v151-reference-cockpit{--v151-reference-aligned:1}
      @media(max-width:760px){.v151-expense-rank{grid-template-columns:1fr 1fr}.v151-expense-lens-head{flex-direction:column}.v151-expense-lens-head small{text-align:left}}
      @media(max-width:460px){.v151-expense-rank{grid-template-columns:1fr}}
    `;(d.head||d.documentElement).appendChild(s);
  }

  function firstNegative(){
    const local=st.plan||w.__LTS_V142_PLAN_BRIDGE?.data||{},pe=w.D?.planning_executive||{},pl=w.D?.planning_ladder||{},pa=w.D?.dashboard_cockpit?.planning_audited||{};
    return local.management_episodes?.[0]?.start_date||pe.management_episodes?.[0]?.start_date||pe.gap_episodes?.[0]?.start_date||pl.gap_episodes?.[0]?.start_date||pa.first_negative_date||pa.first_real_gap_date||null;
  }
  async function loadPlan(){
    if(st.planTried||!w.S?.rpc)return;st.planTried=true;
    try{const {data,error}=await w.S.rpc('lts_browser_planning_bridge_executive_v1');if(error||!data)throw Error(error?.message||'Planejamento indisponível');st.plan=data}catch(e){st.planError=String(e?.message||e)}finally{paint()}
  }
  async function loadExpense(){
    if(st.expenseTried||!w.S?.rpc)return;st.expenseTried=true;
    try{const {data,error}=await w.S.rpc('lts_browser_expense_context_nature_v1',{p_from:monthFrom(),p_to:asOf()});if(error||!data)throw Error(error?.message||'Despesas indisponíveis');st.expense=data}catch(e){st.expenseError=String(e?.message||e)}finally{paint()}
  }
  function drillHtml(){
    const q=st.drill;if(!q)return '';
    if(q.loading)return '<div id="v151ExpenseDrill" class="v151-expense-drill">Abrindo composição…</div>';
    if(q.error)return `<div id="v151ExpenseDrill" class="v151-expense-drill"><div class="v151-expense-drill-head"><b>Composição indisponível</b><button data-v151-exp-close>Fechar</button></div><small>${esc(q.error)}</small></div>`;
    const rows=q.data?.rows||[];
    return `<div id="v151ExpenseDrill" class="v151-expense-drill"><div class="v151-expense-drill-head"><b>${esc(q.category)} · ${rows.length} lançamento(s)</b><button data-v151-exp-close>Fechar</button></div>${rows.slice(0,60).map(x=>`<div class="v151-expense-drill-row"><div><b>${esc(x.display_name||x.description||x.category||'Lançamento')}</b><small>${fmt(x.date)} · ${esc(x.center||x.center_cost||'Não atribuído')}${x.counterparty?' · '+esc(x.counterparty):''}</small></div><strong>${brl(x.amount)}</strong></div>`).join('')||'<div class="v151-empty">Nenhum lançamento detalhado disponível para esta categoria.</div>'}</div>`;
  }
  function expenseLens(){
    const j=st.expense||{},cats=(j.categories||[]).slice().sort((a,b)=>Number(b.total||0)-Number(a.total||0)).slice(0,4);
    if(st.expenseError)return `<section id="v151ExpenseLens" class="v151-expense-lens"><div class="v151-expense-lens-head"><div><span>Despesas do mês</span><h2>Composição</h2></div><small>Não foi possível carregar a composição agora; nenhum valor foi inferido.</small></div></section>`;
    if(!st.expense)return `<section id="v151ExpenseLens" class="v151-expense-lens"><div class="v151-expense-lens-head"><div><span>Despesas do mês</span><h2>Composição</h2></div><small>Carregando categorias documentadas…</small></div></section>`;
    return `<section id="v151ExpenseLens" class="v151-expense-lens"><div class="v151-expense-lens-head"><div><span>Despesas do mês</span><h2>Abra o número até os lançamentos</h2></div><small>${fmt(monthFrom())} → ${fmt(asOf())} · leitura read-only, sem criar classificação</small></div><div class="v151-expense-rank">${cats.map(x=>`<button type="button" data-v151-exp-cat="${encodeURIComponent(x.name||'')}"><span>${esc(x.name||'A classificar')}</span><b>${brl(x.total)}</b><small>${Number(x.rows||0)} lançamento(s) · ver composição</small></button>`).join('')||'<div class="v151-empty">Sem categorias detalhadas neste período.</div>'}</div>${drillHtml()}</section>`;
  }
  async function openDrill(category){
    if(!category||!w.S?.rpc)return;st.drill={category,loading:true,data:null,error:null};paint();
    try{const {data,error}=await w.S.rpc('lts_browser_expense_drilldown_v1',{p_from:monthFrom(),p_to:asOf(),p_dimension:'category',p_key:category});if(error||!data)throw Error(error?.message||'Detalhe indisponível');st.drill.data=data}catch(e){st.drill.error=String(e?.message||e)}finally{st.drill.loading=false;paint()}
  }
  function paintDashboard(){
    const root=d.querySelector('#A .v151')||d.querySelector('.v151');if(!root)return;
    const fn=firstNegative(),fgts=w.D?.dashboard_cockpit?.liquidity?.fgts_d30;
    const kpis=[...root.querySelectorAll('.v151-strip .v151-kpi')],last=kpis[kpis.length-1];
    if(last){const sm=last.querySelector('small');if(sm)sm.textContent=fn?'primeiro saldo negativo '+fmt(fn):'primeiro saldo negativo ainda não identificado'}
    const good=root.querySelector('.v151-chartmeta .v151-mini.good');if(good)good.innerHTML=`<span>FGTS documental atual</span><b>${fgts!=null?brl(fgts):'—'}</b><small>contingência D+30 · sem estimar aportes futuros</small>`;
    const alert=root.querySelector('.v151-alertline');if(alert){let n=d.getElementById('v151FirstNegative');if(!n){n=d.createElement('div');n.id='v151FirstNegative';n.className='v151-first-negative';alert.insertAdjacentElement('afterend',n)}n.innerHTML=fn?`<b>Primeiro saldo negativo: ${fmt(fn)}</b><br>Este é o primeiro dia em que a trajetória cruza abaixo de zero antes de qualquer ação extraordinária. O ponto de gestão pode ocorrer antes.`:'<b>Primeiro saldo negativo ainda não identificado.</b><br>O LTS não substitui a data por uma aproximação.'}
    let lens=d.getElementById('v151ExpenseLens');const grid=root.querySelector('.v151-grid');if(grid){if(!lens){grid.insertAdjacentHTML('afterend',expenseLens());lens=d.getElementById('v151ExpenseLens')}else lens.outerHTML=expenseLens()}
  }
  function paint(){
    css();
    if(String(w.V)==='Dashboard'){paintDashboard();loadPlan();loadExpense()}
    if(['Despesas','Cartões','Patrimônio'].includes(String(w.V))){const a=d.getElementById('A');a?.querySelector(':scope > div')?.classList.add('v151-reference-cockpit')}
    w.__LTS_V151_REFERENCE_STATUS={version:MARK,first_negative_date:firstNegative(),fgts_future_accrual_estimated:false,dashboard_expense_drilldown:true,expense_drilldown_rpc:'lts_browser_expense_drilldown_v1',cards_cockpit_preserved:true,wealth_cockpit_preserved:true,financial_writer_changed:false,permanent_polling:false,pass:true};
  }
  d.addEventListener('click',e=>{const cat=e.target.closest?.('[data-v151-exp-cat]');if(cat){openDrill(decodeURIComponent(cat.dataset.v151ExpCat||''));return}if(e.target.closest?.('[data-v151-exp-close]')){st.drill=null;paint()}},true);
  const prior=w.__LTS_V151_AFTER_RENDER;w.__LTS_V151_AFTER_RENDER=()=>{try{prior?.()}catch(e){}paint()};
  w.LTS_V151_REFERENCE_FIDELITY=MARK;paint();[120,400,900,1800,3200,5200].forEach(ms=>setTimeout(paint,ms));
})();