(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V175_EXPENSE_AUDIT?.installed||!window.__LTS_V174_V173_REVIEW?.installed)return;

    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas;
    const v168=window.__LTS_V168_STATE,v169=window.__LTS_V169_STATE,v171=window.__LTS_V171_STATE||{};
    const state=window.__LTS_V175_STATE||(window.__LTS_V175_STATE={
      expense:{key:'',data:null,loading:false,error:null,token:0},
      monthly:{key:'',data:null,loading:false,error:null,token:0,mode:'',year:null,progress:''},
      cards:{data:null,loading:false,error:null,token:0,bank:'Todos'},
      lastRoute:null
    });
    const previousRpc=S.rpc.bind(S);

    const arr=v=>Array.isArray(v)?v:[];
    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const sum=xs=>arr(xs).reduce((s,x)=>s+(num(x)||0),0);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const brl=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const monthLabel=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const yearOf=v=>String(v||'').slice(0,4);
    const tpl=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
    const addMonths=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z'),day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+delta);const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));return d.toISOString().slice(0,10)};

    function expenseRange(){
      const s=v168?.expense||{},t=today(),year=t.slice(0,4);
      if(s.key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t,label:'6 meses'};
      if(s.key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t,label:'12 meses'};
      if(s.key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};
      if(s.key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom||'')&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo,label:'Personalizado'};
      return{from:year+'-01-01',to:t,label:'Ano atual'};
    }

    async function directRpc(name,args,timeoutMs=18000){
      const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeoutMs);
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K;
        const response=await fetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{
          method:'POST',
          headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},
          body:JSON.stringify(args||{}),
          signal:controller.signal
        });
        const payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status)),status:response.status}};
        return{data:payload,error:null};
      }catch(error){
        return{data:null,error:{message:error?.name==='AbortError'?'Tempo de leitura excedido.':String(error?.message||error)}};
      }finally{clearTimeout(timer)}
    }

    function yearChunks(from,to){
      const out=[],first=Number(from.slice(0,4)),last=Number(to.slice(0,4));
      for(let y=first;y<=last;y++)out.push({from:y===first?from:y+'-01-01',to:y===last?to:y+'-12-31'});
      return out;
    }
    async function mapLimit(items,limit,worker){
      const out=new Array(items.length);let cursor=0;
      async function run(){while(true){const i=cursor++;if(i>=items.length)return;try{out[i]={ok:true,value:await worker(items[i],i)}}catch(error){out[i]={ok:false,error}}}}
      await Promise.all(Array.from({length:Math.min(limit,items.length)},run));return out;
    }
    function mergeGroups(parts,key,months){
      const map=new Map();
      for(const part of parts)for(const row of arr(part?.[key])){
        const label=String(row.label||row.name||'Outros'),id=norm(label),cur=map.get(id)||{label,total:0,source_rows:0,values:new Map()};
        cur.total+=(num(row.total)||0);cur.source_rows+=(num(row.source_rows??row.rows)||0);
        for(const item of arr(row.monthly)){const k=String(item.month).slice(0,10);cur.values.set(k,(cur.values.get(k)||0)+(num(item.amount)||0))}
        map.set(id,cur);
      }
      return [...map.values()].map(g=>({label:g.label,total:g.total,source_rows:g.source_rows,monthly:months.map(k=>({month:k,amount:g.values.get(k)||0}))})).sort((a,b)=>b.total-a.total);
    }
    function mergeMonthly(parts,from,to,failed){
      const months=parts.flatMap(x=>arr(x.months)).map(x=>String(x).slice(0,10)).filter((x,i,a)=>a.indexOf(x)===i).sort();
      const monthlyTotals=parts.flatMap(x=>arr(x.monthly_totals)).sort((a,b)=>String(a.month).localeCompare(String(b.month)));
      const totals=['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'].reduce((o,k)=>(o[k]=sum(parts.map(x=>x?.totals?.[k])),o),{});
      const coverageMap=new Map();let coverageTotal=0,coverageRows=0;
      for(const part of parts){
        const c=part?.expense_unclassified_card_coverage||{};coverageTotal+=(num(c.total)||0);coverageRows+=(num(c.source_rows)||0);
        for(const m of arr(c.monthly)){const k=String(m.month).slice(0,10);coverageMap.set(k,(coverageMap.get(k)||0)+(num(m.amount)||0))}
      }
      const stockMap=new Map();let stockTotal=0;
      for(const part of parts){
        const s=part?.stock_sale_supplement||{};stockTotal+=(num(s.total)||0);
        for(const m of arr(s.monthly)){const k=String(m.month).slice(0,10),cur=stockMap.get(k)||{amount:0,source_rows:0};cur.amount+=(num(m.amount)||0);cur.source_rows+=(num(m.source_rows)||0);stockMap.set(k,cur)}
      }
      const issues=new Map();
      for(const part of parts)for(const issue of arr(part?.open_audit_issues)){if(issue?.issue_id)issues.set(issue.issue_id,issue)}
      return{
        ...parts[0],version:'monthly-balance-v5-v175-annual-fallback',from,to,months,monthly_totals,totals,
        revenue_groups:mergeGroups(parts,'revenue_groups',months),
        extraordinary_groups:mergeGroups(parts,'extraordinary_groups',months),
        expense_groups:mergeGroups(parts,'expense_groups',months),
        expense_unclassified_card_coverage:{label:'Faturas conciliadas pelo total',total:coverageTotal,source_rows:coverageRows,monthly:months.map(k=>({month:k,amount:coverageMap.get(k)||0}))},
        stock_sale_supplement:{total:stockTotal,monthly:months.map(k=>({month:k,amount:stockMap.get(k)?.amount||0,source_rows:stockMap.get(k)?.source_rows||0}))},
        open_audit_issues:[...issues.values()],
        partial_year_failures:failed
      };
    }

    async function loadMonthly(from,to){
      state.monthly.progress='Carregando todo o período…';
      const full=await directRpc('lts_browser_monthly_balance_v5',{p_from:from,p_to:to},14000);
      if(!full.error&&full.data)return{data:full.data,mode:'direct'};
      const chunks=yearChunks(from,to);
      state.monthly.progress='Leitura anual progressiva…';if(V==='Despesas'&&v168?.expense?.tab==='monthly')render();
      const settled=await mapLimit(chunks,3,async chunk=>{
        const r=await directRpc('lts_browser_monthly_balance_v5',{p_from:chunk.from,p_to:chunk.to},12000);
        if(r.error||!r.data)throw Error(r.error?.message||'Ano indisponível');
        return{chunk,data:r.data};
      });
      const good=settled.filter(x=>x.ok).map(x=>x.value.data),failed=settled.map((x,i)=>x.ok?null:chunks[i]).filter(Boolean);
      if(failed.length)return{error:'Histórico incompleto: '+failed.map(x=>x.from.slice(0,4)).join(', ')+'. Tente novamente; nenhum total parcial será exibido.'};
      if(!good.length)return{error:full.error?.message||'Balanço mensal indisponível.'};
      return{data:mergeMonthly(good,from,to,failed),mode:'annual-fallback'};
    }

    async function ensureMonthly(force=false){
      const r=expenseRange(),key=r.from+'|'+r.to,s=state.monthly;
      if(s.loading||(!force&&s.data&&s.key===key))return;
      const token=++s.token;s.key=key;s.loading=true;s.error=null;s.progress='Preparando balanço…';
      if(V==='Despesas'&&v168?.expense?.tab==='monthly')render();
      try{
        const result=await loadMonthly(r.from,r.to);
        if(token!==s.token)return;
        if(result.error||!result.data)throw Error(result.error||'Balanço indisponível');
        s.data=result.data;s.mode=result.mode||'direct';
        const years=[...new Set(arr(s.data.months).map(yearOf))].filter(Boolean);
        if(!years.includes(String(s.year)))s.year=years.at(-1)||today().slice(0,4);
      }catch(error){if(token===s.token){s.error=String(error?.message||error);s.data=null}}
      finally{if(token===s.token){s.loading=false;s.progress='';if(V==='Despesas'&&v168?.expense?.tab==='monthly')render()}}
    }

    async function ensureExpense(force=false){
      const r=expenseRange(),key=r.from+'|'+r.to,s=state.expense;
      if(s.loading||(!force&&s.data&&s.key===key))return;
      const token=++s.token;s.key=key;s.loading=true;s.error=null;
      try{
        const result=await directRpc('lts_browser_expense_executive_v8',{p_from:r.from,p_to:r.to},18000);
        if(token!==s.token)return;
        if(result.error||!result.data)throw Error(result.error?.message||'Despesas indisponíveis');
        s.data=result.data;
      }catch(error){if(token===s.token){s.error=String(error?.message||error);s.data=null}}
      finally{if(token===s.token){s.loading=false;if(V==='Despesas'&&['overview','categories'].includes(v168?.expense?.tab))render()}}
    }

    async function ensureCards(force=false){
      const s=state.cards;if(s.loading||(!force&&s.data))return;
      const token=++s.token;s.loading=true;s.error=null;
      if(V==='Despesas'&&v168?.expense?.tab==='cards')render();
      try{
        const from=today(),to=String(Number(from.slice(0,4))+1)+'-12-31';
        const result=await directRpc('lts_browser_card_flow_schedule_v2',{p_from:from,p_to:to},18000);
        if(token!==s.token)return;
        if(result.error||!result.data)throw Error(result.error?.message||'Cartões indisponíveis');
        s.data=result.data;
      }catch(error){if(token===s.token){s.error=String(error?.message||error);s.data=null}}
      finally{if(token===s.token){s.loading=false;if(V==='Despesas'&&v168?.expense?.tab==='cards')render()}}
    }

    S.rpc=async function(name,args){
      const requested=String(name||''),next={...(args||{})};
      if(['lts_browser_expense_executive_v4','lts_browser_expense_executive_v5','lts_browser_expense_executive_v6','lts_browser_expense_executive_v7','lts_browser_expense_executive_v8'].includes(requested))
        return directRpc('lts_browser_expense_executive_v8',next,18000);
      if(['lts_browser_monthly_balance_v1','lts_browser_monthly_balance_v2','lts_browser_monthly_balance_v3','lts_browser_monthly_balance_v5'].includes(requested))
        return directRpc('lts_browser_monthly_balance_v5',next,18000);
      if(['lts_browser_card_flow_schedule_v1','lts_browser_card_flow_schedule_v2'].includes(requested))
        return directRpc('lts_browser_card_flow_schedule_v2',next,18000);
      return previousRpc(requested,next);
    };

    function usefulChildren(group){
      const parent=norm(group?.name||group?.label),map=new Map();
      for(const child of arr(group?.subgroups)){
        const name=String(child.name||child.label||'').trim(),key=norm(name);
        if(!key||key===parent)continue;
        const cur=map.get(key)||{name,total:0,rows:0,origins:child.origins||''};cur.total+=(num(child.total)||0);cur.rows+=(num(child.rows)||0);if(child.origins)cur.origins=child.origins;map.set(key,cur);
      }
      const children=[...map.values()].sort((a,b)=>b.total-a.total);
      if(parent==='financiamento imobiliario')return[];
      if(children.length===1&&norm(children[0].name)===parent)return[];
      return children;
    }

    function rank(groups,limit=99,details=true){
      const xs=arr(groups).filter(x=>num(x.total)!=null).sort((a,b)=>(num(b.total)||0)-(num(a.total)||0)).slice(0,limit),top=Math.max(1,...xs.map(x=>Math.abs(num(x.total)||0)));
      return '<div class="v175-rank">'+(xs.map((row,index)=>{
        const children=usefulChildren(row),loan=norm(row.name)==='emprestimos';
        return '<div class="v175-rankrow"><span>'+(index+1)+'</span><div><div class="v175-rank-title"><b>'+esc(row.name||row.label||'Outros')+'</b>'+(row.source_reconciled?'<small>fonte reconciliada</small>':'')+'</div><i><u style="width:'+Math.max(2,Math.abs(num(row.total)||0)/top*100)+'%"></u></i>'+
          (details&&children.length>1?'<details><summary>Ver composição</summary>'+children.map(child=>'<em><span>'+esc(child.name)+(child.origins?'<small>'+esc(child.origins)+'</small>':'')+'</span><b>'+brl(child.total)+'</b></em>').join('')+(loan?'<p class="v175-detail-note">Valores acima são pagamentos históricos, não saldo devedor atual.</p>':'')+'</details>':'')+
          '</div><strong>'+brl(row.total)+'</strong></div>';
      }).join('')||'<div class="v168-empty">Sem despesas no período selecionado.</div>')+'</div>';
    }

    function propertyNote(data){
      const p=data?.property_improvement_reconciliation||{};if(num(p.reconciled_unique_brl)==null)return'';
      return '<div class="v175-property"><div><span>Planilha original</span><b>'+brl(p.workbook_summary_brl)+'</b></div><div><span>Duplicidade Móveis</span><b>− '+brl(p.duplicate_source_brl)+'</b></div><div class="primary"><span>Obra/reforma reconciliada</span><b>'+brl(p.reconciled_unique_brl)+'</b></div><p>O total reconciliado preserva os componentes econômicos únicos. '+brl(p.historical_card_coverage_gap_brl)+' continuam como evidência histórica agregada de cartão sem datas de compra inventadas.</p></div>';
    }
    function coverageNote(data){
      const c=data?.coverage_disclosure||{};if((num(c.total)||0)<=0)return'';
      return '<div class="v175-coverage"><b>Faturas ainda sem composição individual completa</b><strong>'+brl(c.total)+'</strong><span>O total permanece nas despesas. O LTS só atribui categoria quando a fonte fecha exatamente; não distribui fatura por hipótese.</span></div>';
    }

    function annualRows(data){
      const map=new Map();
      for(const row of arr(data?.monthly_totals)){
        const y=yearOf(row.month),cur=map.get(y)||{year:y,revenue:0,expenses:0,operating_balance:0,extraordinary:0,cash_after_extraordinary:0,months:0};
        for(const k of ['revenue','expenses','operating_balance','extraordinary','cash_after_extraordinary'])cur[k]+=(num(row[k])||0);
        cur.months++;map.set(y,cur);
      }
      return [...map.values()].sort((a,b)=>a.year.localeCompare(b.year));
    }
    function annualTable(data){
      const rows=annualRows(data);
      return '<article class="v175-section"><div class="v168-cardhead"><div><span>Histórico completo</span><h2>Resultado anual</h2></div><small>'+rows.length+' ano(s)</small></div><div class="v175-tablewrap"><table class="v175-table compact"><thead><tr><th>Ano</th><th>Receitas</th><th>Despesas</th><th>Resultado operacional</th><th>Extraordinárias</th><th>Resultado final</th></tr></thead><tbody>'+rows.map(x=>'<tr><th>'+esc(x.year)+'</th><td>'+brl(x.revenue)+'</td><td>'+brl(x.expenses)+'</td><td class="'+(x.operating_balance<0?'negative':'positive')+'">'+brl(x.operating_balance)+'</td><td>'+brl(x.extraordinary)+'</td><td class="'+(x.cash_after_extraordinary<0?'negative':'positive')+'">'+brl(x.cash_after_extraordinary)+'</td></tr>').join('')+'</tbody></table></div></article>';
    }
    function yearGroups(groups,year){
      return arr(groups).map(g=>{
        const monthly=arr(g.monthly).filter(x=>yearOf(x.month)===String(year)),total=sum(monthly.map(x=>x.amount));
        return{...g,total,monthly};
      }).filter(g=>Math.abs(num(g.total)||0)>0).sort((a,b)=>Math.abs(num(b.total)||0)-Math.abs(num(a.total)||0));
    }
    function coverageMap(data,year){
      const map=new Map();for(const m of arr(data?.expense_unclassified_card_coverage?.monthly))if(yearOf(m.month)===String(year))map.set(String(m.month).slice(0,10),num(m.amount)||0);return map;
    }
    function yearMonths(data,year){return arr(data?.months).map(x=>String(x).slice(0,10)).filter(x=>yearOf(x)===String(year))}
    function matrix(title,subtitle,groups,months,expense,data){
      const cov=coverageMap(data,state.monthly.year);
      return '<article class="v175-section"><div class="v168-cardhead"><div><span>'+esc(subtitle)+'</span><h2>'+esc(title)+'</h2></div><small>'+groups.length+' grupo(s)</small></div><div class="v175-tablewrap"><table class="v175-table"><thead><tr><th>Grupo</th>'+months.map(m=>'<th>'+esc(monthLabel(m))+'</th>').join('')+'<th>Total</th></tr></thead><tbody>'+(
        groups.map(g=>'<tr><th>'+esc(g.label||g.name)+'</th>'+months.map(m=>{const item=arr(g.monthly).find(x=>String(x.month).slice(0,10)===m),value=num(item?.amount)||0,unknown=expense&&value===0&&(cov.get(m)||0)>0;return'<td class="'+(unknown?'unknown':'')+'">'+(value?brl(value):unknown?'—*':'—')+'</td>'}).join('')+'<td class="total">'+brl(g.total)+'</td></tr>').join('')
        ||'<tr><td colspan="'+(months.length+2)+'" class="v168-empty">Sem valores neste ano.</td></tr>')+'</tbody></table></div></article>';
    }
    function auditIssues(data){
      const issues=arr(data?.open_audit_issues);if(!issues.length)return'';
      return '<div class="v175-open-issues">'+issues.map(x=>'<div><b>Pendência de fonte</b><strong>'+esc(x.title)+'</strong><span>'+esc(x.detail)+'</span></div>').join('')+'</div>';
    }
    function monthlyPanel(){
      const s=state.monthly;
      if(s.loading&&!s.data)return'<div class="v175-loading"><div class="v168-skeleton"></div><b>'+esc(s.progress||'Carregando…')+'</b><span>O relatório completo é lido sem montar 156 colunas na tela.</span></div>';
      if(s.error&&!s.data)return'<div class="v168-error">'+esc(s.error)+'</div><button class="v168-btn primary" data-v175-month-retry>Tentar novamente</button>';
      const j=s.data||{},tot=j.totals||{},years=[...new Set(arr(j.months).map(yearOf))].filter(Boolean),selected=years.includes(String(s.year))?String(s.year):years.at(-1),months=yearMonths(j,selected);
      s.year=selected;
      const revenue=yearGroups(j.revenue_groups,selected),extra=yearGroups(j.extraordinary_groups,selected),expense=yearGroups(j.expense_groups,selected),stock=j.stock_sale_supplement||{};
      const pendingApr=arr(j.open_audit_issues).some(x=>x.issue_id==='stock_sale_2026_04_missing_source');
      return '<div class="v175-monthly">'+
        '<div class="v168-kpis"><article class="v168-kpi primary"><span>Receitas operacionais</span><strong>'+brl(tot.revenue)+'</strong><small>todo o período selecionado</small></article><article class="v168-kpi"><span>Despesas</span><strong>'+brl(tot.expenses)+'</strong><small>contas + cartões, uma vez</small></article><article class="v168-kpi"><span>Resultado operacional</span><strong>'+brl(tot.operating_balance)+'</strong><small>receitas menos despesas</small></article><article class="v168-kpi"><span>Entradas extraordinárias</span><strong>'+brl(tot.extraordinary)+'</strong><small>ações separadas de transferências</small></article><article class="v168-kpi"><span>Resultado final</span><strong>'+brl(tot.cash_after_extraordinary)+'</strong><small>após extraordinárias</small></article></div>'+
        '<div class="v175-sale-strip"><div><span>Venda de ações, RSUs e outros ativos</span><b>'+brl(stock.total)+'</b><small>Set/26 recuperado em R$ 18.808,69; transferências posteriores continuam neutras.'+(pendingApr?' Abril/26 permanece aberto porque a fonte do crédito ainda não foi localizada.':'')+'</small></div></div>'+
        auditIssues(j)+annualTable(j)+
        '<div class="v175-yearbar"><div><span>Detalhe mensal</span><b>Escolha o ano</b></div><select data-v175-year aria-label="Ano do detalhe mensal">'+years.map(y=>'<option value="'+esc(y)+'" '+(y===selected?'selected':'')+'>'+esc(y)+'</option>').join('')+'</select><small>'+(s.mode==='annual-fallback'?'carregamento anual de contingência':'leitura integral concluída')+'</small></div>'+
        matrix('Receitas operacionais',selected,revenue,months,false,j)+
        matrix('Entradas extraordinárias',selected,extra,months,false,j)+
        matrix('Despesas por categoria',selected,expense,months,true,j)+
        ((num(j.expense_unclassified_card_coverage?.total)||0)>0?'<div class="v175-coverage"><b>—* não significa zero.</b><strong>'+brl(j.expense_unclassified_card_coverage.total)+'</strong><span>Há faturas históricas cujo total é conhecido, mas a composição individual ainda não está documentada. Categorias recuperadas do workbook só entram quando o total do mês fecha exatamente.</span></div>':'')+
        '</div>';
    }

    function canonicalInventoryName(card){
      const bank=card.bank||'',name=card.card_name||'',last=card.last4?(' · final '+card.last4):'';
      if(bank==='Bradesco'&&/Visa Infinite Prime/i.test(name))return'Visa'+last;
      if(bank==='Itaú'&&/Mastercard Black/i.test(name))return'Mastercard Black Itaú';
      if(bank==='C6'&&/histórico/i.test(name))return'C6 histórico'+last;
      if(bank==='C6'&&/C6 Carbon/i.test(name))return'C6 Carbon'+last;
      return name+last;
    }
    function inventoryPanel(data){
      const cards=arr(data?.inventory?.cards),groups=new Map();
      for(const card of cards){const b=card.bank||'Outros';if(!groups.has(b))groups.set(b,[]);groups.get(b).push(card)}
      return '<article class="v168-card v175-inventory"><div class="v168-cardhead"><div><span>Inventário histórico</span><h2>Todos os cartões documentados</h2></div><small>ativos e históricos</small></div><div class="v175-inventory-grid">'+[...groups.entries()].map(([bank,rows])=>'<section><header>'+esc(bank)+'</header>'+rows.map(card=>'<div><b>'+esc(canonicalInventoryName(card))+'</b><span>'+esc(card.status==='historical'?'Histórico':'Atual/recente')+'</span><small>'+esc(card.first_seen||'—')+' → '+esc(card.last_seen||'—')+'</small></div>').join('')+'</section>').join('')+'</div></article>';
    }
    function cardBank(name){const n=norm(name);if(n.includes('aeternum')||n.includes('bradesco'))return'Bradesco';if(n.includes('c6')||n.includes('carbon')||n.includes('7873')||n.includes('8304')||n.includes('6610'))return'C6';if(n.includes('personnalite')||n.includes('mastercard')||n.includes('itau')||n.includes('itaú'))return'Itaú';return'Outros'}
    function cardKey(name){const n=norm(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('carbon'))return'c6';if(n.includes('mastercard')||n.includes('personnalite'))return'mastercard-itau';if(n.includes('visa infinite prime'))return'visa-prime';if(n.includes('visa infinite')&&n.includes('itau'))return'visa-infinite-itau';return n.replace(/\W+/g,'-')}
    function cardsPanel(){
      const s=state.cards;if(s.loading&&!s.data)return'<div class="v175-loading"><div class="v168-skeleton"></div><b>Conferindo cartões com o Fluxo…</b></div>';if(s.error&&!s.data)return'<div class="v168-error">'+esc(s.error)+'</div>';
      const data=s.data||{},o=D?.card_operating||{},map=new Map(),ensure=(b,c,m)=>{const k=[b,cardKey(c),m].join('|');if(!map.has(k))map.set(k,{bank:b,card:c,month:m,invoices:[],floors:[],flows:[]});return map.get(k)};
      for(const x of [...arr(o.open_cycles),...arr(o.closed_or_due)]){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.due_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).invoices.push(x)}
      for(const m of arr(o.contracted_installment_floor_months))for(const x of arr(m.detail)){const c=x.card_name||'Cartão não identificado';ensure(cardBank(c),c,String(m.reference_month).slice(0,7)).floors.push(x)}
      for(const x of arr(data.events)){const c=x.card_name||x.description||'Cartão não identificado',m=String(x.event_date||'').slice(0,7);if(m)ensure(cardBank(c),c,m).flows.push(x)}
      const banks=['Todos',...new Set([...map.values()].map(x=>x.bank))],filter=s.bank||'Todos',rows=[...map.values()].filter(x=>x.month>=today().slice(0,7)&&(filter==='Todos'||x.bank===filter)).sort((a,b)=>a.bank.localeCompare(b.bank)||cardKey(a.card).localeCompare(cardKey(b.card))||a.month.localeCompare(b.month)),groups=new Map();
      for(const row of rows){const k=row.bank+'|'+cardKey(row.card);if(!groups.has(k))groups.set(k,{bank:row.bank,card:row.card,rows:[]});groups.get(k).rows.push(row)}
      return '<div class="v175-cards">'+inventoryPanel(data)+'<div class="v169-bank-filter">'+banks.map(b=>'<button class="v168-btn '+(filter===b?'primary':'')+'" data-v175-card-bank="'+esc(b)+'">'+esc(b)+'</button>').join('')+'</div><article class="v168-card"><div class="v168-cardhead"><div><span>Conferência com o Fluxo</span><h2>Fatura, piso contratado e valor usado no caixa</h2></div><small>mês a mês</small></div>'+(
        [...groups.values()].map(g=>'<section class="v171-cardgroup"><header><span>'+esc(g.bank)+'</span><h3>'+esc(g.card)+'</h3></header><div class="v171-cardmonths">'+g.rows.map(x=>{const invoice=sum(x.invoices.map(y=>y.amount)),floor=sum(x.floors.map(y=>y.amount)),flow=sum(x.flows.map(y=>y.amount)),considered=x.flows.length?flow:x.invoices.length?invoice:floor;return'<div><b>'+monthLabel(x.month)+'</b><dl><dt>Fatura conhecida</dt><dd>'+brl(invoice)+'</dd><dt>Parcelas contratadas</dt><dd>'+brl(floor)+'</dd><dt>Valor no Fluxo</dt><dd><strong>'+(x.flows.length?brl(flow):'—')+'</strong></dd><dt>Considerado</dt><dd><strong>'+brl(considered)+'</strong></dd></dl></div>'}).join('')+'</div></section>').join('')
        ||'<div class="v168-empty">Nenhum valor futuro documentado neste filtro.</div>')+'</article><div class="v175-coverage"><b>Regra</b><span>Fatura observada e valor do Fluxo prevalecem sobre o piso parcelado. Cartões históricos continuam no inventário mesmo sem fatura futura.</span></div></div>';
    }

    function shellForHeavyTab(){
      const original=v168.expense.tab;v168.expense.tab='overview';
      try{return baseExpenses()}finally{v168.expense.tab=original}
    }
    function expensesV175(){
      const tab=v168?.expense?.tab||'overview',heavy=['monthly','cards'].includes(tab),t=tpl(heavy?shellForHeavyTab():baseExpenses()),root=t.content.querySelector('.v168-expenses'),tabs=root?.querySelector('.v168-tabs');if(!root||!tabs)return t.innerHTML;
      tabs.querySelectorAll('[data-v168-exp-tab]').forEach(b=>{const active=b.dataset.v168ExpTab===tab;b.classList.toggle('active',active);b.setAttribute('aria-selected',String(active))});
      if(tab==='categories'){
        let n=tabs.nextSibling;while(n){const q=n.nextSibling;n.remove();n=q}
        const data=state.expense.data;
        tabs.insertAdjacentHTML('afterend',state.expense.loading&&!data?'<div class="v168-skeleton"></div>':state.expense.error&&!data?'<div class="v168-error">'+esc(state.expense.error)+'</div>':'<article class="v168-card v175-categories"><div class="v168-cardhead"><div><span>Composição auditada</span><h2>Despesas por categoria</h2></div><small>'+esc(expenseRange().label)+'</small></div>'+rank(data?.management_groups,99,true)+propertyNote(data)+coverageNote(data)+'</article>');
      }
      if(tab==='monthly'||tab==='cards'){
        let n=tabs.nextSibling;while(n){const q=n.nextSibling;n.remove();n=q}
        tabs.insertAdjacentHTML('afterend',tab==='monthly'?monthlyPanel():cardsPanel());
      }
      return t.innerHTML;
    }

    function dashboardV175(){
      const t=tpl(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const data=state.expense.data,card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&data?.management_groups){card.querySelectorAll('.v168-rank,.v169-coverage,.v170-rank,.v170-audit,.v171-rank,.v171-reconciliation,.v172-rank,.v172-coverage,.v174-rank,.v174-property-note').forEach(x=>x.remove());card.insertAdjacentHTML('beforeend',rank(data.management_groups,12,false)+coverageNote(data))}
      return t.innerHTML;
    }

    function after(){
      const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v175Route=V==='Fluxo Diário'?'Fluxo de caixa':V;
      const tab=v168?.expense?.tab;
      if(V==='Despesas'){
        if(['overview','categories'].includes(tab)&&!state.expense.loading){const r=expenseRange(),key=r.from+'|'+r.to;if(!state.expense.data||state.expense.key!==key)queueMicrotask(()=>ensureExpense(false))}
        if(tab==='monthly'&&!state.monthly.loading&&!state.monthly.error){const r=expenseRange(),key=r.from+'|'+r.to;if(!state.monthly.data||state.monthly.key!==key)queueMicrotask(()=>ensureMonthly(false))}
        if(tab==='cards'&&!state.cards.loading&&!state.cards.data)queueMicrotask(()=>ensureCards(false));
      }
      document.querySelector('[data-v175-month-retry]')?.addEventListener('click',()=>ensureMonthly(true));
      document.querySelector('[data-v175-year]')?.addEventListener('change',e=>{state.monthly.year=e.currentTarget.value;render()});
      document.querySelectorAll('[data-v175-card-bank]').forEach(b=>b.onclick=()=>{state.cards.bank=b.dataset.v175CardBank;render()});
      document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const old=b.onclick;b.onclick=e=>{state.expense.data=null;state.monthly.data=null;state.expense.key='';state.monthly.key='';return old?.call(b,e)}});
      const apply=document.getElementById('v168ExpenseApply');if(apply){const old=apply.onclick;apply.onclick=e=>{state.expense.data=null;state.monthly.data=null;state.expense.key='';state.monthly.key='';return old?.call(apply,e)}}
    }

    dashboard=dashboardV175;despesas=expensesV175;
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();after();return out};

    state.expense.data=null;state.expense.key='';state.monthly.data=null;state.monthly.key='';state.cards.data=null;
    if(v168){v168.expense.data=null;v168.expense.loading=false;v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false}
    if(v169){v169.monthly.token=(v169.monthly.token||0)+1;v169.monthly.data=null;v169.monthly.key='';v169.monthly.loading=false;v169.monthly.error=null}
    window.__LTS_V175_EXPENSE_AUDIT={
      installed:true,version:'v175',base_version:'v174',public_index_changed:false,
      all_supported_cards_and_accounts_once:true,full_history_monthly_bounded_render:true,
      lender_split_fixed:true,workbook_category_reconciliation:true,historical_card_inventory:true,
      september_stock_sale_restored:true,april_stock_sale_open_source_issue:true,property_reconciled:true
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V174_V173_REVIEW?.installed)return false;
    if(!f.d.getElementById('lts-v175-style')){const link=f.d.createElement('link');link.id='lts-v175-style';link.rel='stylesheet';link.href='lts-v175-expense-financial-audit.css?v=20260918-v175a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V175_EXPENSE_AUDIT?.installed&&!f.d.getElementById('lts-v175-runtime')){const script=f.d.createElement('script');script.id='lts-v175-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V175_EXPENSE_AUDIT?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v175-expense-financial-audit';
})();