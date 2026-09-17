(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V172_V171_REVIEW?.installed||!window.__LTS_V171_V170_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE;
    const state=window.__LTS_V172_STATE||(window.__LTS_V172_STATE={flowSequence:0,flowWarning:'',monthlyChunkCalls:0});
    const previousRpc=S.rpc.bind(S);
    async function directRpc(name,args){
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K,response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{method:'POST',headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify(args||{})}),payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status}};
        return{data:payload,error:null};
      }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
    }
    window.__LTS_V172_V171_REVIEW={
      installed:true,version:'v172',base_version:'v171',public_index_changed:false,
      flow_resilient_reader:true,default_flow_range:'previous-5-through-current-year-end',
      monthly_chunked_full_history:true,expense_source_reconciliation:true,
      professional_wealth_overview:true,morgan_decision_summary:true
    };

    const arr=v=>Array.isArray(v)?v:[];
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((total,value)=>total+(num(value)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
    const money=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const number=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{maximumFractionDigits:3}).format(Number(v));
    const usd=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const fx=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:6}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const month=v=>{const key=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const shift=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+delta);return d.toISOString().slice(0,10)};
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};

    function professionalName(value){
      const x=norm(value);
      if(x==='emprestimos e consignado')return'Empréstimos';
      if(x==='compras de cartao ainda sem categoria'||x==='faturas historicas sem compras individualizadas')return'Faturas conciliadas pelo total';
      if(x==='venda de bens e ativos')return'Venda de ações, RSUs e outros ativos';
      if(x==='mercado')return'Mercado';
      if(x==='presentes')return'Presentes';
      if(x==='amazon')return'Amazon';
      return String(value||'Outros');
    }
    function subgroupName(group,value){
      const g=professionalName(group),x=String(value||'').trim();
      if(g==='Financiamento imobiliário')return /^casa$/i.test(x)?'Financiamento imobiliário — Casa':/^cip[oó] 396$/i.test(x)?'Financiamento imobiliário — CIPÓ 396':x;
      if(g==='Empréstimos'&&/^consignado/i.test(x))return'Empréstimo consignado · Coopharma';
      return professionalName(x);
    }
    function usefulSubgroups(group,rows){
      const seen=new Map();
      for(const row of arr(rows)){
        const name=subgroupName(group,row.name),key=norm(name);
        if(!key||key===norm(professionalName(group)))continue;
        const current=seen.get(key)||{name,total:0,rows:0};
        current.total+=(num(row.total)||0);current.rows+=(num(row.rows)||0);seen.set(key,current);
      }
      return [...seen.values()].sort((a,b)=>b.total-a.total);
    }
    function coverageGroup(data){
      const c=data?.coverage_disclosure||{},total=num(c.total)||0;if(total<=0)return null;
      const origins=new Map();
      for(const row of arr(c.by_origin)){
        const name=String(row.name||'Cartão não identificado'),key=norm(name),current=origins.get(key)||{name,total:0,rows:0};
        current.total+=(num(row.total)||0);current.rows+=(num(row.rows)||0);origins.set(key,current);
      }
      return{name:'Faturas conciliadas pelo total',total,rows:num(c.rows)||0,subgroups:[...origins.values()].sort((a,b)=>b.total-a.total)};
    }
    function displayGroups(data,includeCoverage=false){
      const groups=arr(data?.management_groups).map(group=>({
        ...group,name:professionalName(group.name),subgroups:usefulSubgroups(group.name,group.subgroups)
      }));
      if(includeCoverage){const coverage=coverageGroup(data);if(coverage)groups.push(coverage)}
      return groups.sort((a,b)=>(num(b.total)||0)-(num(a.total)||0));
    }
    function rank(groups,limit=15,details=false){
      const rows=arr(groups).filter(x=>num(x.total)!=null).slice(0,limit),top=Math.max(1,...rows.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v172-rank">'+(rows.map((row,index)=>{
        const children=usefulSubgroups(row.name,row.subgroups);
        return '<div class="v172-rankrow"><span>'+(index+1)+'</span><div><b>'+esc(professionalName(row.name))+'</b><i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+(details&&children.length?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(child.name)+'</span><b>'+money(child.total)+'</b></em>').join('')+'</details>':'')+'</div><strong>'+money(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{},count=num(c.rows)||0;return (num(c.total)||0)>0?'<div class="v172-coverage"><b>Faturas conciliadas pelo total</b><strong>'+money(c.total)+'</strong><span>Este valor já está incluído nas despesas de cartão e não representa uma categoria adicional. Em '+count+' ciclo(s), a fonte histórica contém o total da fatura, mas não as compras individuais necessárias para uma divisão confiável por tipo de gasto.</span></div>':'';
    }

    function dashboardV172(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard'),data=v168?.dashboard?.data?.expense||{};if(!root)return t.innerHTML;
      const card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&displayGroups(data).length){
        card.querySelectorAll('.v171-rank,.v171-reconciliation,.v170-rank,.v170-audit,.v169-coverage').forEach(x=>x.remove());
        const caption=card.querySelector('.v168-cardhead small');if(caption)caption.textContent='Top 12';
        card.insertAdjacentHTML('beforeend',rank(displayGroups(data),12,false)+coverageNote(data));
      }
      return t.innerHTML;
    }

    function matrix(title,subtitle,groups,months){
      return '<article class="v169-balance-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix v172-matrix"><thead><tr><th>Grupo</th>'+months.map(value=>'<th>'+esc(month(value))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(groups.map(group=>'<tr><th>'+esc(professionalName(group.label))+'</th>'+months.map(value=>{const item=arr(group.monthly).find(x=>String(x.month).slice(0,7)===String(value).slice(0,7)),amount=num(item?.amount)||0;return'<td>'+(amount?money(amount):'—')+'</td>'}).join('')+'<td class="total">'+money(group.total)+'</td></tr>').join('')||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste período.</td></tr>')+'</tbody></table></div></article>';
    }
    function monthlyV172(){
      const j=v169?.monthly?.data||{},tot=j.totals||{},rows=arr(j.monthly_totals),months=arr(j.months),cover=j.expense_unclassified_card_coverage||{},expenseGroups=arr(j.expense_groups).map(group=>({...group,label:professionalName(group.label)}));
      if(v169?.monthly?.loading&&!v169.monthly.data)return'<div class="v168-skeleton"></div>';
      if(v169?.monthly?.error&&!v169.monthly.data)return'<div class="v168-error">'+esc(v169.monthly.error)+'</div>';
      return '<div class="v169-monthly v171-monthly v172-monthly"><div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+money(tot.revenue)+'</strong><small>entradas recorrentes</small></article><article class="v168-kpi v171-expense-total"><span>Despesas do período</span><strong>'+money(tot.expenses)+'</strong><small>cartões e contas correntes</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+money(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+money(tot.extraordinary)+'</strong><small>vendas de ações, bens, FGTS e empréstimos</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+money(tot.cash_after_extraordinary)+'</strong><small>após entradas extraordinárias</small></article></div>'+matrix('Receitas operacionais','Receitas',arr(j.revenue_groups),months)+matrix('Entradas extraordinárias','Entradas não recorrentes',arr(j.extraordinary_groups).map(group=>({...group,label:professionalName(group.label)})),months)+matrix('Despesas por categoria','Despesas',expenseGroups,months)+((num(cover.total)||0)>0?'<div class="v172-coverage compact"><b>Faturas conciliadas pelo total</b><strong>'+money(cover.total)+'</strong><span>Incluídas no total mensal; sem divisão por categoria quando a fonte não contém as compras individuais.</span></div>':'')+'<article class="v169-balance-section"><div class="v168-cardhead"><div><span>Fechamento</span><h2>Resultado de cada mês</h2></div><small>'+months.length+' mês(es)</small></div><div class="v169-matrix-wrap"><table class="v169-matrix compact v172-matrix"><thead><tr><th>Mês</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(row=>'<tr><th>'+month(row.month)+'</th><td>'+money(row.revenue)+'</td><td>'+money(row.expenses)+'</td><td class="'+((num(row.operating_balance)||0)<0?'negative':'positive')+'">'+money(row.operating_balance)+'</td><td>'+money(row.extraordinary)+'</td><td class="'+((num(row.cash_after_extraordinary)||0)<0?'negative':'positive')+'">'+money(row.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article></div>';
    }
    function expensesV172(){
      const t=tpl(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168?.expense?.data||{},tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      if(v168.expense.tab==='overview'&&displayGroups(data).length){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelectorAll('.v171-rank,.v171-reconciliation,.v170-rank,.v170-audit,.v169-coverage').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(displayGroups(data),15,false)+coverageNote(data))}
      }
      if(v168.expense.tab==='categories'&&displayGroups(data).length){
        let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}
        tabs.insertAdjacentHTML('afterend','<article class="v168-card v172-categories"><div class="v168-cardhead"><div><span>Composição</span><h2>Despesas por categoria</h2></div><strong>'+money(data.summary?.selected_total)+'</strong></div>'+rank(displayGroups(data),99,true)+coverageNote(data)+'</article>');
      }
      if(v168.expense.tab==='monthly'){
        const old=root.querySelector('.v171-monthly,.v169-monthly,.v168-skeleton,.v168-error');if(old){const content=tpl(monthlyV172());old.replaceWith(...content.content.childNodes)}
      }
      return t.innerHTML;
    }

    function monthSpan(from,to){const a=new Date(from+'T12:00:00Z'),b=new Date(to+'T12:00:00Z');return (b.getUTCFullYear()-a.getUTCFullYear())*12+b.getUTCMonth()-a.getUTCMonth()+1}
    function yearChunks(from,to){const chunks=[];let year=Number(from.slice(0,4)),last=Number(to.slice(0,4));for(;year<=last;year++)chunks.push({from:year===Number(from.slice(0,4))?from:year+'-01-01',to:year===last?to:year+'-12-31'});return chunks}
    async function mapLimit(items,limit,worker){const output=new Array(items.length);let cursor=0;async function run(){while(true){const index=cursor++;if(index>=items.length)return;output[index]=await worker(items[index],index)}}await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return output}
    function mergeMonthlyGroups(parts,key,months){
      const groups=new Map();
      for(const part of parts)for(const row of arr(part[key])){
        const label=professionalName(row.label),id=norm(label),current=groups.get(id)||{label,total:0,source_rows:0,values:new Map()};
        current.total+=(num(row.total)||0);current.source_rows+=(num(row.source_rows)||0);
        for(const item of arr(row.monthly)){const monthKey=String(item.month).slice(0,10);current.values.set(monthKey,(current.values.get(monthKey)||0)+(num(item.amount)||0))}
        groups.set(id,current);
      }
      return [...groups.values()].map(group=>({label:group.label,total:group.total,source_rows:group.source_rows,monthly:months.map(monthKey=>({month:monthKey,amount:group.values.get(monthKey)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to){
      const months=parts.flatMap(part=>arr(part.months)).map(value=>String(value).slice(0,10)).filter((value,index,self)=>self.indexOf(value)===index).sort();
      const monthRows=parts.flatMap(part=>arr(part.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((out,key)=>(out[key]=sum(parts.map(part=>part.totals?.[key])),out),{});
      const coverageValues=new Map();let coverageTotal=0,coverageRows=0;
      for(const part of parts){const coverage=part.expense_unclassified_card_coverage||{};coverageTotal+=(num(coverage.total)||0);coverageRows+=(num(coverage.source_rows)||0);for(const item of arr(coverage.monthly)){const key=String(item.month).slice(0,10);coverageValues.set(key,(coverageValues.get(key)||0)+(num(item.amount)||0))}}
      return{...parts[0],version:'monthly-balance-v3-v172-chunked',from,to,months,monthly_totals:monthRows,totals,revenue_groups:mergeMonthlyGroups(parts,'revenue_groups',months),extraordinary_groups:mergeMonthlyGroups(parts,'extraordinary_groups',months),expense_groups:mergeMonthlyGroups(parts,'expense_groups',months),expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:coverageTotal,source_rows:coverageRows,monthly:months.map(key=>({month:key,amount:coverageValues.get(key)||0}))}};
    }
    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if((requested==='lts_browser_monthly_balance_v1'||requested==='lts_browser_monthly_balance_v2')&&/^\d{4}-\d{2}-\d{2}$/.test(next.p_from||'')&&/^\d{4}-\d{2}-\d{2}$/.test(next.p_to||'')&&monthSpan(next.p_from,next.p_to)>18){
        const chunks=yearChunks(next.p_from,next.p_to);state.monthlyChunkCalls=chunks.length;
        try{
          const parts=await mapLimit(chunks,3,async chunk=>{const response=await directRpc('lts_browser_monthly_balance_v2',{p_from:chunk.from,p_to:chunk.to});if(response?.error||!response?.data)throw Error(response?.error?.message||'Balanço mensal indisponível');return response.data});
          return{data:mergeMonthly(parts,next.p_from,next.p_to),error:null};
        }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
      }
      if(requested==='lts_browser_monthly_balance_v1')return previousRpc('lts_browser_monthly_balance_v2',next);
      return previousRpc(requested,next);
    };

    function commitment(j,id){return arr(j?.financing?.summary?.commitments).find(row=>row.id===id)||{}}
    function obligationValue(row){return num(row.remaining_scheduled_outflow_current_terms??row.remaining_scheduled_outflow??row.remaining_economic_outflow)}
    function list(rows){return '<div class="v172-value-list">'+arr(rows).filter(row=>num(row.total)!=null).map(row=>'<div><span>'+esc(row.name)+(row.note?'<small>'+esc(row.note)+'</small>':'')+'</span><b>'+money(row.total)+'</b></div>').join('')+'</div>'}
    function wealthOverview(j){
      const w=j.wealth||{},summary=w.summary||{},x=j.wealth_v167||j.wealth_v168||{},p=j.pensions||{},r=j.rsu_summary||{},m=j.morgan_statement||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},liquidity=w.liquidity||{},co=commitment(j,'coopharma'),family=commitment(j,'pai_mae'),coValue=obligationValue(co),familyValue=obligationValue(family),cash=(num(liquidity.bank_cash)||0)+(num(liquidity.d0)||0),futureNet=num(m.future_components?.future_after_reserve_brl)??num(r.future_considered_total_brl),net=x.net_worth_central_including_pensions??summary.net_worth_central,assets=x.assets_central_including_pensions??summary.assets_central;
      return '<div class="v172-wealth-overview"><div class="v168-kpis"><article class="v168-kpi primary"><span>Patrimônio líquido hoje</span><strong>'+money(net)+'</strong><small>ativos atuais menos dívidas atuais</small></article><article class="v168-kpi"><span>Bens e ativos atuais</span><strong>'+money(assets)+'</strong><small>inclui previdências</small></article><article class="v168-kpi v171-expense-total"><span>Dívidas com saldo informado</span><strong>'+money(summary.known_debt_total)+'</strong><small>financiamentos atuais</small></article><article class="v168-kpi"><span>Previdências</span><strong>'+money(p.total_gross_brl)+'</strong><small>valor bruto restrito</small></article><article class="v168-kpi"><span>A receber no futuro</span><strong>'+money(futureNet)+'</strong><small>fora do patrimônio de hoje</small></article></div><div class="v172-wealth-grid"><article class="v168-card"><div class="v168-cardhead"><div><span>Bens</span><h2>Imóvel e veículo</h2></div></div>'+list([{name:'CIPÓ 396 · valor de mercado',total:c.market_central},{name:'Volvo XC40 · valor de mercado',total:v.market_central}])+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Disponível agora</span><h2>Dinheiro e investimentos líquidos</h2></div></div>'+list([{name:'Contas + aplicações D0',total:cash},{name:'Morgan Stanley · disponível',total:m.available_total_brl??r.available_total_brl}])+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Restrito</span><h2>Previdências</h2></div><strong>'+money(p.total_gross_brl)+'</strong></div>'+list(arr(p.positions).map(row=>({name:row.name,total:row.gross_balance_brl,note:'posição '+date(row.as_of)})))+'</article><article class="v168-card v172-debts"><div class="v168-cardhead"><div><span>Dívidas</span><h2>Financiamentos e empréstimos</h2></div></div><h3>Saldos para quitação</h3>'+list([{name:'Financiamento imobiliário · CIPÓ 396',total:c.documentary_debt},{name:'Financiamento do Volvo XC40',total:v.documented_financed_balance}])+'<h3>Parcelas restantes</h3>'+list([{name:'Empréstimo consignado · Coopharma',total:coValue,note:(co.remaining_events??'—')+' parcela(s)'},{name:'Empréstimo familiar · Pai e Mãe',total:familyValue,note:(family.remaining_events??'—')+' parcela(s)'}])+'</article><article class="v168-card v172-future"><div class="v168-cardhead"><div><span>Futuro</span><h2>Compensação ainda não disponível</h2></div><strong>'+money(futureNet)+'</strong></div>'+list([{name:'RSUs futuras · bruto',total:m.future_components?.regular_rsu_gross_brl??r.future_regular_brl},{name:'Cash RSUs futuras · líquido projetado',total:m.future_components?.cash_rsu_after_reserve_brl??r.future_cash_net_brl}])+'</article></div></div>';
    }
    function awardType(row){return /cash/i.test(String(row.asset_type||''))?'Cash RSU':'RSU'}
    function rsuPanel(j){
      const r=j.rsu_summary||{},m=j.morgan_statement||{},available=m.available_components||{},future=m.future_components||{},q=m.quantities||{},recon=m.planning_schedule_reconciliation||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{},first=rows[0]||{},pairs=[...new Set(rows.map(row=>String(row.unit_price_usd)+'|'+String(row.fx_rate)))],mixed=pairs.length>1,gross=m.gross_total_brl??((num(r.available_total_brl)||0)+(num(r.future_regular_brl)||0)+(num(r.future_cash_net_brl)||0)),futureNet=future.future_after_reserve_brl??r.future_considered_total_brl,totalNet=m.considered_total_after_reserve_brl??((num(m.available_total_brl??r.available_total_brl)||0)+(num(futureNet)||0));
      return '<div class="v172-morgan"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total bruto do extrato</span><strong>'+money(gross)+'</strong><small>posição Morgan Stanley em '+date(m.as_of||r.as_of)+'</small></article><article class="v168-kpi"><span>Disponível agora</span><strong>'+money(m.available_total_brl??r.available_total_brl)+'</strong><small>ações vested + saldo em corretora</small></article><article class="v168-kpi"><span>A receber líquido projetado</span><strong>'+money(futureNet)+'</strong><small>RSUs futuras + Cash RSUs após reserva</small></article><article class="v168-kpi"><span>Total líquido projetado</span><strong>'+money(totalNet)+'</strong><small>disponível agora + futuro líquido</small></article></div><div class="v172-morgan-components"><article><span>Disponível agora</span><h3>'+money(m.available_total_brl??r.available_total_brl)+'</h3><dl><dt>Ações vested</dt><dd>'+money(available.vested_shares_brl??r.vested_shares_brl)+'</dd><dt>Saldo em corretora</dt><dd>'+money(available.brokerage_cash_brl??r.brokerage_cash_brl)+'</dd></dl></article><article><span>RSUs futuras</span><h3>'+money(future.regular_rsu_gross_brl)+'</h3><small>'+number(q.future_regular_rsu)+' unidades · valor bruto</small></article><article><span>Cash RSUs futuras</span><h3>'+money(future.cash_rsu_after_reserve_brl)+'</h3><small>'+number(q.future_cash_rsu)+' unidades · líquido projetado</small></article></div><div class="v168-note">As Cash RSUs futuras usam uma reserva de 30% somente para o planejamento do valor líquido.</div></div><article class="v168-card v170-global-award"><div class="v168-cardhead"><div><span>Cotação única</span><h2>Atualizar todos os vestings</h2></div><small>'+rows.length+' vesting(s) ativo(s)</small></div><div class="v170-global-form"><label>Preço da ação (USD)<input id="v170AllAwardPrice" type="number" min="0.01" max="10000" step="0.01" value="'+esc(first.unit_price_usd??'')+'"></label><label>Câmbio USD/BRL<input id="v170AllAwardFx" type="number" min="0.0001" max="100" step="0.000001" value="'+esc(first.fx_rate??'')+'"></label><button class="v168-btn primary" id="v170AllAwardApply" '+(window.__LTS_V170_STATE?.globalAward?.saving?'disabled':'')+'>'+(window.__LTS_V170_STATE?.globalAward?.saving?'Atualizando todos…':'Aplicar a todos os vestings')+'</button></div><div class="v170-global-help">'+(mixed?'As premissas atuais variam. Ao aplicar, todos os vestings receberão os mesmos valores.':'A mesma cotação e o mesmo câmbio serão aplicados a RSUs e Cash RSUs.')+'</div>'+(window.__LTS_V170_STATE?.globalAward?.message?'<div class="v168-note good">'+esc(window.__LTS_V170_STATE.globalAward.message)+'</div>':'')+(window.__LTS_V170_STATE?.globalAward?.error?'<div class="v168-note warn">'+esc(window.__LTS_V170_STATE.globalAward.error)+'</div>':'')+'</article><article class="v168-card"><div class="v168-cardhead"><div><span>Agenda</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(futureNet)+'</strong></div><div class="v170-reconciliation"><span>Extrato e agenda permanecem separados para conferência.</span><small>RSU: diferença '+money(recon.regular_delta_brl)+' · Cash RSU bruto: diferença '+money(recon.cash_delta_brl)+'.</small></div><div class="v168-awards">'+rows.map((row,index)=>{const type=awardType(row),value=type==='Cash RSU'?row.net_value_brl:row.gross_value_brl;return'<div class="v168-award"><div><span>Vesting</span><b>'+date(row.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(row.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(row.unit_price_usd)+'</b><small>câmbio '+fx(row.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(row.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+index+'" max="'+esc(row.eligibility_date)+'" value="'+esc(row.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+index+'">Cotação individual</button> <button class="v168-btn blue" data-v168-award-save="'+index+'">Salvar data</button></div></div>'}).join('')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div></article>';
    }
    function wealthV172(){
      const t=tpl(baseWealth()),root=t.content.querySelector('.v168-wealth'),tabs=root?.querySelector('.v168-tabs'),j=v168?.wealth?.data||{};if(!root||!tabs)return t.innerHTML;
      if(v168.wealth.tab==='overview'&&j.wealth){let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}tabs.insertAdjacentHTML('afterend',wealthOverview(j))}
      if(v168.wealth.tab==='rsu'&&j.morgan_statement){let node=tabs.nextSibling;while(node){const next=node.nextSibling;node.remove();node=next}tabs.insertAdjacentHTML('afterend',rsuPanel(j))}
      return t.innerHTML;
    }

    function defaultRange(){const current=today();return{from:shift(current,-5),to:current.slice(0,4)+'-12-31'}}
    function isLegacyDefault(from,to){const current=today(),nextYear=String(Number(current.slice(0,4))+1)+'-12-31';return from===shift(current,-5)&&(to===nextYear||to===shift(current,30))}
    function uniqueRows(rows,dateKey,extraKey){const seen=new Map();for(const row of rows){const key=String(row?.[dateKey]||'')+'|'+String(row?.[extraKey]||'')+'|'+String(row?.source_ref||'');seen.set(key,row)}return[...seen.values()].sort((a,b)=>String(a?.[dateKey]).localeCompare(String(b?.[dateKey])))}
    function mergeFlows(parts,from,to){
      const flows=parts.map(part=>part?.data?.flow).filter(Boolean),base=flows.reduce((out,flow)=>({...out,...flow}),{}),historicalDays=uniqueRows(flows.flatMap(flow=>arr(flow.historical?.days)),'date',''),historicalEvents=uniqueRows(flows.flatMap(flow=>arr(flow.historical?.events)),'event_date','description'),futureDays=uniqueRows(flows.flatMap(flow=>arr(flow.current_future?.days)),'date',''),futureEvents=uniqueRows(flows.flatMap(flow=>arr(flow.current_future?.events)),'event_date','description');
      return{...base,from,to,historical:{...(base.historical||{}),days:historicalDays,events:historicalEvents},current_future:{...(base.current_future||{}),days:futureDays,events:futureEvents}};
    }
    async function flowPart(name,from,to){const response=await directRpc(name,{p_from:from,p_to:to});if(response?.error||!response?.data?.flow)throw Error(response?.error?.message||'Fluxo indisponível');return response}
    async function performFlowRange(from,to){
      const current=today(),seq=++state.flowSequence,yesterday=shift(current,-1),calls=[];state.flowWarning='';FLOWLOADING=true;FLOWFROM=from;FLOWTO=to;FLOWPRESET=from===shift(current,-5)&&to===current.slice(0,4)+'-12-31'?'5 anteriores + fim de '+current.slice(0,4):FLOWPRESET;if(V==='Fluxo Diário')render();
      if(from<current)calls.push({kind:'history',promise:flowPart('lts_browser_flow_v11',from,to<current?to:yesterday)});
      if(to>=current)calls.push({kind:'future',promise:flowPart('lts_browser_flow_v12',from>current?from:current,to)});
      const settled=await Promise.allSettled(calls.map(call=>call.promise));if(seq!==state.flowSequence)return;
      const good=settled.filter(item=>item.status==='fulfilled').map(item=>item.value),failed=settled.filter(item=>item.status==='rejected');
      if(!good.length){FLOWQ={error:'Não foi possível carregar este período. Tente novamente.',historical:{days:[],events:[]},current_future:{days:[],events:[]}};FLOWLOADING=false;if(V==='Fluxo Diário')render();return}
      FLOWQ=mergeFlows(good,from,to);FLOWLOADING=false;if(failed.length)state.flowWarning='Uma parte do período não pôde ser atualizada. Os dados disponíveis continuam visíveis.';if(V==='Fluxo Diário')render();
      if(from<current){const historicalTo=to<current?to:yesterday;flowPart('lts_browser_flow_v12',from,historicalTo).then(upgrade=>{if(seq!==state.flowSequence)return;FLOWQ={...FLOWQ,...upgrade.data.flow,from,to,historical:upgrade.data.flow.historical,current_future:FLOWQ.current_future};if(V==='Fluxo Diário')render()}).catch(()=>{})}
    }
    loadFlowRange=function(from,to){
      if(isLegacyDefault(from,to)){const range=defaultRange();from=range.from;to=range.to}const key=from+'|'+to;
      if(state.rangePending?.key===key)return state.rangePending.promise;
      const promise=performFlowRange(from,to);state.rangePending={key,promise};
      promise.finally(()=>setTimeout(()=>{if(state.rangePending?.promise===promise)state.rangePending=null},1200));return promise;
    };
    function openDefault(){
      const range=defaultRange(),key=range.from+'|'+range.to;SHOWZERO=true;FLOWFORCEZERO=false;
      if(state.defaultPending?.key===key)return state.defaultPending.promise;
      const promise=Promise.resolve(loadFlowRange(range.from,range.to));state.defaultPending={key,promise};
      promise.finally(()=>setTimeout(()=>{if(state.defaultPending?.promise===promise)state.defaultPending=null},1200));return promise;
    }
    function bindFlow(){
      const activate=()=>{V='Fluxo Diário';if(window.__LTS_V170_STATE)window.__LTS_V170_STATE.lastRoute=V;renderNav();openDefault()};
      document.querySelectorAll('.nav [data-v="Fluxo Diário"],#dx1MobileNav [data-mobile-route="Fluxo Diário"]').forEach(button=>button.onclick=activate);
      if(V!=='Fluxo Diário')return;const range=defaultRange(),button=document.getElementById('flowDefaultRange');if(button){button.textContent='5 anteriores + fim de '+range.to.slice(0,4);button.title='Cinco dias anteriores até 31 de dezembro do ano corrente';button.classList.toggle('active',FLOWFROM===range.from&&FLOWTO===range.to);button.onclick=openDefault}const todayButton=document.getElementById('goToday');if(todayButton)todayButton.onclick=openDefault;
      document.querySelectorAll('.v168-history-note').forEach(node=>node.remove());document.querySelector('.v172-flow-warning')?.remove();if(state.flowWarning){document.querySelector('.flow-sticky-controls')?.insertAdjacentHTML('beforeend','<div class="v172-flow-warning">'+esc(state.flowWarning)+'</div>')}
    }
    function stamp(){const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v172Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();bindFlow()}

    dashboard=dashboardV172;despesas=expensesV172;patrimonio=wealthV172;
    render=function(){const out=baseRender();after();return out};renderNav=function(){const out=baseNav();stamp();bindFlow();return out};
    if(v168){v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.expense.data=null;v168.expense.loading=false}if(v169){v169.monthly.data=null;v169.monthly.key='';v169.monthly.error=null}
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f||!f.w.__LTS_V171_V170_REVIEW?.installed)return false;if(!f.d.getElementById('lts-v172-style')){const link=f.d.createElement('link');link.id='lts-v172-style';link.rel='stylesheet';link.href='lts-v172-v171-review.css?v=20260917-v172a';f.d.head.appendChild(link)}if(!f.w.__LTS_V172_V171_REVIEW?.installed&&!f.d.getElementById('lts-v172-runtime')){const script=f.d.createElement('script');script.id='lts-v172-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}const ready=f.w.__LTS_V172_V171_REVIEW?.installed===true;if(ready&&gate)gate.remove();return ready}
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v172-v171-review';
})();
