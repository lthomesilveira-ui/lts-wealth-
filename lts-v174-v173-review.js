(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V174_V173_REVIEW?.installed||!window.__LTS_V173_V172_FEEDBACK?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE,v171=window.__LTS_V171_STATE||{};
    const state=window.__LTS_V174_STATE||(window.__LTS_V174_STATE={
      monthlyWarning:'',monthlyChunkCalls:0,cardFlow:null,cardFlowLoading:false,cardFlowError:'',cardFlowSeq:0
    });
    const previousRpc=S.rpc.bind(S);

    const arr=v=>Array.isArray(v)?v:[],num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((s,x)=>s+(num(x)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const money=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const month=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};

    async function directRpc(name,args){
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K;
        const response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{
          method:'POST',
          headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},
          body:JSON.stringify(args||{})
        });
        const payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status}};
        return{data:payload,error:null};
      }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
    }

    function professionalName(value){
      const x=norm(value);
      if(x==='emprestimos e consignado')return'Empréstimos';
      if(x==='familia — saidas'||x==='familia - saidas')return'Família — saídas';
      if(x==='venda de bens e ativos')return'Venda de ações, RSUs e outros ativos';
      if(x==='compras de cartao ainda sem categoria'||x==='faturas historicas sem compras individualizadas')return'Faturas conciliadas pelo total';
      if(x==='mercado')return'Mercado';
      if(x==='presentes')return'Presentes';
      if(x==='amazon')return'Amazon';
      if(x==='viagem')return'Viagens';
      return String(value||'Outros');
    }
    function subgroupName(group,value){
      const g=professionalName(group),x=String(value||'').trim(),n=norm(x);
      if(g==='Empréstimos'&&n.includes('itau'))return'Histórico pago · Itaú';
      if(g==='Empréstimos'&&n.includes('coopharma'))return'Empréstimo consignado · Coopharma';
      if(g==='Empréstimos'&&n.includes('pai'))return'Empréstimo familiar · Pai e Mãe';
      if(g==='Financiamento de veículo'&&(n==='nao identificado'||n==='veiculo nao atribuido'))return'Volvo XC40';
      return professionalName(x);
    }
    function usefulSubgroups(group,rows){
      const seen=new Map();
      for(const row of arr(rows)){
        const name=subgroupName(group,row.name),key=norm(name),parent=norm(professionalName(group));
        if(!key||key===parent)continue;
        const cur=seen.get(key)||{name,total:0,rows:0};
        cur.total+=(num(row.total)||0);cur.rows+=(num(row.rows)||0);seen.set(key,cur);
      }
      const values=[...seen.values()].sort((a,b)=>b.total-a.total);
      if(professionalName(group)==='Financiamento imobiliário'){
        const allowed=new Set(['casa','cipo 396','financiamento imobiliario — casa','financiamento imobiliario - casa','financiamento imobiliario — cipo 396','financiamento imobiliario - cipo 396']);
        if(values.length&&values.every(x=>allowed.has(norm(x.name))))return[];
      }
      return values;
    }

    function propertyReconciliation(data){return data?.property_improvement_reconciliation||{}}
    function displayGroups(data){
      const prop=propertyReconciliation(data),hasProp=num(prop.reconciled_unique_brl)!=null;
      return arr(data?.management_groups).map(group=>{
        const name=professionalName(group.name);
        const row={...group,name,subgroups:usefulSubgroups(name,group.subgroups)};
        if(name==='Investimentos no imóvel — obra e reforma'&&hasProp){
          row.dated_total=num(group.total)||0;
          row.total=num(prop.reconciled_unique_brl);
          row.source_reconciled=true;
        }
        return row;
      }).sort((a,b)=>(num(b.total)||0)-(num(a.total)||0));
    }
    function rank(groups,limit=99,details=true){
      const xs=arr(groups).filter(x=>num(x.total)!=null).slice(0,limit),top=Math.max(1,...xs.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v174-rank">'+(xs.map((row,index)=>{
        const children=usefulSubgroups(row.name,row.subgroups);
        return '<div class="v174-rankrow"><span>'+(index+1)+'</span><div><b>'+esc(professionalName(row.name))+'</b>'+(row.source_reconciled?'<small class="v174-source-badge">fonte reconciliada</small>':'')+'<i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+(details&&children.length>1?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(child.name)+'</span><b>'+money(child.total)+'</b></em>').join('')+'</details>':'')+'</div><strong>'+money(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{},count=num(c.rows)||0;
      return (num(c.total)||0)>0?'<div class="v172-coverage"><b>Faturas conciliadas pelo total</b><strong>'+money(c.total)+'</strong><span>Esse valor já está no total de despesas. Em '+count+' ciclo(s), a fonte preserva a fatura, mas não todas as compras necessárias para uma divisão confiável por categoria.</span></div>':'';
    }
    function propertyNote(data){
      const p=propertyReconciliation(data);if(num(p.reconciled_unique_brl)==null)return'';
      return '<div class="v174-property-note"><div><span>Planilha original · Reformas e melhorias</span><b>'+money(p.workbook_summary_brl)+'</b></div><div><span>Duplicidade confirmada na fonte · Móveis</span><b>− '+money(p.duplicate_source_brl)+'</b></div><div class="primary"><span>Reformas e melhorias · reconciliado</span><b>'+money(p.reconciled_unique_brl)+'</b></div><p>O valor reconciliado conta a saída econômica uma única vez. '+money(p.historical_card_coverage_gap_brl)+' permanecem documentados em agregados históricos de cartão sem data/compra individual suficiente para uma distribuição mensal inventada.</p></div>';
    }

    function monthSpan(from,to){const a=new Date(from+'T12:00:00Z'),b=new Date(to+'T12:00:00Z');return (b.getUTCFullYear()-a.getUTCFullYear())*12+b.getUTCMonth()-a.getUTCMonth()+1}
    function yearChunks(from,to){const out=[];let y=Number(from.slice(0,4)),last=Number(to.slice(0,4));for(;y<=last;y++)out.push({from:y===Number(from.slice(0,4))?from:y+'-01-01',to:y===last?to:y+'-12-31'});return out}
    async function mapLimitSettled(items,limit,worker){
      const out=new Array(items.length);let cursor=0;
      async function run(){while(true){const i=cursor++;if(i>=items.length)return;try{out[i]={status:'fulfilled',value:await worker(items[i],i)}}catch(reason){out[i]={status:'rejected',reason}}}}
      await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return out;
    }
    function mergeGroups(parts,key,months){
      const groups=new Map();
      for(const part of parts)for(const row of arr(part[key])){
        const label=professionalName(row.label),id=norm(label),cur=groups.get(id)||{label,total:0,source_rows:0,values:new Map()};
        cur.total+=(num(row.total)||0);cur.source_rows+=(num(row.source_rows)||0);
        for(const item of arr(row.monthly)){const k=String(item.month).slice(0,10);cur.values.set(k,(cur.values.get(k)||0)+(num(item.amount)||0))}
        groups.set(id,cur);
      }
      return [...groups.values()].map(g=>({label:g.label,total:g.total,source_rows:g.source_rows,monthly:months.map(k=>({month:k,amount:g.values.get(k)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to,failed){
      const months=parts.flatMap(x=>arr(x.months)).map(x=>String(x).slice(0,10)).filter((x,i,a)=>a.indexOf(x)===i).sort();
      const monthlyTotals=parts.flatMap(x=>arr(x.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((o,k)=>(o[k]=sum(parts.map(x=>x.totals?.[k])),o),{});
      const covMap=new Map();let covTotal=0,covRows=0;
      for(const part of parts){const c=part.expense_unclassified_card_coverage||{};covTotal+=(num(c.total)||0);covRows+=(num(c.source_rows)||0);for(const m of arr(c.monthly)){const k=String(m.month).slice(0,10);covMap.set(k,(covMap.get(k)||0)+(num(m.amount)||0))}}
      const saleMap=new Map();let saleTotal=0;
      for(const part of parts){const s=part.stock_sale_supplement||{};saleTotal+=(num(s.total)||0);for(const m of arr(s.monthly)){const k=String(m.month).slice(0,10);saleMap.set(k,(saleMap.get(k)||0)+(num(m.amount)||0))}}
      return{
        ...parts[0],version:'monthly-balance-v4-v174-resilient-chunked',from,to,months,monthly_totals,totals,
        revenue_groups:mergeGroups(parts,'revenue_groups',months),
        extraordinary_groups:mergeGroups(parts,'extraordinary_groups',months),
        expense_groups:mergeGroups(parts,'expense_groups',months),
        expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:covTotal,source_rows:covRows,monthly:months.map(k=>({month:k,amount:covMap.get(k)||0}))},
        stock_sale_supplement:{total:saleTotal,monthly:months.map(k=>({month:k,amount:saleMap.get(k)||0}))},
        partial_year_failures:failed||[]
      };
    }
    async function monthlyV174Rpc(args){
      const from=args?.p_from,to=args?.p_to;state.monthlyWarning='';
      if(!/^\d{4}-\d{2}-\d{2}$/.test(from||'')||!/^\d{4}-\d{2}-\d{2}$/.test(to||''))return directRpc('lts_browser_monthly_balance_v3',args||{});
      if(monthSpan(from,to)<=18)return directRpc('lts_browser_monthly_balance_v3',{p_from:from,p_to:to});
      const chunks=yearChunks(from,to);state.monthlyChunkCalls=chunks.length;
      const settled=await mapLimitSettled(chunks,3,async chunk=>{
        const r=await directRpc('lts_browser_monthly_balance_v3',{p_from:chunk.from,p_to:chunk.to});
        if(r?.error||!r?.data)throw Error(r?.error?.message||'Balanço anual indisponível');
        return{chunk,data:r.data};
      });
      const good=settled.filter(x=>x.status==='fulfilled').map(x=>x.value.data),failed=settled.map((x,i)=>x.status==='rejected'?chunks[i]:null).filter(Boolean);
      if(!good.length)return{data:null,error:{message:'Balanço mensal indisponível para o período selecionado.'}};
      if(failed.length)state.monthlyWarning='Alguns anos não responderam. O LTS manteve os anos carregados e não apagou o relatório: '+failed.map(x=>x.from.slice(0,4)).join(', ')+'.';
      return{data:mergeMonthly(good,from,to,failed),error:null};
    }

    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if(requested==='lts_browser_expense_executive_v6')return previousRpc('lts_browser_expense_executive_v7',next);
      if(requested==='lts_browser_monthly_balance_v1'||requested==='lts_browser_monthly_balance_v2'||requested==='lts_browser_monthly_balance_v3')return monthlyV174Rpc(next);
      return previousRpc(requested,next);
    };

    function coverageByMonth(j){const m=new Map();for(const row of arr(j?.expense_unclassified_card_coverage?.monthly))m.set(String(row.month).slice(0,10),num(row.amount)||0);return m}
    function matrix(title,subtitle,groups,months,expense,j){
      const cov=coverageByMonth(j);
      return '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix v174-matrix"><thead><tr><th>Grupo</th>'+months.map(x=>'<th>'+esc(month(x))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(group=>'<tr><th>'+esc(professionalName(group.label))+'</th>'+months.map(k=>{const item=arr(group.monthly).find(x=>String(x.month).slice(0,10)===String(k).slice(0,10)),amount=num(item?.amount)||0,unknown=expense&&amount===0&&(cov.get(String(k).slice(0,10))||0)>0;return'<td class="'+(unknown?'v174-unknown':'')+'">'+(amount?money(amount):unknown?'—*':'—')+'</td>'}).join('')+'<td class="total">'+money(group.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>';
    }
    function monthlyPanel(){
      const j=v169?.monthly?.data||{},tot=j.totals||{},rows=arr(j.monthly_totals),months=arr(j.months),cover=j.expense_unclassified_card_coverage||{},sales=j.stock_sale_supplement||{};
      if(v169?.monthly?.loading&&!v169.monthly.data)return'<div class="v168-skeleton"></div>';
      if(v169?.monthly?.error&&!v169.monthly.data)return'<div class="v168-error">'+esc(v169.monthly.error)+'</div>';
      return '<div class="v169-monthly v174-monthly">'+(state.monthlyWarning?'<div class="v174-warning">'+esc(state.monthlyWarning)+'</div>':'')+
        '<div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+money(tot.revenue)+'</strong><small>entradas recorrentes</small></article><article class="v168-kpi v171-expense-total"><span>Despesas com competência conhecida</span><strong>'+money(tot.expenses)+'</strong><small>cartões + contas sem dupla contagem</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+money(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+money(tot.extraordinary)+'</strong><small>inclui venda de ações comprovada</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+money(tot.cash_after_extraordinary)+'</strong><small>após entradas extraordinárias</small></article></div>'+
        ((num(sales.total)||0)>0?'<div class="v174-audit-strip"><span>Venda de ações recuperada no período</span><b>'+money(sales.total)+'</b><small>Venda/realização é receita extraordinária; transferência posterior C6 → Itaú/Bradesco continua neutra.</small></div>':'')+
        matrix('Receitas operacionais','Receitas',arr(j.revenue_groups),months,false,j)+
        matrix('Entradas extraordinárias','Entradas não recorrentes',arr(j.extraordinary_groups),months,false,j)+
        matrix('Despesas por categoria','Despesas',arr(j.expense_groups),months,true,j)+
        ((num(cover.total)||0)>0?'<div class="v174-coverage"><b>—* não significa despesa zero</b><span>O mês tem '+money(cover.total)+' de cobertura agregada de cartão ao longo da seleção. Quando a compra individual não existe na fonte, o LTS não inventa Restaurante, iFood, Rafiki ou outra categoria.</span></div>':'')+
        '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Resultado de cada mês</h2></div><small>'+months.length+' mês(es)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(row=>'<tr><th>'+month(row.month)+'</th><td>'+money(row.revenue)+'</td><td>'+money(row.expenses)+'</td><td class="'+((num(row.operating_balance)||0)<0?'negative':'positive')+'">'+money(row.operating_balance)+'</td><td>'+money(row.extraordinary)+'</td><td class="'+((num(row.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+money(row.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article></div>';
    }

    function cardBank(name){const n=norm(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau'))return'Itaú';return'Outros'}
    function cardKey(name){const n=norm(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304'))return'c6';if(n.includes('personnalite')||n.includes('5546')||n.includes('mastercard'))return'personnalite';if(n.includes('visa infinite prime'))return'visa-infinite-prime';return n.replace(/\W+/g,'-')}
    async function ensureCardFlow(force=false){
      if(state.cardFlowLoading||(!force&&state.cardFlow))return;
      const seq=++state.cardFlowSeq;state.cardFlowLoading=true;state.cardFlowError='';
      const from=today(),to=String(Number(from.slice(0,4))+1)+'-12-31';
      try{const r=await directRpc('lts_browser_card_flow_schedule_v1',{p_from:from,p_to:to});if(r?.error||!r?.data)throw Error(r?.error?.message||'Fluxo de cartões indisponível');if(seq===state.cardFlowSeq)state.cardFlow=r.data}
      catch(e){if(seq===state.cardFlowSeq)state.cardFlowError=String(e?.message||e)}
      finally{if(seq===state.cardFlowSeq){state.cardFlowLoading=false;if(V==='Despesas'&&v168?.expense?.tab==='cards')render()}}
    }
    function cardsPanel(){
      const o=D?.card_operating||{},map=new Map(),ensure=(b,c,m)=>{const k=[b,cardKey(c),m].join('|');if(!map.has(k))map.set(k,{bank:b,card:c,month:m,invoices:[],installments:[],flows:[]});return map.get(k)};
      for(const x of [...arr(o.open_cycles),...arr(o.closed_or_due)]){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.due_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).invoices.push(x)}
      for(const m of arr(o.contracted_installment_floor_months))for(const x of arr(m.detail)){const c=x.card_name||'Cartão não identificado';ensure(cardBank(c),c,String(m.reference_month).slice(0,7)).installments.push(x)}
      for(const x of arr(state.cardFlow?.events)){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.event_date||'').slice(0,7),b=cardBank(c);if(m)ensure(b,c,m).flows.push(x)}
      const filter=v171.cardBank||'Todos',all=[...map.values()].filter(x=>x.month>=today().slice(0,7)).sort((a,b)=>a.bank.localeCompare(b.bank)||cardKey(a.card).localeCompare(cardKey(b.card))||a.month.localeCompare(b.month)),banks=['Todos',...new Set(all.map(x=>x.bank))],visible=all.filter(x=>filter==='Todos'||x.bank===filter),groups=new Map();
      for(const x of visible){const k=x.bank+'|'+cardKey(x.card);if(!groups.has(k))groups.set(k,{bank:x.bank,card:x.card,rows:[]});groups.get(k).rows.push(x)}
      return '<div class="v174-cards"><div class="v169-bank-filter">'+banks.map(x=>'<button class="v168-btn '+(filter===x?'primary':'')+'" data-v174-card-bank="'+esc(x)+'">'+esc(x)+'</button>').join('')+'</div>'+
        (state.cardFlowLoading?'<div class="v174-warning">Conferindo os valores efetivamente usados no Fluxo…</div>':'')+
        (state.cardFlowError?'<div class="v174-warning">Não foi possível atualizar o comparativo com o Fluxo agora: '+esc(state.cardFlowError)+'</div>':'')+
        '<article class="v168-card"><div class="v168-cardhead"><div><span>Conferência bancária</span><h2>Fatura, piso contratado e valor do Fluxo</h2></div><small>mês a mês</small></div>'+
        ([...groups.values()].map(g=>'<section class="v171-cardgroup"><header><span>'+esc(g.bank)+'</span><h3>'+esc(g.card)+'</h3></header><div class="v171-cardmonths">'+g.rows.map(x=>{const invoice=sum(x.invoices.map(y=>y.amount)),floor=sum(x.installments.map(y=>y.amount)),flow=sum(x.flows.map(y=>y.amount)),used=x.flows.length?flow:x.invoices.length?invoice:floor,diff=x.flows.length&&floor?flow-floor:null;return'<div><b>'+month(x.month)+'</b><dl><dt>Fatura conhecida</dt><dd>'+money(invoice)+'</dd><dt>Parcelas já contratadas</dt><dd>'+money(floor)+'</dd><dt>Valor no Fluxo</dt><dd><strong>'+(x.flows.length?money(flow):'—')+'</strong></dd><dt>Considerado</dt><dd><strong>'+money(used)+'</strong></dd>'+(diff!=null?'<dt>Fluxo × piso</dt><dd>'+money(diff)+'</dd>':'')+'</dl></div>'}).join('')+'</div></section>').join('')||'<div class="v168-empty">Nenhuma fatura futura documentada neste filtro.</div>')+
        '</article><div class="v171-reconciliation"><b>Leitura corrigida</b><span>“Parcelas já contratadas” é apenas um piso. “Valor no Fluxo” mostra o compromisso/projeção realmente usado no caixa; quando existe fatura observada ela prevalece.</span></div></div>';
    }

    function expensesV174(){
      const t=tpl(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168?.expense?.data||{},tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(v168.expense.tab==='overview'&&displayGroups(data).length){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit,.v171-rank,.v171-reconciliation,.v172-rank,.v172-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),15,false)+coverageNote(data)+propertyNote(data))}
      }
      if(v168.expense.tab==='categories'&&displayGroups(data).length){
        let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}
        tabs.insertAdjacentHTML('afterend','<article class="v168-card v174-categories"><div class="v168-cardhead"><div><span>Composição auditada</span><h2>Despesas por categoria</h2></div><small>Total com data/competência: '+money(data.summary?.selected_total)+'</small></div>'+rank(displayGroups(data),99,true)+propertyNote(data)+coverageNote(data)+'</article>');
      }
      if(v168.expense.tab==='monthly'){
        const old=root.querySelector('.v171-monthly,.v172-monthly,.v169-monthly,.v168-skeleton,.v168-error');if(old){const h=tpl(monthlyPanel());old.replaceWith(...h.content.childNodes)}
      }
      if(v168.expense.tab==='cards'){
        const old=root.querySelector('.v171-cards,.v169-cards,.v174-cards');if(old){const h=tpl(cardsPanel());old.replaceWith(...h.content.childNodes)}
      }
      return t.innerHTML;
    }

    function dashboardV174(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard'),data=v168?.dashboard?.data?.expense||{};if(!root)return t.innerHTML;
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&displayGroups(data).length){card.querySelectorAll('.v171-rank,.v172-rank,.v174-rank,.v171-reconciliation,.v172-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),12,false)+coverageNote(data))}
      return t.innerHTML;
    }

    function after(){
      const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v174Route=V==='Fluxo Diário'?'Fluxo de caixa':V;
      document.querySelectorAll('[data-v174-card-bank]').forEach(b=>b.onclick=()=>{v171.cardBank=b.dataset.v174CardBank;render()});
      if(V==='Despesas'&&v168?.expense?.tab==='cards'&&!state.cardFlow&&!state.cardFlowLoading)queueMicrotask(()=>ensureCardFlow(false));
    }

    dashboard=dashboardV174;despesas=expensesV174;
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();after();return out};

    if(v168){v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.expense.data=null;v168.expense.loading=false}
    if(v169){v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null}
    window.__LTS_V174_V173_REVIEW={
      installed:true,version:'v174',base_version:'v173',public_index_changed:false,
      deep_expense_audit:true,stock_sales_extraordinary_fixed:true,monthly_resilient_full_history:true,
      card_flow_precedence:true,property_source_reconciliation:true,family_outflows_explicit:true
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V173_V172_FEEDBACK?.installed)return false;
    if(!f.d.getElementById('lts-v174-style')){const link=f.d.createElement('link');link.id='lts-v174-style';link.rel='stylesheet';link.href='lts-v174-v173-review.css?v=20260918-v174a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V174_V173_REVIEW?.installed&&!f.d.getElementById('lts-v174-runtime')){const script=f.d.createElement('script');script.id='lts-v174-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V174_V173_REVIEW?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v174-v173-review';
})();