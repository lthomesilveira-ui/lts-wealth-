(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V177_EXPENSE_UX?.installed||!window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return;

    const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE;
    const state=window.__LTS_V177_STATE||(window.__LTS_V177_STATE={
      exec:{loading:false,key:'',token:0,error:null},
      detail:{open:false,loading:false,error:null,data:null,group:'',subgroup:null,query:''}
    });

    const priorFetch=window.fetch.bind(window);
    function remapUrl(input){
      const raw=typeof input==='string'?input:input?.url;if(!raw)return input;
      const next=raw
        .replace('/rest/v1/rpc/lts_browser_expense_executive_v8','/rest/v1/rpc/lts_browser_expense_executive_v10')
        .replace('/rest/v1/rpc/lts_browser_expense_executive_v9','/rest/v1/rpc/lts_browser_expense_executive_v10');
      if(next===raw)return input;
      return typeof input==='string'?next:new Request(next,input);
    }
    window.fetch=(input,init)=>priorFetch(remapUrl(input),init);

    const num=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const brl=v=>num(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const monthLabel=v=>{const k=String(v||'').slice(0,7);return /^\d{4}-\d{2}$/.test(k)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(k+'-01T12:00:00Z')).replace('.',''):k||'—'};
    const addMonths=(iso,delta)=>{const d=new Date(iso+'T12:00:00Z'),day=d.getUTCDate();d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+delta);const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));return d.toISOString().slice(0,10)};

    function range(){
      const s=v168?.expense||{},t=today(),year=t.slice(0,4);
      if(s.key==='6m')return{from:addMonths(t,-5).slice(0,8)+'01',to:t,label:'6 meses'};
      if(s.key==='12m')return{from:addMonths(t,-11).slice(0,8)+'01',to:t,label:'12 meses'};
      if(s.key==='all')return{from:'2013-10-10',to:t,label:'Desde 2013'};
      if(s.key==='custom'&&/^\d{4}-\d{2}-\d{2}$/.test(s.customFrom||'')&&/^\d{4}-\d{2}-\d{2}$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo,label:'Personalizado'};
      return{from:year+'-01-01',to:t,label:'Ano atual'};
    }

    async function directRpc(name,args){
      try{
        const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token||K;
        const response=await priorFetch(U+'/rest/v1/rpc/'+encodeURIComponent(name),{
          method:'POST',
          headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json',Accept:'application/json'},
          body:JSON.stringify(args||{})
        });
        const payload=await response.json().catch(()=>null);
        if(!response.ok)return{data:null,error:{message:String(payload?.message||payload?.error_description||('HTTP '+response.status))}};
        return{data:payload,error:null};
      }catch(error){return{data:null,error:{message:String(error?.message||error)}}}
    }

    async function ensureExecutive(force=false){
      if(!v175?.expense)return;
      const r=range(),key=r.from+'|'+r.to;
      if(state.exec.loading||(!force&&v175.expense.data?.version==='expense-executive-v19-v177-property-rollup'&&v175.expense.key===key))return;
      const token=++state.exec.token;state.exec.loading=true;state.exec.key=key;state.exec.error=null;
      try{
        const result=await directRpc('lts_browser_expense_executive_v10',{p_from:r.from,p_to:r.to});
        if(token!==state.exec.token)return;
        if(result.error||!result.data)throw Error(result.error?.message||'Relatório de despesas indisponível');
        v175.expense.data=result.data;v175.expense.key=key;v175.expense.error=null;
      }catch(error){if(token===state.exec.token)state.exec.error=String(error?.message||error)}
      finally{if(token===state.exec.token){state.exec.loading=false;if(V==='Despesas'||V==='Dashboard')render()}}
    }

    async function openDetail(group,subgroup=null){
      const r=range(),d=state.detail;
      d.open=true;d.loading=true;d.error=null;d.data=null;d.group=group;d.subgroup=subgroup;d.query='';
      renderDrawer();
      const result=await S.rpc('lts_browser_expense_group_detail_v1',{p_from:r.from,p_to:r.to,p_group:group,p_subgroup:subgroup});
      if(result?.error||!result?.data){d.loading=false;d.error=String(result?.error?.message||'Não foi possível abrir os lançamentos.');renderDrawer();return}
      d.loading=false;d.data=result.data;renderDrawer();
    }

    function closeDetail(){state.detail.open=false;state.detail.data=null;state.detail.error=null;state.detail.query='';document.getElementById('v177ExpenseDrawer')?.remove()}

    function detailDate(row){
      if(row.row_kind==='historical_component')return'Histórico';
      if(row.row_kind==='monthly_category_total')return monthLabel(row.date);
      return row.date_label||'—';
    }
    function componentSummary(rows){
      const map=new Map();
      for(const row of rows||[]){
        const key=String(row.component||'').trim();if(!key)continue;
        map.set(key,(map.get(key)||0)+(num(row.amount)||0));
      }
      return [...map.entries()].map(([name,total])=>({name,total})).sort((a,b)=>b.total-a.total);
    }
    function renderDrawerRows(){
      const d=state.detail,data=d.data||{},q=norm(d.query),rows=(data.rows||[]).filter(row=>!q||norm([row.description,row.account_source,row.counterparty,row.center_cost,row.component].join(' ')).includes(q));
      return '<div class="v177-detail-table-wrap"><table class="v177-detail-table"><thead><tr><th>Data</th><th>Histórico</th><th>Conta / cartão</th><th>Referência</th><th>Valor</th></tr></thead><tbody>'+(
        rows.map(row=>'<tr><td>'+esc(detailDate(row))+'</td><td><b>'+esc(row.description||'Lançamento')+'</b>'+(row.component&&data.group==='Apartamento · CIPÓ 396'?'<small>'+esc(row.component)+'</small>':'')+'</td><td>'+esc(row.account_source||'—')+'</td><td>'+esc([row.center_cost,row.counterparty].filter(x=>x&&x!=='Não atribuído'&&x!=='Não identificado').join(' · ')||'—')+'</td><td>'+brl(row.amount)+'</td></tr>').join('')
        ||'<tr><td colspan="5" class="v177-empty">Nenhum lançamento encontrado neste filtro.</td></tr>')+'</tbody></table></div>';
    }
    function renderDrawer(){
      let host=document.getElementById('v177ExpenseDrawer');
      if(!state.detail.open){host?.remove();return}
      if(!host){host=document.createElement('div');host.id='v177ExpenseDrawer';document.body.appendChild(host)}
      const d=state.detail,data=d.data||{},summary=componentSummary(data.rows||[]);
      host.innerHTML='<div class="v177-drawer-backdrop" data-v177-close></div><aside class="v177-drawer"><header><div><span>Detalhamento</span><h2>'+esc(d.subgroup||d.group||'Despesas')+'</h2><small>'+esc(range().label)+(d.subgroup?' · '+esc(d.group):'')+'</small></div><button data-v177-close aria-label="Fechar">×</button></header>'+
        (d.loading?'<div class="v177-drawer-loading">Carregando lançamentos…</div>':d.error?'<div class="v168-error">'+esc(d.error)+'</div>':
          '<div class="v177-drawer-kpis"><div><span>Total</span><b>'+brl(data.total)+'</b></div><div><span>Itens</span><b>'+esc(data.row_count??(data.rows||[]).length)+'</b></div></div>'+
          (summary.length>1?'<div class="v177-component-strip">'+summary.map(x=>'<span><b>'+esc(x.name)+'</b>'+brl(x.total)+'</span>').join('')+'</div>':'')+
          '<div class="v177-search"><input id="v177DetailSearch" type="search" placeholder="Filtrar histórico, conta, cartão ou referência" value="'+esc(d.query)+'"></div>'+
          '<div id="v177DetailRows">'+renderDrawerRows()+'</div>'
        )+'</aside>';
      host.querySelectorAll('[data-v177-close]').forEach(x=>x.onclick=closeDetail);
      const input=host.querySelector('#v177DetailSearch');
      if(input)input.oninput=e=>{state.detail.query=e.currentTarget.value;const rowsHost=host.querySelector('#v177DetailRows');if(rowsHost)rowsHost.innerHTML=renderDrawerRows()};
    }

    function rowGroup(row){
      return row.querySelector('.v175-rank-title b')?.textContent?.trim()
        || row.querySelector(':scope > div > b')?.textContent?.trim()
        || '';
    }
    function childName(em){
      const span=em.querySelector('span');if(!span)return'';
      return Array.from(span.childNodes).filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.textContent).join(' ').trim()||span.textContent.trim();
    }

    function decorateExpenseUX(){
      document.querySelectorAll('.v175-property,.v174-property-note').forEach(x=>x.remove());
      document.querySelectorAll('.v175-rank-title small').forEach(x=>{if(/fonte reconciliada/i.test(x.textContent||''))x.remove()});
      document.querySelectorAll('.v168-cardhead span').forEach(x=>{if(/^composição auditada$/i.test((x.textContent||'').trim()))x.textContent='Composição'});
      document.querySelectorAll('.v175-rankrow').forEach(row=>{
        const group=rowGroup(row);if(!group)return;
        const amount=row.querySelector(':scope > strong');
        if(amount&&!amount.dataset.v177Bound){
          amount.dataset.v177Bound='1';amount.classList.add('v177-amount-link');amount.setAttribute('role','button');amount.setAttribute('tabindex','0');amount.title='Abrir lançamentos';
          amount.onclick=()=>openDetail(group,null);amount.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();openDetail(group,null)}};
        }
        const title=row.querySelector('.v175-rank-title b');
        if(title&&!title.dataset.v177Bound){title.dataset.v177Bound='1';title.classList.add('v177-title-link');title.onclick=()=>openDetail(group,null)}
        row.querySelectorAll('details em').forEach(em=>{
          const subgroup=childName(em);if(!subgroup||em.dataset.v177Bound)return;
          em.dataset.v177Bound='1';em.classList.add('v177-subgroup-link');em.onclick=e=>{e.preventDefault();e.stopPropagation();openDetail(group,subgroup)};
        });
      });
    }

    const baseRender=render;
    render=function(){const out=baseRender();decorateExpenseUX();renderDrawer();return out};
    const baseRenderNav=renderNav;
    renderNav=function(){const out=baseRenderNav();const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v177Route=V==='Fluxo Diário'?'Fluxo de caixa':V;return out};

    if(v175?.expense){v175.expense.data=null;v175.expense.key='';v175.expense.error=null;v175.expense.loading=false;v175.expense.token=(v175.expense.token||0)+1}

    const observer=new MutationObserver(()=>queueMicrotask(decorateExpenseUX));
    observer.observe(A,{childList:true,subtree:true});

    const periodic=()=>{if((V==='Despesas'||V==='Dashboard')&&!state.exec.loading){const r=range(),key=r.from+'|'+r.to;if(!v175?.expense?.data||v175.expense.key!==key||v175.expense.data.version!=='expense-executive-v19-v177-property-rollup')ensureExecutive(false)}};
    setInterval(periodic,700);
    queueMicrotask(periodic);

    window.__LTS_V177_EXPENSE_UX={
      installed:true,version:'v177',base_version:'v176',public_index_changed:false,
      property_rollup:true,group_drilldown:true,technical_reconciliation_hidden:true,
      audit_2020_status:'source_complete_and_normalized_vs_2019_wedding',
      audit_2020_total_brl:281377.71,audit_2020_monthly_avg_brl:23448.14
    };
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return false;
    if(!f.d.getElementById('lts-v177-style')){const link=f.d.createElement('link');link.id='lts-v177-style';link.rel='stylesheet';link.href='lts-v177-expense-ux.css?v=20260918-v177a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V177_EXPENSE_UX?.installed&&!f.d.getElementById('lts-v177-runtime')){const script=f.d.createElement('script');script.id='lts-v177-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V177_EXPENSE_UX?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v177-expense-ux';
})();