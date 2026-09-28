/* V226: authenticated invoice composition, shared by Dashboard and Expenses. */
(function () {
  'use strict';
  const shell=document.getElementById('shell');
  function runtime(){
    if(window.__LTS_V226)return;
    const st=window.__LTS_V226={installed:true,cycles:null,loading:false,error:'',epoch:0,options:null,history:{key:'',loading:false,data:null,error:''}};
    const previousRender=render,previousNav=renderNav;
    const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const money=x=>x==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
    const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'Vencimento a confirmar';
    const month=x=>/^\d{4}-\d{2}/.test(x||'')?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(x.slice(0,7)+'-01T12:00:00Z')).replace('.',''):'Sem ciclo informado';
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const sum=xs=>xs.reduce((n,x)=>n+Number(x||0),0);
    const names={aeternum:'Visa Aeternum',bradesco_prime:'Visa Infinite Prime',itau_mastercard:'Mastercard Black',itau_visa:'Visa Infinite',c6:'C6 Carbon'};
    const category=x=>String(x||'A classificar').replace(/^Lucas\s*[-—]\s*/i,'').replace(/Vestuário/gi,'Imagem e cuidados pessoais');
    const source=x=>({open_finance_composition:'Em aberto · compras recebidas',provider_installments:'Parcelas futuras informadas pelo banco',derived_current_installments:'Parcelas restantes das compras recebidas',documented_floor_partial_detail:'Piso documentado · composição parcial',contracted_installments:'Parcelas já contratadas',documented_snapshot:'Última posição documentada'}[x]||'Última posição documentada');
    const active=()=>typeof D!=='undefined'&&D&&!N.classList.contains('hidden');
    async function rpc(name,args={}){const r=await S.rpc(name,args);if(r.error||!r.data)throw Error('Não foi possível carregar esta composição.');return r.data;}
    function period(){
      const s=window.__LTS_V168_STATE?.expense||{},to=today();
      if(s.key==='all')return {p_from:'2013-10-10',p_to:to};
      if(s.key==='custom')return {p_from:s.customFrom,p_to:s.customTo};
      if(s.key==='6m'||s.key==='12m'){const d=new Date(to.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{p_from:d.toISOString().slice(0,10),p_to:to};}
      return{p_from:to.slice(0,4)+'-01-01',p_to:to};
    }
    function clear(){st.epoch++;st.cycles=null;st.loading=false;st.error='';st.options=null;st.history={key:'',loading:false,data:null,error:''};document.getElementById('v226-detail')?.close();}
    st.invalidate=clear;
    async function loadCycles(force=false){
      if(st.loading||(!force&&(st.cycles||st.error)))return;
      const epoch=st.epoch;st.loading=true;st.error='';
      try{const data=await rpc('lts_browser_card_cycles_v226');if(data.version!=='card-cycles-v226'||!Array.isArray(data.cards))throw Error('Formato incompleto');if(epoch===st.epoch)st.cycles=data;}
      catch{if(epoch===st.epoch)st.error='As próximas faturas não estão disponíveis agora.';}
      finally{if(epoch===st.epoch){st.loading=false;paint();}}
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
    function upcomingPanel(full){
      const cards=st.cycles?.cards||[];
      const head='<div class="v168-cardhead"><div><span>Por banco e cartão</span><h2>Próximas faturas</h2></div><button type="button" class="v168-btn" data-v226-retry>Atualizar faturas</button></div>';
      if(!st.cycles)return head+'<p role="status">'+esc(st.error||'Consultando os próximos ciclos…')+'</p>';
      const next=cards.flatMap(c=>c.cycles?.length?[{card:c,cycle:c.cycles[0]}]:[]),nextTotal=sum(next.map(x=>x.cycle.amount));
      const future=cards.flatMap(c=>(c.cycles||[]).slice(1)),futureTotal=sum(future.map(c=>c.amount));
      const bankNames=[...new Set(cards.map(c=>c.bank))];
      return head+'<div class="v226-totals"><div><span>Próximas faturas conhecidas</span><strong><button class="v226-link" data-v226-overview="next">'+money(nextTotal)+'</button></strong></div><div><span>Ciclos seguintes conhecidos</span><strong><button class="v226-link" data-v226-overview="future">'+money(futureTotal)+'</button></strong><small>Valores documentados e parcelas; sem novas compras estimadas</small></div></div>'+
        '<div class="v226-banks">'+bankNames.map(bank=>'<section><h3>'+esc(bank)+'</h3>'+cards.filter(c=>c.bank===bank).map(c=>{
          const cycle=c.cycles?.[0],label=esc(names[c.family]||c.name);
          return '<div class="v226-card-line"><div>'+(cycle?openButton(c,cycle,label):'<b>'+label+'</b>')+'<small>Conta final '+esc(c.last4)+(c.family==='c6'?' · inclui 8304':'')+'</small></div><div>'+(cycle?openButton(c,cycle,money(cycle.amount),'v226-amount'):'<span>Sem fatura aberta informada</span>')+(cycle?'<small>'+esc(month(cycle.month))+' · '+esc(date(cycle.due_date))+'</small><small>'+esc(source(cycle.basis))+'</small>':'')+'</div></div>';
        }).join('')+'</section>').join('')+'</div>'+
        '<p class="v226-note">'+st.cycles.active_billing_accounts+' contas de cartão ativas. Cartões adicionais compartilham a fatura; clique no nome ou no valor para abrir as compras.</p>'+
        '<details class="v226-future"><summary>Faturas e parcelas dos próximos meses · '+money(futureTotal)+'</summary><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Valor</th><th>Origem</th></tr></thead><tbody>'+cards.flatMap(c=>(c.cycles||[]).slice(1).map(x=>'<tr><td>'+esc(c.bank+' · '+(names[c.family]||c.name))+'</td><td>'+openButton(c,x,esc(month(x.month)))+'</td><td>'+openButton(c,x,money(x.amount))+'</td><td>'+esc(source(x.basis))+'</td></tr>')).join('')+'</tbody></table></div></details>';
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
    function detailBody(data,cycle){
      const rows=data.items||[],total=sum(rows.map(r=>r.amount)),expected=data.invoice_amount??cycle?.amount;
      const complete=expected!=null&&Math.abs(Number(expected)-total)<0.005;
      return (data.source_note?'<p class="v226-note">'+esc(data.source_note)+'</p>':'')+'<div class="v226-totals"><div><span>Valor da fatura</span><strong>'+money(expected)+'</strong></div><div><span>Compras e créditos detalhados</span><strong>'+money(total)+'</strong><small>'+rows.length+' lançamentos · '+(complete?'composição conferida':'composição parcial')+'</small></div></div>'+
        (expected!=null&&!complete?'<p class="v226-warning">A fonte traz '+money(Number(expected)-total)+' sem composição conciliada. Este valor não foi distribuído entre compras.</p>':'')+
        '<div class="v226-breakdown"><section><h3>Por cartão</h3>'+grouped(rows,'last4').map(x=>'<div><span>Final '+esc(x.name)+' · '+x.n+' lançamentos</span><b>'+money(x.amount)+'</b></div>').join('')+'</section><section><h3>Por tipo de despesa</h3>'+grouped(rows,'category').map(x=>'<div><span>'+esc(category(x.name))+'</span><b>'+money(x.amount)+'</b></div>').join('')+'</section></div>'+
        '<label class="v226-search">Buscar nesta fatura <input type="search" data-v226-search placeholder="Compra, cartão ou categoria"></label>'+
        '<div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Categoria</th><th>Parcela</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr data-v226-item><td>'+esc(r.date_kind==='reference_month'?month(r.reference_month):date(r.purchase_date||r.posting_date))+'</td><td>'+esc(r.last4||'—')+'</td><td>'+esc(r.description)+'</td><td>'+categoryCell(r)+'</td><td>'+(r.installment_number&&r.total_installments?r.installment_number+'/'+r.total_installments:'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="5">Total da composição</th><td>'+money(total)+'</td></tr></tfoot></table></div>'+
        alternativeSource(data)+'<p class="v226-note">Pagamentos da fatura anterior estão separados das compras. Créditos e estornos reduzem o total. Compras em processamento podem ser atualizadas pelo banco.</p>';
    }
    async function openDetail(family,cycleMonth){
      document.getElementById('v226-detail')?.close();
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      const card=st.cycles?.cards.find(c=>c.family===family),cycle=card?.cycles?.find(x=>x.month===cycleMonth);
      dialog.innerHTML='<header><div><small>'+esc(month(cycleMonth))+'</small><h2>'+esc(names[family]||'Fatura')+'</h2></div><button type="button" class="v168-btn" data-v226-close>Fechar</button></header><div data-v226-body><p role="status">Carregando todas as compras…</p></div>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());dialog.showModal();
      const epoch=st.epoch;
      try{
        const d=cycle?.items?.length?{items:cycle.items}:await rpc('lts_browser_card_detail_v226',{p_family:family,p_month:cycleMonth});
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
      dialog.innerHTML='<header><h2>'+ (kind==='next'?'Próximas faturas conhecidas':'Ciclos seguintes conhecidos')+'</h2><button class="v168-btn" data-v226-close>Fechar</button></header><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Vencimento</th><th>Valor</th></tr></thead><tbody>'+rows.map(({card:c,cycle:x})=>'<tr data-v226-overview-row><td>'+openButton(c,x,esc(c.bank+' · '+(names[c.family]||c.name)))+'</td><td>'+esc(month(x.month))+'</td><td>'+esc(date(x.due_date))+'</td><td>'+openButton(c,x,money(x.amount))+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="3">Total</th><td>'+money(sum(rows.map(x=>x.cycle.amount)))+'</td></tr></tfoot></table></div><p class="v226-note">Clique no cartão ou no valor para ver as compras e parcelas. Inclui apenas valores recebidos ou documentados.</p>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());bind(dialog);dialog.showModal();
    }
    function paint(){
      if(!active())return;
      document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');
      document.querySelectorAll('.v182-expand-mark').forEach(e=>e.remove());
      if(!['Dashboard','Despesas','Patrimônio'].includes(V))return;
      const full=V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='cards';
      if(V==='Despesas'&&!full)return;
      let host=document.querySelector('.v226-upcoming');
      if(!host){host=document.createElement('article');host.className='v168-card v226-upcoming';const root=document.querySelector(V==='Dashboard'?'.v168-dashboard':V==='Patrimônio'?'.v168-wealth':'.v168-expenses');if(!root)return;const after=root.querySelector(V==='Dashboard'?'.v168-kpi-section.current':'.v168-tabs');if(after)after.after(host);else if(V==='Despesas')root.prepend(host);else root.appendChild(host);}
      host.innerHTML=upcomingPanel(full);bind(host);
      if(!st.cycles&&!st.loading&&!st.error)queueMicrotask(()=>loadCycles());
      if(full){let h=document.querySelector('.v226-history');if(!h){h=document.createElement('article');h.className='v168-card v226-history';host.after(h);}h.innerHTML=historyPanel();bind(h);queueMicrotask(loadHistory);}
    }
    function bind(root){root.querySelectorAll('[data-v226-family]').forEach(b=>b.onclick=()=>openDetail(b.dataset.v226Family,b.dataset.v226Month));root.querySelectorAll('[data-v226-overview]').forEach(b=>b.onclick=()=>openOverview(b.dataset.v226Overview));root.querySelector('[data-v226-retry]')?.addEventListener('click',()=>{clear();loadCycles(true);if(V==='Despesas')loadHistory();paint();});}
    st.openDetail=openDetail;
    render=function(){const result=previousRender();paint();return result;};
    renderNav=function(){const result=previousNav();document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');return result;};
    S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')clear();});
    paint();
  }
  let tries=0;
  function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V225?.installed)return false;if(!d.getElementById('v226-style')){const s=d.createElement('link');s.id='v226-style';s.rel='stylesheet';s.href='lts-v226-card-composition.css';d.head.appendChild(s);}if(!w.__LTS_V226){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return Boolean(w.__LTS_V226);}catch{return false;}}
  function start(){if(!install()&&++tries<320)setTimeout(start,125);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
