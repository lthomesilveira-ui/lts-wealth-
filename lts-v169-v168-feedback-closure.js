(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V169_V168_FEEDBACK?.installed||!window.__LTS_V168_COMPLETE_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio;
    const baseOpenFlowEditor=openFlowEditor,baseFlowEditorInline=flowEditorInline,baseSaveFlowEdit=saveFlowEdit,baseDeleteFlowEvent=deleteFlowEvent;
    const v168=window.__LTS_V168_STATE;
    const state=window.__LTS_V169_STATE||(window.__LTS_V169_STATE={
      monthly:{loading:false,key:'',data:null,error:null,token:0},
      cardBank:'all'
    });
    window.__LTS_V169_V168_FEEDBACK={
      installed:true,version:'v169',base_version:'v168',public_index_changed:false,
      monthly_balance:true,card_future_by_bank:true,paired_transfer_crud:true,
      explicit_passive_layers:true,dashboard_total_emphasis:true,
      historical_card_coverage_disclosed:true
    };

    const arr=v=>Array.isArray(v)?v:[];
    const finite=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc169=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm169=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const brl169=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const date169=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month169=v=>{const key=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
    const today169=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const addMonths169=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)};
    const sum169=xs=>arr(xs).reduce((s,x)=>s+(finite(x)||0),0);
    function template(html){const t=document.createElement('template');t.innerHTML=html;return t}
    function range169(){const s=v168.expense,t=today169(),year=t.slice(0,4),key=s.key;if(key==='6m')return{from:addMonths169(t,-5).slice(0,8)+'01',to:t,label:'Últimos 6 meses'};if(key==='12m')return{from:addMonths169(t,-11).slice(0,8)+'01',to:t,label:'Últimos 12 meses'};if(key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};if(key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom)&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo))return{from:s.customFrom,to:s.customTo,label:date169(s.customFrom)+' a '+date169(s.customTo)};return{from:year+'-01-01',to:t,label:'Ano atual'}}
    function rank169(rows){const xs=arr(rows),top=Math.max(1,...xs.map(x=>Math.abs(finite(x.total)||0)));return '<div class="v168-rank">'+(xs.map(x=>'<div class="v168-rankrow"><b>'+esc169(x.name||x.label||'Outros')+'</b><i><u style="width:'+Math.max(2,Math.abs(finite(x.total)||0)/top*100)+'%"></u></i><strong>'+brl169(x.total)+'</strong></div>').join('')||'<div class="v168-empty">Sem composição para este período.</div>')+'</div>'}

    function findKpi(section,label){return [...section.querySelectorAll('.v168-kpi')].find(x=>norm169(x.querySelector('span')?.textContent)===norm169(label))}
    function markTotal(section,label,newLabel,value,note){section.querySelectorAll('.v168-kpi').forEach(x=>x.classList.remove('primary'));const k=findKpi(section,label);if(!k)return;k.classList.add('primary');if(newLabel)k.querySelector('span').textContent=newLabel;if(value!==undefined)k.querySelector('strong').textContent=brl169(value);if(note)k.querySelector('small').textContent=note}
    function dashboardV169(){
      const t=template(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const sections=[...root.querySelectorAll('.v168-kpi-section')],data=v168.dashboard.data||{},wealth=data.wealth||{},liquidity=wealth.wealth?.liquidity||{},rsu=wealth.rsu_summary||{},flow=data.flow||{},days=arr(flow.flow?.current_future?.days),todayRow=days.find(x=>x.date===today169())||null;
      const availableParts=[finite(todayRow?.Consolidado?.bank_balance),finite(liquidity.d0),finite(rsu.available_total_brl)].filter(x=>x!=null),available=availableParts.length?sum169(availableParts):null;
      if(sections[0])markTotal(sections[0],'Recursos mapeados','Total disponível hoje',available,'contas + D0 + RSUs já disponíveis');
      if(sections[1])markTotal(sections[1],'Compensação futura','Total de posições futuras',finite(rsu.future_considered_total_brl),'RSU + Cash RSU; ainda fora do caixa atual');
      if(sections[2]){
        sections[2].querySelectorAll('.v168-kpi').forEach(x=>x.classList.remove('primary'));
        const pension=findKpi(sections[2],'Previdências'),expense=findKpi(sections[2],'Despesas do período');
        pension?.classList.add('primary');expense?.classList.add('primary');
        if(pension)pension.querySelector('span').textContent='Total em previdências';
        if(expense)expense.querySelector('span').textContent='Total de despesas do período';
      }
      const expenseCard=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||'')),raw=arr(data.expense?.rankings?.categories),coverage=raw.find(x=>/detalhe hist[oó]rico n[aã]o recuperado|faturas hist[oó]ricas sem compras/i.test(String(x.name||x.category||''))),groups=raw.filter(x=>x!==coverage).map(x=>{let name=x.name||x.category||'Outros';if(norm169(name)==='compromissos financeiros')name='Empréstimo consignado · Coopharma';return{name,total:x.total??x.amount}}).slice(0,6);
      if(expenseCard){expenseCard.querySelector('.v168-rank,.v168-empty')?.remove();expenseCard.insertAdjacentHTML('beforeend',rank169(groups)+(coverage?'<div class="v169-coverage"><b>Faturas históricas sem compras individualizadas · '+brl169(coverage.total??coverage.amount)+'</b><span>O total das faturas foi preservado, mas as compras desses ciclos não estão disponíveis. O LTS não inventa estabelecimentos nem categorias.</span></div>':''))}
      return t.innerHTML;
    }

    async function ensureMonthly(force){
      const r=range169(),key=r.from+'|'+r.to,s=state.monthly,changed=s.key!==key;if(!force&&!changed&&(s.loading||s.data))return;
      const token=++s.token;s.loading=true;s.key=key;s.error=null;if(force||changed)s.data=null;
      try{const {data,error}=await S.rpc('lts_browser_monthly_balance_v1',{p_from:r.from,p_to:r.to});if(error||!data)throw Error(error?.message||'Balanço mensal indisponível');if(token===s.token)s.data=data}catch(e){if(token===s.token)s.error=String(e?.message||e)}finally{if(token===s.token){s.loading=false;if(V==='Despesas'&&v168.expense.tab==='monthly')render()}}
    }
    function monthlyMatrix(title,subtitle,groups,kind){const data=state.monthly.data||{},months=arr(data.months);return '<article class="v169-balance-section '+kind+'"><div class="v168-cardhead"><div><span>'+esc169(subtitle)+'</span><h2>'+esc169(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+esc169(month169(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(g=>'<tr><th><b>'+esc169(g.label)+'</b><small>'+esc169(String(g.source_rows||0))+' origem(ns)</small></th>'+arr(g.monthly).map(x=>'<td class="'+((finite(x.amount)||0)<0?'negative':'')+'">'+((finite(x.amount)||0)?brl169(x.amount):'—')+'</td>').join('')+'<td class="total">'+brl169(g.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>'}
    function monthlyPanel(){
      ensureMonthly(false);const s=state.monthly,j=s.data||{},tot=j.totals||{},months=arr(j.monthly_totals),coverage=j.coverage||{};
      if(s.loading&&!s.data)return '<div class="v168-skeleton" aria-label="Carregando balanço mensal"></div>';
      if(s.error&&!s.data)return '<div class="v168-error">'+esc169(s.error)+'</div><button class="v168-btn primary" data-v169-month-retry>Tentar novamente</button>';
      const balance=finite(tot.operating_balance)||0,cash=finite(tot.cash_after_extraordinary)||0;
      return '<div class="v169-monthly"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total de receitas</span><strong>'+brl169(tot.revenue)+'</strong><small>entradas recorrentes e operacionais</small></article><article class="v168-kpi"><span>Total de despesas</span><strong>'+brl169(tot.expenses)+'</strong><small>consumo por competência</small></article><article class="v168-kpi '+(balance<0?'v169-negative':'')+'"><span>Saldo mensal operacional</span><strong>'+brl169(balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+brl169(tot.extraordinary)+'</strong><small>empréstimos, FGTS e venda de bens</small></article><article class="v168-kpi '+(cash<0?'v169-negative':'')+'"><span>Saldo após extraordinárias</span><strong>'+brl169(cash)+'</strong><small>explica a cobertura pontual de caixa</small></article></div><div class="v169-month-cards">'+months.map(x=>'<article class="'+((finite(x.operating_balance)||0)<0?'negative':'positive')+'"><span>'+esc169(month169(x.month))+'</span><dl><dt>Receitas</dt><dd>'+brl169(x.revenue)+'</dd><dt>Despesas</dt><dd>'+brl169(x.expenses)+'</dd><dt>Saldo operacional</dt><dd>'+brl169(x.operating_balance)+'</dd><dt>Extraordinárias</dt><dd>'+brl169(x.extraordinary)+'</dd></dl></article>').join('')+'</div>'+monthlyMatrix('Receitas mês a mês','Parte de cima',arr(j.revenue_groups),'revenue')+monthlyMatrix('Entradas extraordinárias','Separadas das receitas',arr(j.extraordinary_groups),'extraordinary')+monthlyMatrix('Principais grupos de despesa','Parte de baixo',arr(j.expense_groups),'expense')+monthlyTotalsTable(months)+'<div class="v169-coverage"><b>Como este balanço evita dupla contagem</b><span>Transferências internas, aplicações e pagamentos de fatura não entram como consumo. As compras de cartão entram uma única vez. Entradas extraordinárias ficam separadas das receitas.</span>'+(finite(coverage.historical_invoice_aggregate)>0?'<span><strong>'+brl169(coverage.historical_invoice_aggregate)+'</strong> em faturas históricas têm o total preservado, mas não compras individualizadas ('+esc169(coverage.historical_invoice_months||0)+' competência(s)).</span>':'')+'</div></div>';
    }
    function monthlyTotalsTable(rows){return '<article class="v169-balance-section totals"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Saldo de cada mês</h2></div><small>positivo ou negativo</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Saldo operacional</th><th>Extraordinárias</th><th>Saldo após extraordinárias</th></tr></thead><tbody>'+rows.map(x=>'<tr><th>'+esc169(month169(x.month))+'</th><td>'+brl169(x.revenue)+'</td><td>'+brl169(x.expenses)+'</td><td class="'+((finite(x.operating_balance)||0)<0?'negative':'positive')+'">'+brl169(x.operating_balance)+'</td><td>'+brl169(x.extraordinary)+'</td><td class="'+((finite(x.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+brl169(x.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article>'}

    function cardBank(name){const n=norm169(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau'))return'Itaú';return'Outros'}
    function cardsPanel169(){
      const o=D?.card_operating||{},filter=state.cardBank,match=x=>filter==='all'||cardBank(x.card_name||x.description)===filter,cycles=[...arr(o.open_cycles).map(x=>({...x,stateLabel:'Fatura aberta'})),...arr(o.closed_or_due).map(x=>({...x,stateLabel:x.state==='payment_evidence_needed'?'Fechada · pagamento a confirmar':'Fatura fechada'}))].filter(match),floors=arr(o.contracted_installment_floor_months),map=new Map(),ensure=m=>{const key=String(m).slice(0,7);if(!map.has(key))map.set(key,{month:key,invoices:[],installments:[]});return map.get(key)};
      cycles.forEach(x=>{const key=String(x.due_date||'').slice(0,7);if(key)ensure(key).invoices.push(x)});floors.forEach(m=>arr(m.detail).filter(match).forEach(x=>ensure(m.reference_month).installments.push({...x,reference_month:m.reference_month})));
      const rows=[...map.values()].filter(x=>x.month>=today169().slice(0,7)).sort((a,b)=>a.month.localeCompare(b.month)),openTotal=sum169(cycles.map(x=>x.amount)),floorTotal=sum169(rows.flatMap(x=>x.installments).map(x=>x.amount)),consideredTotal=sum169(rows.map(x=>x.invoices.length?sum169(x.invoices.map(y=>y.amount)):sum169(x.installments.map(y=>y.amount)))),banks=['all','Itaú','Bradesco','C6'];
      return '<div class="v169-cards"><div class="v169-bank-filter" role="tablist" aria-label="Filtrar cartões por banco">'+banks.map(x=>'<button type="button" class="v168-btn '+(filter===x?'primary':'')+'" data-v169-card-bank="'+esc169(x)+'">'+(x==='all'?'Todos os bancos':esc169(x))+'</button>').join('')+'</div><div class="v168-kpis"><article class="v168-kpi primary"><span>Considerado no Fluxo</span><strong>'+brl169(consideredTotal)+'</strong><small>fatura quando conhecida; senão piso contratado</small></article><article class="v168-kpi"><span>Faturas abertas/fechadas</span><strong>'+brl169(openTotal)+'</strong><small>'+cycles.length+' ciclo(s) no filtro</small></article><article class="v168-kpi"><span>Piso futuro contratado</span><strong>'+brl169(floorTotal)+'</strong><small>parcelas já conhecidas</small></article><article class="v168-kpi"><span>Meses à frente</span><strong>'+esc169(rows.length)+'</strong><small>'+esc169(filter==='all'?'todos os bancos':filter)+'</small></article></div><article class="v168-card"><div class="v168-cardhead"><div><span>Conferência com o banco</span><h2>Valores futuros mês a mês</h2></div><small>'+esc169(filter==='all'?'visão consolidada':filter)+'</small></div><div class="v169-card-months">'+(rows.map(x=>{const invoice=sum169(x.invoices.map(y=>y.amount)),floor=sum169(x.installments.map(y=>y.amount)),considered=x.invoices.length?invoice:floor,source=x.invoices.length?'Fatura já observada':'Piso das parcelas contratadas',details=[...x.invoices.map(y=>(y.card_name||'Cartão')+' · '+y.stateLabel),...x.installments.map(y=>(y.card_name||'Cartão')+' · parcela conhecida')];return '<div class="v169-card-month"><div><span>'+esc169(month169(x.month))+'</span><b>'+esc169(source)+'</b><small>'+esc169(details.join(' · ')||'Sem detalhe')+'</small></div><dl><dt>Fatura conhecida</dt><dd>'+brl169(invoice)+'</dd><dt>Piso parcelado</dt><dd>'+brl169(floor)+'</dd><dt>Valor usado no Fluxo</dt><dd><strong>'+brl169(considered)+'</strong></dd></dl></div>'}).join('')||'<div class="v168-empty">Nenhum valor futuro documentado para este banco.</div>')+'</div></article><div class="v169-coverage"><b>Regra de conferência</b><span>Quando já existe uma fatura observada, ela é o valor usado no Fluxo. Nos meses ainda sem fatura, o LTS mostra o piso das parcelas contratadas; compras novas podem aumentar o valor final.</span></div></div>';
    }
    function expensesV169(){
      const t=template(baseExpenses()),root=t.content.querySelector('.v168-expenses'),tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(!tabs.querySelector('[data-v168-exp-tab="monthly"]'))tabs.insertAdjacentHTML('beforeend','<button type="button" role="tab" aria-selected="'+(v168.expense.tab==='monthly')+'" class="'+(v168.expense.tab==='monthly'?'active':'')+'" data-v168-exp-tab="monthly">Balanço mensal</button>');
      if(v168.expense.tab==='monthly'||v168.expense.tab==='cards'){
        let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next}
        tabs.insertAdjacentHTML('afterend',v168.expense.tab==='monthly'?monthlyPanel():cardsPanel169());
      }
      return t.innerHTML;
    }

    function commitment(j,id){return arr(j.financing?.summary?.commitments).find(x=>x.id===id)||{}}
    function obligationValue(x){return finite(x.remaining_scheduled_outflow_current_terms??x.remaining_scheduled_outflow??x.remaining_economic_outflow)}
    function wealthV169(){
      const html=baseWealth(),t=template(html),root=t.content.querySelector('.v168-wealth'),j=v168.wealth.data||{};if(!root||v168.wealth.tab!=='overview'||!j.wealth)return t.innerHTML;
      const summary=j.wealth.summary||{},c=j.wealth.assets?.cipo_396||{},v=j.wealth.assets?.volvo_xc40||{},co=commitment(j,'coopharma'),family=commitment(j,'pai_mae'),coValue=obligationValue(co),familyValue=obligationValue(family),obligations=[{name:'Empréstimo consignado · Coopharma',total:coValue,note:(co.remaining_events??'—')+' parcela(s) remanescente(s)'},{name:'Empréstimo familiar · Pai e Mãe',total:familyValue,note:(family.remaining_events??'—')+' parcela(s) remanescente(s)'}],obligationTotal=sum169(obligations.map(x=>x.total));
      const kpis=root.querySelector('.v168-kpis');if(kpis){const debt=findKpi(kpis,'Dívidas atuais');if(debt){debt.querySelector('span').textContent='Dívidas com saldo atual';debt.querySelector('small').textContent='quitação documental · CIPÓ + Volvo'}debt?.insertAdjacentHTML('afterend','<article class="v168-kpi"><span>Obrigações remanescentes</span><strong>'+brl169(obligationTotal)+'</strong><small>Coopharma + Pai e Mãe · cronogramas, não saldo de quitação</small></article>')}
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/^passivos$/i.test(x.querySelector('.v168-cardhead span')?.textContent||''));if(card){const head=card.querySelector('.v168-cardhead');head.querySelector('h2').textContent='Dívidas e obrigações remanescentes';const strong=head.querySelector('strong');if(strong)strong.textContent=brl169(summary.known_debt_total);[...card.children].filter(x=>x!==head).forEach(x=>x.remove());card.insertAdjacentHTML('beforeend','<div class="v169-passives"><section><div class="v169-passive-title"><b>Saldo de quitação documentado</b><strong>'+brl169(summary.known_debt_total)+'</strong></div>'+rank169([{name:'Financiamento imobiliário · CIPÓ 396',total:c.documentary_debt},{name:'Financiamento do Volvo XC40',total:v.documented_financed_balance}].filter(x=>(finite(x.total)||0)>0))+'</section><section><div class="v169-passive-title"><b>Obrigações sem saldo de quitação informado</b><strong>'+brl169(obligationTotal)+'</strong></div><div class="v168-statlist">'+obligations.map(x=>'<div class="v168-stat"><span><b>'+esc169(x.name)+'</b><small>'+esc169(x.note)+'</small></span><b>'+brl169(x.total)+'</b></div>').join('')+'</div></section><div class="v169-coverage"><b>Critério financeiro</b><span>Coopharma e Pai e Mãe agora aparecem nos passivos. Como só há cronogramas remanescentes — e não saldos atuais de quitação — esses totais não são somados ao patrimônio líquido central para evitar tratar juros futuros como principal atual.</span></div></div>')}
      return t.innerHTML;
    }

    const isTransfer=e=>e?.source==='internal_transfer'&&e?.confidence==='user_flow_editable'&&String(e?.source_ref||'').startsWith('financial_events:');
    openFlowEditor=async function(e,mode='edit'){
      if(!isTransfer(e))return baseOpenFlowEditor(e,mode);
      const anchor=e.event_date;EXP.add(anchor);FLOWEDIT={event:e,anchor_date:anchor,mode:'edit',loading:true,error:null,data:{kind:'internal_transfer_pair'},parts:[]};render();
      const {data,error}=await S.rpc('lts_browser_internal_transfer_editor_v1',{p_source_ref:e.source_ref});
      if(error||!data?.editable){FLOWEDIT={...FLOWEDIT,loading:false,error:error?.message||data?.reason||'Esta transferência não pode ser editada.'};render();return}
      FLOWEDIT={event:e,anchor_date:anchor,mode:'edit',loading:false,error:null,data,parts:[]};render();
    };
    flowEditorInline=function(day){
      if(FLOWEDIT?.data?.kind!=='internal_transfer_pair')return baseFlowEditorInline(day);
      if(FLOWEDIT.anchor_date!==day)return'';if(FLOWEDIT.loading)return'<div class="flowedit-panel"><div class="mut">Carregando a transferência completa…</div></div>';if(FLOWEDIT.error)return'<div class="flowedit-panel"><div class="notice">'+esc169(FLOWEDIT.error)+'</div><button id="flowEditClose" class="btn ghost" style="margin-top:8px">Fechar</button></div>';
      const d=FLOWEDIT.data||{},accounts=['Itaú','Bradesco','C6'];return '<div class="flowedit-panel v169-transfer-editor"><div class="flowedit-head"><div><div class="title">Editar transferência entre contas</div><div class="mut">'+date169(d.event_date)+' · duas pernas vinculadas · efeito consolidado R$ 0,00</div></div><button id="flowEditClose" class="btn ghost">Fechar</button></div><div class="flowedit-grid"><label>Data<input id="flowEditDate" type="date" value="'+esc169(d.event_date)+'"></label><label>Valor<input id="flowEditAmount" type="number" min="0.01" step="0.01" value="'+esc169(d.amount)+'"></label><label>Conta de origem<select id="v169TransferFrom">'+accounts.map(a=>'<option '+(a===d.from_account?'selected':'')+'>'+a+'</option>').join('')+'</select></label><label>Conta de destino<select id="v169TransferTo">'+accounts.map(a=>'<option '+(a===d.to_account?'selected':'')+'>'+a+'</option>').join('')+'</select></label><label class="wide">Descrição<input id="flowEditDesc" value="'+esc169(d.description||'')+'"></label></div><div class="flowedit-hint"><b>Operação atômica:</b> salvar atualiza simultaneamente a saída e a entrada. Excluir cancela as duas pernas. O histórico original permanece na auditoria.</div><div class="flowedit-actions"><button id="flowEditSave" class="btn">Salvar transferência</button><button id="flowEditCancelProjection" class="btn ghost danger-text">Excluir transferência</button></div></div>';
    };
    saveFlowEdit=async function(cancelOnly=false){
      if(FLOWEDIT?.data?.kind!=='internal_transfer_pair')return baseSaveFlowEdit(cancelOnly);if(FLOWEDITSAVING)return;const d=FLOWEDIT.data,action=cancelOnly?'cancel':'edit';let payload={};
      if(action==='edit'){payload={event_date:document.getElementById('flowEditDate')?.value,amount:Number(document.getElementById('flowEditAmount')?.value),from_account:document.getElementById('v169TransferFrom')?.value,to_account:document.getElementById('v169TransferTo')?.value,description:document.getElementById('flowEditDesc')?.value.trim()};if(!payload.event_date||!Number.isFinite(payload.amount)||payload.amount<=0||!payload.description||payload.from_account===payload.to_account){alert('Revise data, valor, descrição e use contas de origem e destino diferentes.');return}}
      if(action==='cancel'&&!confirm('Excluir esta transferência do Fluxo? A saída e a entrada serão canceladas juntas e o registro original ficará preservado para auditoria.'))return;
      FLOWEDITSAVING=true;const b=document.getElementById('flowEditSave');if(b){b.disabled=true;b.textContent='Salvando…'}try{const key='transfer-'+action+'-'+(crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2)),{data,error}=await S.rpc('lts_browser_internal_transfer_mutate_v1',{p_action:action,p_source_ref:d.source_ref,p_payload:payload,p_idempotency_key:key});if(error||!data?.ok)throw Error(error?.message||'Não foi possível salvar a transferência.');FLOWEDIT=null;await loadFlowRange(FLOWFROM||today169(),FLOWTO||today169())}catch(e){alert('Falha ao ajustar transferência: '+String(e?.message||e))}finally{FLOWEDITSAVING=false;if(V==='Fluxo Diário')render()}
    };
    deleteFlowEvent=async function(e,b){
      if(!isTransfer(e))return baseDeleteFlowEvent(e,b);if(!confirm('Excluir esta transferência do Fluxo? A saída e a entrada serão canceladas juntas e o registro original ficará preservado para auditoria.'))return;const old=b?.textContent||'Excluir';if(b){b.disabled=true;b.textContent='Excluindo…'}try{const key='transfer-cancel-'+(crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2)),{data,error}=await S.rpc('lts_browser_internal_transfer_mutate_v1',{p_action:'cancel',p_source_ref:e.source_ref,p_payload:{},p_idempotency_key:key});if(error||!data?.ok)throw Error(error?.message||'Não foi possível excluir.');FLOWEDIT=null;await loadFlowRange(FLOWFROM||today169(),FLOWTO||today169())}catch(err){alert('Falha ao excluir transferência: '+String(err?.message||err));if(b){b.disabled=false;b.textContent=old}}
    };
    function decorateTransferActions(){if(V!=='Fluxo Diário'||typeof mergedFlowEvents!=='function')return;const events=mergedFlowEvents();document.querySelectorAll('.floweditbtn[data-mode="duplicate"]').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.remove()});document.querySelectorAll('.floweditbtn[data-mode="edit"]').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.textContent='Editar transferência'});document.querySelectorAll('.flowdeletebtn').forEach(b=>{const e=events.find(x=>flowEventKey(x)===b.dataset.ekey);if(isTransfer(e))b.textContent='Excluir transferência'})}

    function bind169(){
      document.querySelectorAll('[data-v169-card-bank]').forEach(b=>b.onclick=()=>{state.cardBank=b.dataset.v169CardBank;render()});
      document.querySelector('[data-v169-month-retry]')?.addEventListener('click',()=>ensureMonthly(true));
      document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const old=b.onclick;b.onclick=e=>{state.monthly.data=null;state.monthly.key='';state.monthly.error=null;return old?.call(b,e)}});
      const apply=document.getElementById('v168ExpenseApply');if(apply){const old=apply.onclick;apply.onclick=e=>{state.monthly.data=null;state.monthly.key='';state.monthly.error=null;return old?.call(apply,e)}}
      decorateTransferActions();
    }
    function stamp(){document.querySelectorAll('.brand small').forEach(n=>n.innerHTML='<b>V169</b> · Homologação');document.querySelectorAll('.v168-release').forEach(n=>n.textContent='V169 · Homologação');const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent='V169 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação'}
    function after(){stamp();bind169()}
    dashboard=dashboardV169;despesas=expensesV169;patrimonio=wealthV169;
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();stamp();return out};
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;if(!f.w.__LTS_V168_COMPLETE_REVIEW?.installed)return false;if(!f.d.getElementById('lts-v169-style')){const l=f.d.createElement('link');l.id='lts-v169-style';l.rel='stylesheet';l.href='lts-v169-v168-feedback-closure.css?v=20260916-v169a';f.d.head.appendChild(l)}if(!f.w.__LTS_V169_V168_FEEDBACK?.installed&&!f.d.getElementById('lts-v169-runtime')){const s=f.d.createElement('script');s.id='lts-v169-runtime';s.textContent='('+runtime.toString()+')();';f.d.head.appendChild(s)}const ready=f.w.__LTS_V169_V168_FEEDBACK?.installed===true;if(ready&&gate)gate.hidden=true;if(ready&&scope)scope.textContent='V169 · Homologação';return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v169-v168-feedback-closure';
})();
