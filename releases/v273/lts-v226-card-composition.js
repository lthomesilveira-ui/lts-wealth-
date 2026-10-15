/* V226: authenticated invoice composition, shared by Dashboard and Expenses. */
(function () {
  'use strict';
  const shell=document.getElementById('shell');
  function runtime(){
function documentaryPaymentNote(cycle, esc, formatDate) {
  const e = cycle?.documentary_payment_evidence;
  if (!e) return '';
  if (e.status === 'source_changed') return '<p class="v226-note">A fonte do pagamento mudou. A associação documental precisa ser conferida novamente.</p>';
  if (e.status !== 'identified_in_statement' || e.cash_effect !== 'none' || e.currency !== 'BRL' || !/^\d{4}-\d{2}-\d{2}$/.test(e.payment_date || '') || !(Number(e.amount) > 0)) return '';
  return '<p class="v226-note">Pagamento identificado no extrato em ' + esc(formatDate(e.payment_date)) + '. Associação documental conferida; o estado informado pelo emissor é apresentado separadamente.</p>';
}


    const v233Formatters=[new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'})];

    if(window.__LTS_V226)return;
    const st=window.__LTS_V226={installed:true,completeness_contract:269,cycles:null,loading:false,error:'',epoch:0,loadedAt:0,loadedDay:null,options:null,history:{key:'',loading:false,data:null,error:''}};
    const previousRender=render,previousNav=renderNav;
    const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const money=x=>x==null?'—':v233Formatters[0].format(Number(x));
    const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'Vencimento a confirmar';
    const month=x=>/^\d{4}-\d{2}/.test(x||'')?v233Formatters[1].format(new Date(x.slice(0,7)+'-01T12:00:00Z')).replace('.',''):'Sem ciclo informado';
    const today=()=>v233Formatters[2].format(new Date());
    const sum=xs=>xs.reduce((n,x)=>n+Number(x||0),0);
    const cycleTotal=xs=>st.cycles?.complete===false||xs.some(x=>x.complete===false||x.amount==null)?null:sum(xs.map(x=>x.amount));
    const totalLabel=x=>x==null?'Total incompleto':money(x);
    const names={aeternum:'Visa Aeternum',bradesco_prime:'Visa Infinite Prime',itau_mastercard:'Mastercard Black',itau_visa:'Visa Infinite',c6:'C6 Carbon'};
    const category=x=>window.LTSCategoryDisplay.category(x||'A classificar');
    const source=x=>({incomplete_cycle_identity:'Total incompleto · ciclo em conferência',received_and_projected_installments:'Compras recebidas + parcelas previstas',open_finance_invoice_v263:'Fatura recebida do banco',user_confirmed_recurring_estimate:'Assinatura prevista · fatura ainda não recebida',open_finance_composition:'Em aberto · compras recebidas',bank_document_composition:'Em aberto · banco e fatura parcial',provider_installments:'Parcelas futuras informadas pelo banco',derived_current_installments:'Parcelas restantes das compras recebidas',documented_floor_partial_detail:'Piso documentado · composição parcial',contracted_installments:'Parcelas já contratadas',documented_snapshot:'Última posição documentada'}[x]||'Última posição documentada');
    const active=()=>typeof D!=='undefined'&&D&&!N.classList.contains('hidden');
    async function rpc(name,args={}){const r=await S.rpc(name,args);if(r.error||!r.data)throw Error('Não foi possível carregar esta composição.');return r.data;}
    function period(){
      const s=window.__LTS_V168_STATE?.expense||{},to=today();
      if(s.key==='all')return {p_from:'2013-10-10',p_to:to};
      if(s.key==='custom')return {p_from:s.customFrom,p_to:s.customTo};
      if(s.key==='6m'||s.key==='12m'){const d=new Date(to.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{p_from:d.toISOString().slice(0,10),p_to:to};}
      return{p_from:to.slice(0,4)+'-01-01',p_to:to};
    }
    function clear(){st.epoch++;st.loadedAt=0;st.loadedDay=null;st.cycles=null;st.loading=false;st.error='';st.options=null;st.history={key:'',loading:false,data:null,error:''};document.getElementById('v226-detail')?.close();}
    st.invalidate=clear;
    async function loadCycles(force=false){
      if(force)window.__LTS_V227_TRANSPORT?.invalidate?.();
      if(st.loading)return st.pending;
      if(!force&&(st.error||(st.cycles&&st.loadedDay===today()&&Date.now()-st.loadedAt<60000)))return;
      st.pending=(async()=>{
      const epoch=st.epoch;st.loading=true;st.error='';
      try{const data=await rpc('lts_browser_card_cycles_v229');if(data.version!=='card-cycles-v226'||!Array.isArray(data.cards))throw Error('Formato incompleto');if(epoch===st.epoch){st.cycles=data;st.loadedAt=Date.now();st.loadedDay=today();}}
      catch{if(epoch===st.epoch)st.error='As próximas faturas não estão disponíveis agora.';}
      finally{if(epoch===st.epoch){st.loading=false;paint();}}
      })();
      return st.pending;
    }
    async function loadHistory(){
      const p=period(),key=p.p_from+'|'+p.p_to,h=st.history;
      if(h.key===key&&(h.loading||h.data||h.error))return;
      h.key=key;h.loading=true;h.data=null;h.error='';const epoch=st.epoch;
      try{const d=await rpc('lts_browser_card_history_v226',p);if(d.version!=='card-history-v226'||!Array.isArray(d.invoices))throw Error('Histórico incompleto');if(epoch===st.epoch&&h.key===key)h.data=d;}
      catch{if(epoch===st.epoch&&h.key===key)h.error='Não foi possível consultar a composição histórica.';}
      finally{if(epoch===st.epoch&&h.key===key){h.loading=false;paint();}}
    }
    function openButton(card,cycle,label,cls=''){
      return '<button type="button" class="v226-link '+cls+'" data-v226-family="'+esc(card.family)+'" data-v226-month="'+esc(cycle.month||cycle.reference_month)+'" aria-label="'+esc('Abrir '+(names[card.family]||card.card_name)+' · '+month(cycle.month||cycle.reference_month))+'">'+label+'</button>';
    }
    const receivedFormatter=new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
    function sourceStamp(card,cycle){
      const rows=[],add=(label,value)=>{if(/^\d{4}-\d{2}-\d{2}$/.test(value||'')){rows.push('<small class="v232-source-stamp">'+label+esc(date(value))+'</small>');return;}const parsed=new Date(value);if(value&&Number.isFinite(parsed.getTime()))rows.push('<small class="v232-source-stamp">'+label+esc(receivedFormatter.format(parsed))+'</small>');};
      if(cycle?.invoice_source_updated_at){
        add('Fatura atualizada no banco: ',cycle.invoice_source_updated_at);
        add('Recebida pelo LTS: ',cycle.invoice_received_at);
      }else{
        add('Dados do cartão no provedor: ',card.source_updated_at);
        add('Recebidos pelo LTS: ',card.received_at);
      }
      if(cycle?.basis==='bank_document_composition')add('Fatura parcial complementar: ',card.document_source_as_of);
      else if(['documented_snapshot','documented_floor_partial_detail'].includes(cycle?.basis)&&cycle.documentary_as_of)rows.push('<small class="v232-source-stamp">Posição documentada: '+esc(date(cycle.documentary_as_of))+'</small>');
      return rows.join('');
    }
    function upcomingPanel(full){
      const cards=st.cycles?.cards||[];
      const head='<div class="v168-cardhead"><div><span>Por banco e cartão</span><h2>Próximas faturas</h2></div><button type="button" class="v168-btn" data-v226-retry>Atualizar faturas</button></div>';
      if(!st.cycles)return head+'<p role="status">'+esc(st.error||'Consultando os próximos ciclos…')+'</p>';
      const next=cards.flatMap(c=>c.cycles?.length?[{card:c,cycle:c.cycles[0]}]:[]),nextTotal=cycleTotal(next.map(x=>x.cycle));
      const future=cards.flatMap(c=>(c.cycles||[]).slice(1)),futureTotal=cycleTotal(future);
      const bankNames=[...new Set(cards.map(c=>c.bank))];
      return head+(st.cycles.complete===false?'<p class="v226-warning" role="status">O C6 tem compras cujo ciclo ou parcela precisa ser conciliado. O total conjunto está incompleto; os demais cartões continuam disponíveis.</p>':'')+(st.loading?'<p role="status">Atualizando faturas…</p>':st.error?'<p role="alert">'+esc(st.error)+' A leitura anterior está indicada abaixo.</p>':'')+'<div class="v226-totals"><div><span>Próximas faturas e valores previstos</span><strong><button class="v226-link" data-v226-overview="next">'+totalLabel(nextTotal)+'</button></strong></div><div><span>Ciclos seguintes conhecidos</span><strong><button class="v226-link" data-v226-overview="future">'+totalLabel(futureTotal)+'</button></strong><small>Valores documentados e parcelas; sem novas compras estimadas</small></div></div>'+
        '<div class="v226-banks">'+bankNames.map(bank=>'<section><h3>'+esc(bank)+'</h3>'+cards.filter(c=>c.bank===bank).map(c=>{
          const cycle=c.cycles?.[0],label=esc(names[c.family]||c.name);
          return '<div class="v226-card-line"><div>'+(cycle?openButton(c,cycle,label):'<b>'+label+'</b>')+'<small>Conta final '+esc(c.last4)+(c.family==='c6'?' · inclui 8304':'')+'</small></div><div>'+(cycle?openButton(c,cycle,totalLabel(cycle.amount),'v226-amount'):'<span>Sem fatura aberta informada</span>')+(cycle?'<small>'+esc(month(cycle.month))+' · '+esc(date(cycle.due_date))+'</small><small>'+esc(source(cycle.basis)+(cycle.payment_status==='payment_not_reported'?' · pagamento não informado':cycle.payment_status==='payment_reported'?' · pagamento informado':cycle.payment_status==='paid'?' · pagamento confirmado':''))+'</small>'+sourceStamp(c,cycle)+documentaryPaymentNote(cycle,esc,date):'')+'</div></div>'+unresolvedPanel(c);
        }).join('')+'</section>').join('')+'</div>'+
        '<p class="v226-note">'+st.cycles.active_billing_accounts+' contas de cartão ativas. Cartões adicionais compartilham a fatura; clique no nome ou no valor para abrir as compras.</p>'+
        '<details class="v226-future"><summary>Faturas e parcelas dos próximos meses · '+totalLabel(futureTotal)+'</summary><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Valor</th><th>Origem</th></tr></thead><tbody>'+cards.flatMap(c=>(c.cycles||[]).slice(1).map(x=>'<tr><td>'+esc(c.bank+' · '+(names[c.family]||c.name))+'</td><td>'+openButton(c,x,esc(month(x.month)))+'</td><td>'+openButton(c,x,money(x.amount))+'</td><td>'+esc(source(x.basis))+'</td></tr>')).join('')+'</tbody></table></div></details>';
    }
    function unresolvedPanel(card){
      const rows=card.unresolved_items||[],ambiguous=card.ambiguous_document_candidates||[];
      if(card.complete!==false)return '';
      const item=r=>'<tr><td>'+esc(date(r?.purchase_date||r?.posting_date))+'</td><td>'+esc(r?.last4)+'</td><td>'+esc(r?.description)+'</td><td>'+money(r?.amount)+'</td></tr>';
      return '<details class="v226-alternative"><summary>Evidências em conferência · '+rows.length+' compras sem ciclo · '+ambiguous.length+' correspondências ambíguas</summary><p>Valores de fontes que ainda não podem ser somados como despesas. Nenhum vencimento incerto foi atribuído.</p><div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Valor da fonte</th></tr></thead><tbody>'+rows.map(item).join('')+ambiguous.map(a=>'<tr><th colspan="4">Documento '+esc(a.document_id)+' / banco '+esc(a.provider_id)+'</th></tr>'+item(a.document_item)+item(a.provider_item)).join('')+'</tbody></table></div></details>';
    }
    function historyPanel(){
      const h=st.history,head='<div class="v168-cardhead"><div><span>Composição das fontes disponíveis</span><h2>Faturas históricas</h2></div></div>';
      if(!h.data)return head+'<p role="status">'+esc(h.error||'Conferindo faturas do período…')+'</p>';
      const rows=h.data.invoices||[];
      return head+(rows.length?'<div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo / vencimento</th><th>Fatura</th><th>Compras e créditos</th><th>Composição</th></tr></thead><tbody>'+rows.map(r=>'<tr><td>'+openButton(r,r,esc(r.bank+' · '+(names[r.family]||r.card_name)))+'</td><td>'+esc(r.due_date?date(r.due_date):month(r.reference_month))+'</td><td>'+openButton(r,r,money(r.amount))+'</td><td>'+r.item_count+' lançamentos · '+money(r.detail_total)+'</td><td>'+(r.detail_complete?(r.source==='workbook_reconciled'?'Total conferido · planilha':'Total conferido'):'Diferença de '+money(r.difference)+' · fonte parcial')+'</td></tr>').join('')+'</tbody></table></div>':'<p>Nenhuma fatura do Open Finance neste período. O histórico anterior permanece abaixo.</p>');
    }
    function grouped(items,key){const map=new Map();for(const r of items){const k=(key==='category'?category(r[key]):r[key])||'Não informado',v=map.get(k)||{name:k,amount:0,n:0};v.amount+=Number(r.amount);v.n++;map.set(k,v);}return [...map.values()].sort((a,b)=>b.amount-a.amount);}
    function categoryCell(r){
      if(r.category_basis!=='unresolved'||!r.source_id)return esc(category(r.category));
      if(!st.options?.length)return 'A classificar · categorias indisponíveis agora. Atualize as faturas para tentar novamente.';
      return '<details class="v226-classify"><summary>Identificar despesa</summary><form data-v226-classify="'+esc(r.source_id)+'"><label>Categoria<select name="category" required><option value="">Selecione…</option>'+(st.options||[]).map(x=>'<option value="'+esc(x)+'">'+esc(category(x))+'</option>').join('')+'</select></label><label>Para quem?<select name="beneficiary"><option value="">Sem identificação adicional</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(x=>'<option>'+x+'</option>').join('')+'</select></label><button type="submit" class="v168-btn">Salvar categoria</button><span role="status"></span></form></details>';
    }
    function alternativeSource(data){
      const rows=data.alternative_items||[];if(!rows.length)return '';
      return '<details class="v226-alternative"><summary>Detalhes adicionais do banco · '+rows.length+' lançamentos</summary><p class="v226-note">'+esc(data.alternative_note||'Outra fonte da mesma fatura; não somar novamente.')+'</p><div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Categoria</th><th>Parcela</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr data-v226-alternative-item><td>'+esc(date(r.purchase_date||r.posting_date))+'</td><td>'+esc(r.last4||'—')+'</td><td>'+esc(r.description)+'</td><td>'+esc(category(r.category))+'</td><td>'+(r.installment_number&&r.total_installments?r.installment_number+'/'+r.total_installments:'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')+'</tbody></table></div></details>';
    }
    function descriptionCell(row){
      const documented=Number(row.source_document?.amount),received=Number(row.amount);
      const mismatch=row.source_document?.amount!=null&&Number.isFinite(documented)&&Number.isFinite(received)&&Math.abs(documented-received)>=0.005;
      return esc(row.description)+(row.provider_status==='PROJECTED'?'<small class="v226-projected-origin">Parcela prevista · ainda não recebida neste ciclo</small>':'')+(row.source_document?.page?'<small class="v233-document-origin">Fatura parcial · pág. '+esc(row.source_document.page)+'</small>':'')+(mismatch?'<small class="v226-warning">Documento: '+money(documented)+' · banco: '+money(received)+'. Diferença preservada para conferência.</small>':'');
    }
    function formulaSource(data){
      const f=data.formula_resolution;if(!f)return '';
      return '<details class="v226-alternative" data-v237-formula><summary>Conferência da fórmula da planilha</summary><p class="v226-note">'+esc(f.source_note)+'</p><p>As '+Number(f.raw_item_count)+' linhas originais somam '+money(f.raw_detail_total)+'. O total aplicado é '+money(data.detail_total)+'.</p>'+(f.excluded_items||[]).map(r=>'<p data-v237-excluded>'+esc(r.source_sheet)+' · linha '+Number(r.source_row)+' · '+esc(r.category)+' · '+money(r.amount)+' · fora do total da fórmula original</p>').join('')+(f.formula_evidence||[]).map(r=>'<p>'+esc(r.file)+' · '+esc(r.total_cell)+'<br><code>'+esc(r.total_formula)+'</code><br><code>'+esc(r.category_formula)+'</code></p>').join('')+'</details>';
    }
    function compositionEvidence(data,cycle,total){
      const basis=data.basis||cycle?.basis;
      const amount=value=>typeof value==='number'&&Number.isFinite(value)?value:typeof value==='string'&&/^-?\d+(?:\.\d+)?$/.test(value.trim())&&Number.isFinite(Number(value))?Number(value):null;
      const expected=amount(data.invoice_amount??cycle?.amount);
      // A partial composition cannot certify itself by summing its own rows.
      const independentTotal=amount(data.invoice_amount)!=null||(Boolean(cycle?.invoice_source_id)&&amount(cycle?.amount)!=null);
      const mismatch=data.complete===false||cycle?.complete===false||data.document_items_matched===false||cycle?.document_items_matched===false||data.invoice_composition_complete===false||cycle?.invoice_composition_complete===false||data.detail_complete===false||cycle?.detail_complete===false;
      const documentMatched=data.document_items_matched===true||cycle?.document_items_matched===true;
      const providerTotalMatched=data.invoice_composition_complete===true||cycle?.invoice_composition_complete===true;
      const complete=independentTotal&&(documentMatched||providerTotalMatched)&&!mismatch&&expected!=null&&Number.isFinite(total)&&Math.abs(Number(expected)-total)<0.005;
      const projected=['received_and_projected_installments','derived_current_installments','provider_installments','documented_floor_partial_detail','contracted_installments','documented_snapshot','user_confirmed_recurring_estimate'].includes(basis);
      return {expected,complete,independentTotal,
        label:independentTotal?'Valor recebido da fatura':projected?'Valor previsto do ciclo':'Compras recebidas do ciclo',
        coverage:complete?(documentMatched?'itens conferidos com o documento':'total confere com os itens recebidos'):independentTotal?'composição parcial':'composição parcial · total da fatura não recebido'};
    }
    function detailBody(data,cycle){
      const rows=data.items||[],total=sum(rows.map(r=>r.amount)),uncertain=data.complete===false||cycle?.complete===false,detailTotal=uncertain?'Total não consolidado':money(total);
      const {expected,complete,independentTotal,label,coverage}=compositionEvidence(data,cycle,total);
      const documented=rows.filter(r=>r.provider_status==='DOCUMENTED').length;
      return (data.complete===false||cycle?.complete===false?'<p class="v226-warning">Total incompleto. Os itens abaixo são conhecidos, mas ainda existem compras ou parcelas com identidade em conferência.</p>':'')+(data.source_note?'<p class="v226-note">'+esc(data.source_note)+'</p>':'')+(documented&&(data.basis||cycle?.basis)==='bank_document_composition'?'<p class="v226-note" data-v233-document-note>'+documented+(documented===1?' parcela comprovada':' parcelas comprovadas')+' na fatura parcial do banco.</p>':'')+'<div class="v226-totals"><div><span>'+esc(label)+'</span><strong>'+money(expected)+'</strong></div><div><span>Compras e créditos detalhados</span><strong>'+detailTotal+'</strong><small>'+rows.length+' lançamentos · '+coverage+'</small></div></div>'+
        (!uncertain&&independentTotal&&expected!=null&&Math.abs(Number(expected)-total)>=0.005?'<p class="v226-warning">A fonte traz '+money(Number(expected)-total)+' sem composição conciliada. Este valor não foi distribuído entre compras.</p>':'')+
        (uncertain?'':'<div class="v226-breakdown"><section><h3>Por cartão</h3>'+grouped(rows,'last4').map(x=>'<div><span>Final '+esc(x.name)+' · '+x.n+' lançamentos</span><b>'+money(x.amount)+'</b></div>').join('')+'</section><section><h3>Por tipo de despesa</h3>'+grouped(rows,'category').map(x=>'<div><span>'+esc(category(x.name))+'</span><b>'+money(x.amount)+'</b></div>').join('')+'</section></div>')+
        '<label class="v226-search">Buscar nesta fatura <input type="search" data-v226-search placeholder="Compra, cartão ou categoria"></label>'+
        '<div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Categoria</th><th>Parcela</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr data-v226-item><td>'+esc(r.date_kind==='reference_month'?month(r.reference_month):date(r.purchase_date||r.posting_date))+'</td><td>'+esc(r.last4||'—')+'</td><td>'+descriptionCell(r)+'</td><td>'+categoryCell(r)+'</td><td>'+(r.installment_number&&r.total_installments?r.installment_number+'/'+r.total_installments:'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="5">Total da composição</th><td>'+detailTotal+'</td></tr></tfoot></table></div>'+
        documentaryPaymentNote(cycle||data,esc,date)+formulaSource(data)+alternativeSource(data)+(data.basis==='user_confirmed_recurring_estimate'?'<p class="v226-note">Assinatura recorrente informada por você. A fatura e seu vencimento ainda precisam ser recebidos; este valor permanece uma previsão.</p>':'')+'<p class="v226-note">Pagamentos da fatura anterior estão separados das compras. Créditos e estornos reduzem o total. Compras em processamento podem ser atualizadas pelo banco.</p>';
    }
    async function openDetail(family,cycleMonth){
      if(st.cycles&&(st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))await loadCycles();
      document.getElementById('v226-detail')?.close();
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      const card=st.cycles?.cards.find(c=>c.family===family),cycle=card?.cycles?.find(x=>x.month===cycleMonth);
      dialog.innerHTML='<header><div><small>'+esc(month(cycleMonth))+'</small><h2>'+esc(names[family]||'Fatura')+'</h2></div><button type="button" class="v168-btn" data-v226-close>Fechar</button></header><div data-v226-body><p role="status">Carregando todas as compras…</p></div>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());dialog.showModal();
      const epoch=st.epoch;
      try{
        const d=cycle?.items?.length?{...cycle,items:cycle.items,basis:cycle.basis}:await rpc('lts_browser_card_detail_v226',{p_family:family,p_month:cycleMonth});
        if(!dialog.isConnected||epoch!==st.epoch)return;
        if(d.items?.some(r=>r.category_basis==='unresolved')&&!st.options){try{const options=await rpc('lts_browser_card_category_options_v226');if(epoch===st.epoch)st.options=options.categories||[];}catch{st.options=[];}}
        if(!dialog.isConnected||epoch!==st.epoch)return;
        const draw=()=>{
          dialog.querySelector('[data-v226-body]').innerHTML=detailBody(d,cycle);
          dialog.querySelector('[data-v226-search]').oninput=e=>{const key=e.target.value.toLocaleLowerCase('pt-BR');dialog.querySelectorAll('[data-v226-item],[data-v226-alternative-item]').forEach(r=>r.hidden=!r.textContent.toLocaleLowerCase('pt-BR').includes(key));};
          dialog.querySelectorAll('[data-v226-classify]').forEach(form=>form.onsubmit=async event=>{
            event.preventDefault();const button=form.querySelector('button'),status=form.querySelector('[role="status"]'),cat=form.elements.category.value,person=form.elements.beneficiary.value;
            if(!cat||button.disabled)return;button.disabled=true;status.textContent='Salvando…';
            try{
              const saved=await rpc('lts_browser_card_classify_v226',{p_source_id:form.dataset.v226Classify,p_category:cat,p_beneficiary:person||null});
              if(saved.ok!==true)throw Error('Não confirmado');
              if(epoch!==st.epoch||!dialog.isConnected)return;
              for(const row of d.items||[])if(row.source_id===form.dataset.v226Classify){row.category=person&&person!=='Lucas'?person+' — '+cat:cat;row.category_basis='user_decision';}
              st.cycles=null;st.history={key:'',loading:false,data:null,error:''};
              const reports=window.__LTS_V175_STATE;
              for(const key of ['expense','monthly','cards']){const s=reports?.[key];if(s){s.token=(s.token||0)+1;s.key='';s.data=null;s.loading=false;s.error=null;}}
              if(window.__LTS_V225?.pending){window.__LTS_V225.pending.key='';window.__LTS_V225.pending.data=null;}
              draw();loadCycles(true);window.__LTS_V178_REVIEW?.refresh?.();
            }catch{if(dialog.isConnected){button.disabled=false;status.textContent='Não foi possível salvar. Tente novamente.';}}
          });
        };draw();
      }
      catch{if(dialog.isConnected)dialog.querySelector('[data-v226-body]').innerHTML='<p role="alert">Não foi possível abrir a composição. Feche e tente novamente.</p>';}
    }
    function openOverview(kind){
      document.getElementById('v226-detail')?.close();
      const rows=(st.cycles?.cards||[]).flatMap(c=>(kind==='next'?(c.cycles||[]).slice(0,1):(c.cycles||[]).slice(1)).map(cycle=>({card:c,cycle})));
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      dialog.innerHTML='<header><h2>'+ (kind==='next'?'Próximas faturas conhecidas':'Ciclos seguintes conhecidos')+'</h2><button class="v168-btn" data-v226-close>Fechar</button></header><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Vencimento</th><th>Valor</th></tr></thead><tbody>'+rows.map(({card:c,cycle:x})=>'<tr data-v226-overview-row><td>'+openButton(c,x,esc(c.bank+' · '+(names[c.family]||c.name)))+'</td><td>'+esc(month(x.month))+'</td><td>'+esc(date(x.due_date))+'</td><td>'+openButton(c,x,money(x.amount))+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="3">Total</th><td>'+totalLabel(cycleTotal(rows.map(x=>x.cycle)))+'</td></tr></tfoot></table></div><p class="v226-note">Clique no cartão ou no valor para ver as compras e parcelas. Inclui valores recebidos, parcelas documentadas e estimativas identificadas.</p>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());bind(dialog);dialog.showModal();
    }
    function paint(){
      if(!active())return;
      document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');
      document.querySelectorAll('.v182-expand-mark').forEach(e=>e.remove());
      if(!['Dashboard','Despesas','Patrimônio'].includes(V))return;
      const full=V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='cards';
      if(V==='Despesas'&&!full)return;
      if(V==='Patrimônio'&&window.__LTS_V168_STATE?.wealth?.tab!=='assets')return;
      let host=document.querySelector('.v226-upcoming');
      if(!host){host=document.createElement('article');host.className='v168-card v226-upcoming';const root=document.querySelector(V==='Dashboard'?'.v168-dashboard':V==='Patrimônio'?'.v168-wealth':'.v168-expenses');if(!root)return;if(V==='Despesas'){const tabs=root.querySelector('.v168-tabs');if(tabs)tabs.after(host);else root.appendChild(host);}else root.appendChild(host);}
      host.innerHTML=upcomingPanel(full);bind(host);
      if(!st.loading&&!st.error&&(!st.cycles||st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))queueMicrotask(()=>loadCycles());
      if(full){let h=document.querySelector('.v226-history');if(!h){h=document.createElement('article');h.className='v168-card v226-history';host.after(h);}h.innerHTML=historyPanel();bind(h);queueMicrotask(loadHistory);}
    }
    function bind(root){root.querySelectorAll('[data-v226-overview]').forEach(b=>b.onclick=()=>openOverview(b.dataset.v226Overview));root.querySelector('[data-v226-retry]')?.addEventListener('click',()=>{clear();loadCycles(true);if(V==='Despesas')loadHistory();paint();});}
    document.addEventListener('click',event=>{const button=event.target.closest?.('[data-v226-family]');if(!button)return;event.preventDefault();openDetail(button.dataset.v226Family,button.dataset.v226Month);});
    // Modern Flow invoices share the exact canonical composition with Dashboard.
    const previousSettlement=openCardSettlement;
    let settlementRequest=0;
    openCardSettlement=async function(event){
      const request=++settlementRequest,epoch=st.epoch;
      if(event?.source!=='card_invoice')return previousSettlement(event);
      const button=document.activeElement;
      try{await loadCycles(Boolean(st.error));}catch{}
      if(request!==settlementRequest||epoch!==st.epoch||!active()||V!=='Fluxo Diário')return;
      const target=window.LTSFlowInvoiceTarget.resolve(event,st.error?null:st.cycles);
      if(target.ok){await openDetail(target.family,target.month);return;}
      document.getElementById('v226-detail')?.close();
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      dialog.innerHTML='<header><h2>Composição da fatura</h2><button type="button" class="v168-btn" data-v226-close>Fechar</button></header><div class="v226-scroll"><p role="alert">Não foi possível vincular este movimento a uma única fatura com segurança. A composição precisa ser conferida; nenhuma compra foi presumida.</p></div>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();if(button?.isConnected)button.focus({preventScroll:true});});dialog.showModal();
    };
    st.openDetail=openDetail;
    st.refresh=()=>loadCycles(true);
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)paint();});
    window.addEventListener('focus',()=>{if(active()&&!st.loading&&(st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))loadCycles();});
    render=function(){const result=previousRender();paint();return result;};
    renderNav=function(){const result=previousNav();document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');return result;};
    S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')clear();});
    paint();
  }
  let tries=0;
  function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V225?.installed)return false;if(!d.getElementById('v226-style')){const s=d.createElement('link');s.id='v226-style';s.rel='stylesheet';s.href='lts-v226-card-composition.css';d.head.appendChild(s);}if(!w.LTSFlowInvoiceTarget){if(!window.LTSFlowInvoiceTarget)return false;w.LTSFlowInvoiceTarget=window.LTSFlowInvoiceTarget;}if(!w.__LTS_V226){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return Boolean(w.__LTS_V226);}catch{return false;}}
  function start(){if(!install()&&++tries<320)setTimeout(start,125);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();


