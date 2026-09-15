/* Existing V162 executive/monthly Despesas integration. No financial writes,
 * added frames, background polling or persistent storage. */
(function () {
  'use strict';
  function runtime() {
    'use strict';
    if (window.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed) return;
    const M = window.parent.LTSExpenseReadModel;
    if (!M || typeof ex135State !== 'function' || typeof despesas !== 'function') return;
    const status = window.__LTS_EXPENSE_SCREEN_ALIGNMENT = {installed:true,version:'current-executive-screen-v2',financial_writes:0,lastDetailParity:null};
    let route=V,product=D,executiveKey=null,monthSelection=null,fullMonth=null;
    function state() { return window.EX135 || (window.EX135={rangeKey:'ytd',winKey:'6m',loading:false,error:null,data:null,key:null,month:null,monthData:null,monthLoading:false,monthError:null,monthCategory:null}); }
    function sumCents(items, field) { return items.reduce((n,x)=>{const v=n+M.cents(x[field]);if(!Number.isSafeInteger(v))throw Error('Unsafe total');return v;},0); }
    function adaptExecutive(payload, request) {
      if(payload?.version!=='expense-executive-v12-cached-effective-contract')throw Error('Unexpected report contract');
      const scope=M.rangeSelection(payload.period);
      if(JSON.stringify(scope)!==JSON.stringify(request))throw Error('Wrong report interval');
      if(!payload.summary || !Array.isArray(payload.monthly_detail) || !Array.isArray(payload.yearly_detail))throw Error('Missing report detail');
      const total=M.cents(payload.summary.selected_total),known=M.cents(payload.data_quality?.selected_category_unallocated_total),seen=new Set();
      if(sumCents(payload.monthly_detail,'total')!==total || M.cents(payload.summary.account_total)+M.cents(payload.summary.card_total)!==total)throw Error('Report totals disagree');
      for(const m of payload.monthly_detail){
        M.date(m.month);if(!m.month.endsWith('-01') || seen.has(m.month)||m.month.slice(0,7)<scope.from.slice(0,7)||m.month.slice(0,7)>scope.to.slice(0,7))throw Error('Invalid report month');seen.add(m.month);
        if(!Number.isSafeInteger(m.rows)||m.rows<0||M.cents(m.card_total)+M.cents(m.account_total)!==M.cents(m.total))throw Error('Monthly total mismatch');
      }
      if(known<0)throw Error('Invalid coverage amount');
      const legacy=JSON.parse(JSON.stringify(payload));
      for(const m of legacy.monthly_detail)if(m.is_partial===true){m.mom_comparison_pct=null;m.yoy_comparison_pct=null;}
      for(const k of ['3m','6m','12m']){
        const w=legacy.rolling_windows?.[k];if(!w || !Array.isArray(w.top_categories))throw Error('Missing rolling window');
        M.cents(w.total);M.cents(w.known_category_total);M.cents(w.financing_total);
        w.top_categories.sort((a,b)=>M.cents(b.total)-M.cents(a.total));
      }
      return Object.freeze({legacy,scope,totalCents:total,sourceParityVerified:false});
    }
    function expectedThrough(month){const d=new Date(month+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+1,0);return [today(),d.toISOString().slice(0,10)].sort()[0];}
    function resetMonth(){monthSelection=null;fullMonth=null;const s=state();s.month=null;s.monthData=null;s.monthModel=null;s.monthCategory=null;s.monthLoading=false;s.monthError=null;monthSession.invalidate();}
    const executiveSession=M.createReadSession({selection:M.rangeSelection,load:r=>S.rpc('lts_browser_expense_executive_v3',{p_from:r.from,p_to:r.to}),adapt:adaptExecutive});
    const monthSession=M.createReadSession({load:r=>S.rpc('lts_browser_expense_month_detail_v2',{p_month:r.month,p_category:r.category}),adapt(payload,requested){
      const model=M.normalizeMonth(payload,requested);if(!model.internallyConsistent)throw Error('Monthly detail not consistent');
      const base=state().data?.monthly_detail?.find(m=>m.month===model.scope.month);
      if(model.scope.category===null){
        if(!base || M.cents(base.total)!==model.actualTotalCents || base.rows!==model.rows.length)throw Error('Summary and month differ');
        fullMonth=model;
      }else if(fullMonth?.scope.month===model.scope.month){
        const cat=fullMonth.categories.find(c=>c.name===model.scope.category);
        if(!cat || cat.totalCents!==model.actualTotalCents || cat.rows!==model.rows.length)throw Error('Category and detail differ');
      }
      status.lastDetailParity=true;return Object.freeze({...model,legacy:payload});
    }});
    executiveSession.subscribe(s=>{const v=state();v.loading=s.phase==='loading';v.phase=s.phase;v.error=['error','authentication_required'].includes(s.phase)?s.message:null;v.data=s.model?.legacy||null;v.key=executiveKey;if(V==='Despesas')render();});
    monthSession.subscribe(s=>{const v=state();v.monthLoading=s.phase==='loading';v.monthPhase=s.phase;v.monthError=['error','authentication_required'].includes(s.phase)?s.message:null;v.monthData=s.model?.legacy||null;v.monthModel=s.model||null;if(V==='Despesas')render();});
    ex135Load=function(k){const s=state();s.rangeKey=k||s.rangeKey||'ytd';const r=ex135Range(s.rangeKey);executiveKey=r.from+'|'+r.to;s.key=executiveKey;resetMonth();return executiveSession.select({from:r.from,to:r.to});};
    ex135State=function(){const s=state(),r=ex135Range(s.rangeKey||'ytd'),key=r.from+'|'+r.to;if(executiveKey!==key)ex135Load(s.rangeKey);return s;};
    ex135SetRange=function(k){if(state().rangeKey===k && state().data)return;return ex135Load(k);};
    ex135OpenMonth=function(month,category=null){M.date(month);const s=state();if(!s.data)return;status.lastDetailParity=null;s.month=month;s.monthCategory=category;monthSelection={month,through:expectedThrough(month),category};return monthSession.select(monthSelection);};
    ex135CloseMonth=function(){resetMonth();if(V==='Despesas')render();};
    const oldRank=ex135Rank;
    ex135Rank=function(items,known,limit){return oldRank([...(items||[])].sort((a,b)=>Number(b.total)-Number(a.total)),known,limit);};
    ex135MonthDetail=function(s){
      if(!s.month)return '';
      if(s.monthLoading)return '<div class="ex135-detail" role="status">Carregando o mês selecionado…</div>';
      if(s.monthError)return `<div class="ex135-detail"><b>Não foi possível conferir o detalhamento.</b><p>${esc(s.monthError)}</p><button class="chip" data-exp-close>Fechar</button></div>`;
      const d=s.monthModel;if(!d)return '';
      const categories=fullMonth?.scope.month===d.scope.month?fullMonth.categories:d.categories;
      const provisional=d.rows.some(r=>r.sourceTable==='card_invoice_current_items');
      const textDate=r=>r.transactionDate?fmt(r.transactionDate):r.originType==='cartão'?'Data original não informada':r.detailLevel==='transaction'?fmt(r.eventDate):'Composição histórica';
      return `<div class="ex135-detail"><div class="ex135-detailhead"><div><span class="ex135-eye">Lançamentos do mês</span><h3>${esc(ex135MonthLabel(d.scope.month,true))}${d.partial?' · parcial':''}</h3><div class="mut">${d.scope.category?'Categoria '+esc(d.scope.category)+' · ':''}${d.rows.length} linha(s) · ${brl(d.actualTotalCents/100)}</div></div><button class="chip" data-exp-close>Fechar</button></div>${provisional?'<div class="notice">Inclui fatura aberta. A posição é provisória e pode mudar até o fechamento; não representa pagamento confirmado.</div>':''}<div class="ex135-detailcats"><button data-exp-category="-1" class="${d.scope.category===null?'active':''}">Tudo</button>${categories.map((c,i)=>`<button data-exp-category="${i}" class="${d.scope.category===c.name?'active':''}">${esc(c.name)} · ${brl(c.totalCents/100)}</button>`).join('')}</div><div class="ex135-items">${d.rows.slice(0,180).map(r=>`<div class="ex135-item"><span>${esc(textDate(r))}</span><div><b>${esc(r.counterparty||'Contraparte não informada')}</b><span>${esc(r.category)} · ${esc(r.originName)} · ${r.detailLevel==='category_only'?'composição histórica por categoria':r.detailLevel==='total_only'?'total histórico sem compras individuais':'lançamento individual'}${r.sourceTable==='card_invoice_current_items'?' · fatura aberta':''}</span>${r.centerCost && r.centerCost!=='Não atribuído'?'<span>Centro de custo: '+esc(r.centerCost)+'</span>':''}</div><strong>${brl(r.amountCents/100)}</strong></div>`).join('')||'<div class="empty">Sem linhas no resultado.</div>'}</div>${d.rows.length>180?`<div class="mut">Exibindo 180 de ${d.rows.length} linhas. Selecione uma categoria para reduzir o resultado.</div>`:''}</div>`;
    };
    const oldView=despesas;
    despesas=function(){
      const html=oldView(),s=state();if(!s.data||s.loading||s.error)return html;
      const q=D?.expense_universe_qa,asof=q?.bank_documented_through,scope=s.data.period;
      const opened=(D?.expense_drilldown?.rows||[]).filter(r=>r.source_table==='card_invoice_current_items'&&String(r.competence_month||'').slice(0,7)>=scope.from.slice(0,7)&&String(r.competence_month||'').slice(0,7)<=scope.to.slice(0,7));
      return `<div class="notice lts-exp-source-notice" role="status">${asof?'Base bancária documentada até '+esc(fmt(asof))+'. ':''}Cartões por competência da fatura; movimentos bancários por data de caixa. ${opened.length?'Inclui fatura aberta: posição provisória. Comparações de mês parcial aguardam períodos equivalentes. ':''}Categoria definida não significa detalhe individual disponível em todo o histórico.</div>`+html;
    };
    const oldRender=render;
    render=function(){
      const leaving=route==='Despesas'&&V!=='Despesas',changed=product!==D;
      route=V;product=D;
      if(leaving||changed){executiveKey=null;resetMonth();executiveSession.invalidate();}
      const value=oldRender(),s=state();
      document.querySelectorAll('[data-exp-close]').forEach(b=>b.onclick=ex135CloseMonth);
      const cats=fullMonth?.scope.month===s.month?fullMonth.categories:s.monthModel?.categories||[];
      document.querySelectorAll('[data-exp-category]').forEach(b=>b.onclick=()=>ex135OpenMonth(s.month,b.dataset.expCategory==='-1'?null:cats[Number(b.dataset.expCategory)]?.name));
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=V==='Despesas'?'Despesas · homologação':'Fluxo Diário · homologação';return value;
    };
    const style=document.createElement('style');style.id='lts-expense-source-alignment-style';style.textContent='.lts-exp-source-notice{font-size:12px;line-height:1.55;margin-bottom:14px}.ex135-detailcats{max-height:210px;overflow:auto}.ex135-item>span{white-space:normal;overflow-wrap:anywhere}.ex135-item>div{min-width:0;overflow-wrap:anywhere}.ex135-detail .notice{font-size:12px;line-height:1.5}';document.head.appendChild(style);
    if(V==='Despesas')render();
  }
  const frame=document.getElementById('shell');
  function install(){try{const doc=frame?.contentDocument;if(!doc||!frame.contentWindow?.location.pathname.endsWith('/index.html')||doc.getElementById('lts-expense-source-alignment'))return;const s=doc.createElement('script');s.id='lts-expense-source-alignment';s.textContent='('+runtime.toString()+')();';(doc.head||doc.documentElement).appendChild(s);}catch(_){/* Same-origin frame may still be navigating. Its load event retries installation. */}}
  frame?.addEventListener('load',install);if(frame?.contentDocument?.readyState==='complete')install();
})();
