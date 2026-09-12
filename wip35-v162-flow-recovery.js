(function(){
  'use strict';
  const CONTRACT='v150-flow-direct-current-read-v3';
  const TARGET_RPC='lts_browser_flow_v11';
  const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let bootGeneration=0;
  function recoveryRuntime(){
    'use strict';
    const CONTRACT='v150-flow-direct-current-read-v3';
    const TARGET_RPC='lts_browser_flow_v11';
    const TARGET_MUTATION_RPC='lts_browser_flow_mutate_v2';
    if(window.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true)return;
    const calls=[];
    const status=window.__LTS_V162_FLOW_RECOVERY_STATUS={installed:true,contract:CONTRACT,baseline:'Protected index V150 Flow component',route:null,data_rpc:TARGET_RPC,legacy_flow_reads_mapped:true,public_index_changed:false,mutation_rpc:TARGET_MUTATION_RPC,financial_writer_changed:false,dashboard_in_scope:false,bounded_boot:true,permanent_polling:false,refresh_requested:false,last_flow_done:false,last_flow_ok:false,last_flow_error:null,calls};
    const baseRpc=S.rpc.bind(S);
    async function mappedRpc(name,args){
      const requested=String(name||'');
      const mapped=(requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4')?TARGET_RPC:requested==='lts_browser_flow_mutate_v1'?TARGET_MUTATION_RPC:requested;
      calls.push({requested,mapped,at:new Date().toISOString()});if(calls.length>40)calls.shift();
      try{
        const result=await baseRpc(mapped,args);
        if(mapped===TARGET_RPC){status.last_flow_rpc=mapped;status.last_flow_done=true;status.last_flow_ok=!result?.error&&!!result?.data?.flow;status.last_flow_error=result?.error?.message||(!result?.data?.flow?'Resposta do Fluxo sem dados':null);status.last_flow_at=new Date().toISOString()}
        return result;
      }catch(error){
        if(mapped===TARGET_RPC){status.last_flow_rpc=mapped;status.last_flow_done=true;status.last_flow_ok=false;status.last_flow_error=String(error?.message||error||'Falha de leitura');status.last_flow_at=new Date().toISOString()}
        throw error;
      }
    }
    mappedRpc.__ltsV162FlowBridge=true;S.rpc=mappedRpc;
    const DEFAULT_RANGE_CONTRACT='previous-5-today-next-30-v1';
    const DEFAULT_RANGE_LABEL='5 anteriores + 30 próximos';
    let flowRequestSequence=0,lastRenderedRoute=V;
    status.default_range_contract=DEFAULT_RANGE_CONTRACT;status.default_range_applied=false;
    function defaultRange(){const day=today();const shift=offset=>{const date=new Date(day+'T12:00:00Z');date.setUTCDate(date.getUTCDate()+offset);return date.toISOString().slice(0,10)};return {from:shift(-5),to:shift(30)}}
    function useDefaultState(){const range=defaultRange();FLOWPRESET=DEFAULT_RANGE_LABEL;SHOWZERO=true;FLOWFORCEZERO=false;FLOWYEAR=Number(today().slice(0,4));status.default_range_applied=true;status.default_range=range;return range}
    loadFlowRange=async function(from,to){
      if(!status.default_range_applied){const range=useDefaultState();from=range.from;to=range.to}
      const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''));if(!valid(from)||!valid(to)||from>to)return;
      const sequence=++flowRequestSequence;FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;status.refresh_requested=true;status.last_flow_done=false;status.last_flow_ok=false;status.requested_range={from,to};if(V==='Fluxo Diário')render();
      try{
        const {data,error}=await S.rpc('lts_browser_flow_v3',{p_from:from,p_to:to});if(sequence!==flowRequestSequence)return;
        if(error||!data?.flow)throw new Error(error?.message||'Resposta do Fluxo sem dados');
        FLOWQ=data.flow;status.last_flow_ok=true;status.last_flow_error=null;status.loaded_range={from,to};
      }catch(error){if(sequence!==flowRequestSequence)return;status.last_flow_ok=false;status.last_flow_error=String(error?.message||error||'Falha de leitura');FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}}}
      finally{if(sequence===flowRequestSequence){FLOWLOADING=false;status.last_flow_done=true;if(V==='Fluxo Diário')render()}}
    };
    function openDefaultRange(){const range=useDefaultState();return loadFlowRange(range.from,range.to)}
    function bindDefaultRange(){
      if(V!=='Fluxo Diário')return;
      const first=document.querySelector('[data-p]');
      if(first&&!document.getElementById('flowDefaultRange')){const button=document.createElement('button');button.id='flowDefaultRange';button.type='button';button.className='chip';button.textContent=DEFAULT_RANGE_LABEL;button.title='Cinco dias anteriores, hoje e os próximos 30 dias';first.parentNode.insertBefore(button,first)}
      const button=document.getElementById('flowDefaultRange');if(button){const range=defaultRange(),active=FLOWFROM===range.from&&FLOWTO===range.to;button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));button.onclick=openDefaultRange}
      document.querySelectorAll('[data-p="Hoje"]').forEach(node=>node.remove());const go=document.getElementById('goToday');if(go)go.onclick=()=>openDefaultRange();
    }
    const preservedRender=render;
    render=function(){const entered=V==='Fluxo Diário'&&lastRenderedRoute!=='Fluxo Diário';lastRenderedRoute=V;preservedRender();bindDefaultRange();if(entered&&D&&status.default_range_applied){queueMicrotask(()=>{if(V==='Fluxo Diário')openDefaultRange()})}};
    const preservedRenderNav=renderNav;
    renderNav=function(){preservedRenderNav();const button=document.querySelector('.nav [data-v="Fluxo Diário"]');if(button)button.onclick=()=>{V='Fluxo Diário';lastRenderedRoute=V;renderNav();openDefaultRange()}};
    renderNav();bindDefaultRange();

    // Shared Aeternum summary for all issuers, preserving the protected source.
    status.invoice_contract='all-cards-aeternum-summary-source-v1';
    const previousCardPredicate=isCardSettlement;
    isCardSettlement=function(event){const name=String(event.description||event.description_raw||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();return num(event.signed_amount)<0&&(event.source==='card_invoice'||/fatura|personnalite|pers black|gastos cartao de credito/.test(name)||previousCardPredicate(event))};
    let invoiceSequence=0;
    openCardSettlement=async function(event){
      const sequence=++invoiceSequence;EXP.add(event.event_date);CARDDETAILFULL=false;CARDDETAILLOADING=true;CARDDETAIL={event};render();focusCardDetail(event.event_date);
      try{const {data,error}=await S.rpc('lts_browser_card_settlement_detail_v2',{p_event_date:event.event_date,p_description:event.description||event.description_raw||'',p_amount:Math.abs(num(event.signed_amount)),p_account:event.account||null});if(sequence!==invoiceSequence)return;if(error)throw error;CARDDETAIL={event,...(data||{})}}
      catch(error){if(sequence!==invoiceSequence)return;CARDDETAIL={event,error:'Não foi possível consultar o detalhe. Feche e abra a fatura para tentar novamente.'}}
      finally{if(sequence===invoiceSequence){CARDDETAILLOADING=false;render();focusCardDetail(event.event_date)}}
    };
    cardSettlementDrawer=function(){
      if(!CARDDETAIL)return '';
      const detail=CARDDETAIL,event=detail.event||{},purchases=detail.purchases||[];
      const title=detail.card_name||event.description||'Cartão não identificado';
      const close='<button id="closeCardDetail" class="btn ghost" type="button">Fechar</button>';
      const head=(full=false)=>`<div class="invoice-head"><div><b>${full?'Fatura completa':'Resumo da fatura'}</b><div class="mut">${esc(title)}</div></div><div class="chips">${full?'<button id="backCardSummary" class="chip" type="button">Voltar ao resumo</button>':''}${close}</div></div>`;
      const shell=body=>`<section class="invoice-inline fx89-invoice lts-invoice-unified ${CARDDETAILFULL?'':'fx89-invoice-compact'}" data-invoice-contract="all-cards-aeternum-summary-source-v1" aria-label="Resumo da fatura">${body}</section>`;
      if(CARDDETAILLOADING)return shell(head()+'<div class="notice" role="status">Carregando compras da fatura…</div>');
      if(detail.error)return shell(head()+`<div class="notice" role="alert">${esc(detail.error)}</div>`);
      if(!detail.matched)return shell(head()+`<div class="fx89-metric"><span>Valor no Fluxo</span><b>${brl(Math.abs(num(event.signed_amount)))}</b><small>${esc(event.account||'')} · caixa ${fmt(event.event_date)}</small></div><div class="notice">Sem fatura documental vinculada com segurança a este banco, cartão e competência. Não há compras a exibir. Um valor igual em outro mês não confirma este vínculo.</div>`);
      const state=detail.open_cycle?'Em aberto':detail.projected_cycle?'Projeção':detail.payment_documented?'Pagamento documentado':detail.historical_only?'Registro histórico':'Fechada · pagamento não confirmado';
      const lines=Array.isArray(purchases)?purchases:[];
      const grouped=new Map();let pendingCharges=0,pendingCredits=0,chargeCount=0,creditCount=0;
      lines.forEach(item=>{const category=item.category||'A classificar',amount=num(item.amount);grouped.set(category,(grouped.get(category)||0)+amount);if(['a classificar','—',''].includes(String(category).toLowerCase().trim())){if(amount<0){pendingCredits+=Math.abs(amount);creditCount++}else{pendingCharges+=amount;chargeCount++}}});
      const categories=[...grouped].map(([category,total])=>({category,total})).sort((a,b)=>b.total-a.total||a.category.localeCompare(b.category,'pt-BR'));
      const net=lines.reduce((value,item)=>value+num(item.amount),0)-num(detail.invoice_credit);
      const delta=lines.length?num(detail.invoice_total)-net:null;
      const complete=lines.length>0&&Math.abs(delta)<0.005;
      const dates=`<div class="lts-invoice-dates"><span class="status at">${esc(state)}</span><span>Vencimento ${fmt(detail.due_date)}</span><span>Caixa ${fmt(detail.cash_event_date||event.event_date)}</span>${detail.evidence_as_of?`<span>Posição ${fmt(detail.evidence_as_of)}</span>`:''}</div>`;
      const categoryHtml=categories.map(category=>`<div class="fx89-cat ${category.category==='A classificar'?'pending':''}" data-category-total="${category.total}"><span>${esc(category.category)}</span><b>${brl(category.total)}</b></div>`).join('');
      const pending=chargeCount||creditCount?`<div class="fx89-class-alert"><b>Classificação pendente</b>${chargeCount?`<span>${chargeCount} lançamento(s) de despesa · ${brl(pendingCharges)}</span>`:''}${creditCount?`<span class="lts-pending-credit">${creditCount} crédito(s)/estorno(s) · ${brl(pendingCredits)}. Não é uma nova despesa.</span>`:''}<button id="goCardClassification" class="chip" type="button">Revisar classificação</button></div>`:lines.length?'<div class="fx89-class-ok">Itens documentados classificados.</div>':'';
      const check=complete?'Detalhe confere com o total':lines.length?'Detalhe parcial · diferença a conferir':'Detalhe não documentado';
      const metric=`<div class="fx89-metric"><span>${detail.open_cycle?'Total da posição aberta':'Total da fatura'}</span><b>${brl(detail.invoice_total)}</b><small>${lines.length} lançamento(s) · ${check}${delta!==null?' · diferença '+brl(delta):''}</small>${detail.open_cycle?'<small>A fatura ainda pode crescer; não indica pagamento.</small>':''}</div>`;
      const guard='<div class="notice lts-invoice-guard">Pagamento da fatura explica o caixa; compras explicam consumo e não são somadas novamente. Datas, finais e parcelas são apresentados somente quando documentados.</div>';
      if(!CARDDETAILFULL)return shell(head()+dates+`<div class="fx89-invoice-body"><div><div class="fx89-invoice-title">Por categoria</div><div class="mut">Valores líquidos, do maior para o menor.</div><div class="fx89-catgrid">${categoryHtml||'<div class="empty">Sem detalhe documental para agrupar.</div>'}</div>${num(detail.invoice_credit)?`<div class="fx89-cat"><span>Créditos da fatura fora das compras</span><b>− ${brl(detail.invoice_credit)}</b></div>`:''}</div><div class="fx89-invoice-side">${metric}${pending}${lines.length?'<button id="openCardFull" class="btn ghost" type="button">Acessar fatura completa</button>':''}</div></div>`+guard);
      const items=lines.map(item=>{const date=item.purchase_date?fmt(item.purchase_date):item.date_printed?String(item.date_printed)+' · ano não informado':'Data não informada';const installment=item.installment_label||(item.installment_number&&item.installments?item.installment_number+'/'+item.installments:null);return `<div class="expense-tx lts-source-line" data-source-row="${esc(item.row_id||'')}"><div class="expense-main"><b>${esc(item.description)}</b><span>${esc(date)}${item.card_final?' · final '+esc(item.card_final):''}${item.holder?' · '+esc(item.holder):''}</span><div class="expense-meta"><i class="tag">${esc(item.category||'A classificar')}</i>${installment?`<i class="tag">Parcela ${esc(installment)}</i>`:''}${num(item.amount)<0?'<i class="tag">Crédito / estorno</i>':''}${item.source_page?`<i class="tag">Página ${esc(item.source_page)}</i>`:''}</div></div><b class="expense-val ${num(item.amount)<0?'pos':'neg'}">${num(item.amount)<0?'− ':''}${brl(Math.abs(num(item.amount)))}</b></div>`}).join('');
      return shell(head(true)+dates+`<div class="lts-invoice-metrics">${metric}<div class="fx89-metric"><span>Créditos não incluídos nas linhas</span><b>${brl(detail.invoice_credit)}</b><small>${check}</small></div></div><div class="invoice-grid"><div class="card"><div class="title">Por categoria</div>${categoryHtml}${pending}</div><div class="card"><div class="title">Compras e créditos da fatura</div>${items||'<div class="empty">Sem linhas documentadas.</div>'}</div></div>`+guard);
    };
    const invoiceStyle=document.createElement('style');invoiceStyle.id='lts-integrated-invoices-style';
    invoiceStyle.textContent=`
      .lts-invoice-unified{box-sizing:border-box!important;width:100%!important;min-width:0!important;margin-left:0!important}
      .lts-invoice-unified .invoice-grid{grid-template-columns:minmax(200px,30%) minmax(0,1fr)!important}
      .lts-invoice-unified .card,.lts-invoice-unified .expense-main{min-width:0;overflow-wrap:anywhere}
      .lts-invoice-unified .expense-val{white-space:nowrap;flex-shrink:0}
      .lts-invoice-dates{display:flex;flex-wrap:wrap;gap:8px 14px;font-size:11px;margin:8px 0 14px;color:var(--mut)}
      .lts-invoice-metrics{display:grid;grid-template-columns:1fr 1fr;gap:12px}
      .lts-invoice-unified .fx89-class-alert>span{display:block;margin:6px 0}
      .lts-invoice-unified .fx89-catgrid{margin-top:10px}
      .lts-invoice-guard{margin-top:14px;font-size:11px}
      .lts-reconciliation-warning{margin:12px 0;font-size:12px}
      @media(max-width:820px){.lts-invoice-unified .invoice-grid,.lts-invoice-metrics{grid-template-columns:1fr!important}.lts-invoice-unified .invoice-head{flex-wrap:wrap}.lts-invoice-unified .fx89-invoice-body{display:grid;grid-template-columns:1fr}.lts-invoice-unified button{min-height:36px}.lts-invoice-unified .expense-tx{display:flex;gap:10px}.lts-invoice-unified .expense-main{flex:1}.lts-invoice-unified{padding:12px!important}}
    `;document.head.appendChild(invoiceStyle);
    function addReconciliationNotice(){
      if(V!=='Fluxo Diário'||!FLOWQ)return;
      const gaps=(FLOWQ.historical?.days||[]).flatMap(day=>Object.entries(day.reconciliation_gaps||{}).filter(([bank,value])=>Math.abs(num(value))>.005&&(ACC==='Consolidado'||ACC===bank)).map(([bank,value])=>({bank,value,date:day.date})));
      const priorEvidence=document.getElementById('ltsBankEvidence');if(priorEvidence)priorEvidence.remove();
      const banks=(FLOWQ.bank_evidence_as_of||[]).filter(bank=>ACC==='Consolidado'||ACC===bank.bank),rangeHost=document.querySelector('.flowbar');
      if(banks.length&&rangeHost){const evidence=document.createElement('div');evidence.id='ltsBankEvidence';evidence.className='mut';evidence.textContent='Saldos documentados: '+banks.map(bank=>bank.bank+' em '+fmt(bank.date)).join(' · ')+'. Os dias seguintes são projeção, não consulta ao banco.';rangeHost.insertAdjacentElement('afterend',evidence)}
      const previous=document.getElementById('ltsReconciliationWarning');if(previous)previous.remove();if(!gaps.length)return;
      const host=document.querySelector('.flowbar');if(!host)return;
      const notice=document.createElement('div');notice.id='ltsReconciliationWarning';notice.className='notice lts-reconciliation-warning';notice.setAttribute('role','status');notice.textContent='Conferência histórica pendente: '+gaps.map(g=>g.bank+' em '+fmt(g.date)+' · diferença de '+brl(Math.abs(g.value))).join('; ')+'. O saldo documental está preservado; não foi criado lançamento para encobrir a diferença.';host.insertAdjacentElement('afterend',notice);
    }
    const renderWithInvoices=render;render=function(){renderWithInvoices();addReconciliationNotice()};
    function applyScope(){document.querySelectorAll('.brand small').forEach(node=>{node.textContent='Recuperação do Fluxo Diário'});document.querySelectorAll('.footer').forEach(node=>{node.hidden=true})}
    window.__LTS_V162_ROUTE_FLOW=function(){
      if(!D){applyScope();return {state:document.querySelector('.login')?'login':'waiting',done:false,ok:false}}
      if(status.route!=='Fluxo Diário'){V='Fluxo Diário';renderNav();render();status.route='Fluxo Diário';status.route_applied_at=new Date().toISOString()}
      applyScope();
      if(!status.refresh_requested&&!FLOWLOADING){Promise.resolve(openDefaultRange()).catch(error=>{status.last_flow_done=true;status.last_flow_ok=false;status.last_flow_error=String(error?.message||error||'Falha de leitura')})}
      return {state:'flow',done:status.last_flow_done,ok:status.last_flow_ok,error:status.last_flow_error};
    };
  }
  function currentFrame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement)return null;const path=w.location?.pathname||'';if(!path.endsWith('/index.html'))return null;return {w,d}}catch(error){return null}}
  function showGate(message){if(!gate)return;gate.textContent=message||'Preparando o Fluxo Diário…';gate.hidden=false}
  function hideGate(){if(gate)gate.hidden=true}
  function installRuntime(frame){if(frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true)return true;if(frame.d.getElementById('lts-v162-flow-runtime'))return false;const host=frame.d.head||frame.d.documentElement;if(!host)return false;const script=frame.d.createElement('script');script.id='lts-v162-flow-runtime';script.textContent=`(${recoveryRuntime.toString()})();`;host.appendChild(script);return frame.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true}
  function install(){
    const frame=currentFrame();if(!frame)return false;
    if(!frame.d.getElementById('v162-flow-scope-css')){
      const host=frame.d.head||frame.d.documentElement;if(!host)return false;const style=frame.d.createElement('style');style.id='v162-flow-scope-css';
      style.textContent=`
        .nav [data-v="Dashboard"]{display:none!important}
        .footer{display:none!important}
        @media(max-width:820px){
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2){display:block!important;padding:8px 7px!important;text-align:right!important;min-height:49px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(n+2)::before{display:block;margin-bottom:4px;color:var(--mut);font-size:8px;font-weight:850;line-height:1.15;text-align:left;text-transform:uppercase;letter-spacing:.025em}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2)::before{content:'Saldo anterior'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(3)::before{content:'Entradas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(4)::before{content:'Saídas'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(5)::before{content:'Saldo final'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6)::before{content:'D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(7)::before{content:'Saldo c/ D0/D1'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(8)::before{content:'RSU vested'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(9)::before{content:'Saldo c/ RSU'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(10)::before{content:'FGTS restrito'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(11)::before{content:'Saldo total'}
          .fx87-row.fx87-cons .fx87-cell:nth-child(2),.fx87-row.fx87-cons .fx87-cell:nth-child(5),.fx87-row.fx87-cons .fx87-cell:nth-child(7),.fx87-row.fx87-cons .fx87-cell:nth-child(9),.fx87-row.fx87-cons .fx87-cell:nth-child(11){background:#f2f4f6!important;border-radius:8px}
          .fx87-row.fx87-cons .fx87-cell:nth-child(6),.fx87-row.fx87-cons .fx87-cell:nth-child(7){border-top:1px solid #e4e9ef}
          .fx87-date{display:flex!important;min-height:0!important;text-align:left!important}
        }
      `;host.appendChild(style);
    }
    if(!installRuntime(frame))return false;
    const result=frame.w.__LTS_V162_ROUTE_FLOW?.(),status=frame.w.__LTS_V162_FLOW_RECOVERY_STATUS;
    if(result?.state==='login'){hideGate();return true}
    if(status?.refresh_requested&&status?.last_flow_done){hideGate();return true}
    if(result?.state==='flow')showGate('Atualizando o Fluxo Diário…');return result?.state==='flow';
  }
  function burst(){const generation=++bootGeneration;let attempt=0;function step(){if(generation!==bootGeneration)return;install();attempt+=1;if(attempt<160&&gate&&!gate.hidden)setTimeout(step,100)}step();[250,600,1200,2400,4800,8000,12000,18000].forEach(delay=>{setTimeout(()=>{if(generation===bootGeneration)install()},delay)})}
  outer?.addEventListener('load',()=>{showGate('Preparando o Fluxo Diário…');burst()});
  window.addEventListener('storage',event=>{if(event.key===SESSION_KEY){showGate('Atualizando o Fluxo Diário…');burst()}});
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v162-flow-recovery';
  window.__LTS_V162_STATUS={contract:CONTRACT,source_candidate:'index.html',flow_baseline:'WIP35-v150 Flow component',data_rpc:TARGET_RPC,dashboard_in_scope:false,public_index_changed:false,bounded_boot:true,permanent_polling:false};
})();
