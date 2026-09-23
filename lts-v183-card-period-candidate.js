/* V183 candidate: scope invoice reconciliation to the user's selected period. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V182_FEEDBACK?.installed)return false;
      if(w.__LTS_V183_CARD_PERIOD?.installed)return true;
      const runtime=function(){
        const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE;
        const oldExpenses=despesas,oldRender=render;
        const state=window.__LTS_V183_CARD_PERIOD={installed:true,status:'idle',key:'',rows:[],documentary:[],legacy:[],error:null,periods:0};
        const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x)||0);
        const date=x=>/^\d{4}-\d\d-\d\d$/.test(String(x||''))?x.split('-').reverse().join('/'):String(x||'—');
        const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
        function range(){
          const s=v168?.expense||{},to=today(),year=to.slice(0,4);
          if(s.key==='all')return{from:'2013-10-10',to};
          if(s.key==='custom'&&/^\d{4}-\d\d-\d\d$/.test(s.customFrom||'')&&/^\d{4}-\d\d-\d\d$/.test(s.customTo||''))return{from:s.customFrom,to:s.customTo};
          if(s.key==='6m'||s.key==='12m'){
            const d=new Date(to.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{from:d.toISOString().slice(0,10),to};
          }
          return{from:year+'-01-01',to};
        }
        function chunks(from,to){
          const result=[];let start=from;
          while(start<=to){const d=new Date(start+'T12:00:00Z');d.setUTCFullYear(d.getUTCFullYear()+2);d.setUTCDate(d.getUTCDate()-1);const end=d.toISOString().slice(0,10);result.push({from:start,to:end<to?end:to});d.setUTCDate(d.getUTCDate()+1);start=d.toISOString().slice(0,10)}
          return result;
        }
        async function load(){
          const r=range(),key=r.from+'|'+r.to;
          if(state.status==='loading'||(state.key===key&&state.status==='ready'))return;
          state.key=key;state.status='loading';state.error=null;state.rows=[];state.documentary=[];state.legacy=[];render();
          try{
            if(r.from>r.to)throw Error('Período inválido');
            const evidence=await S.rpc('lts_browser_invoice_documentary_only_v1');
            if(evidence?.error||evidence?.data?.financial_effect!=='none'||!Array.isArray(evidence?.data?.invoices))throw Error('Evidência documental indisponível');
            const periods=chunks(r.from,r.to),rows=[],legacy=[],seen=new Set(),seenLegacy=new Set();state.periods=periods.length;
            for(const period of periods){
              const [response,old]=await Promise.all([
                S.rpc('lts_browser_invoice_flow_reconciliation_v183',{p_from:period.from,p_to:period.to}),
                S.rpc('lts_browser_legacy_invoice_gap_v183',{p_from:period.from,p_to:period.to})
              ]);
              if(response?.error||!response?.data||!Array.isArray(response.data.rows))throw Error(response?.error?.message||'Conciliação indisponível');
              for(const item of response.data.rows){
                const key=[item.card_name,item.reference_month,item.due_date,item.documented_amount].join('|');
                if(seen.has(key))throw Error('Fatura repetida em intervalos de leitura');
                seen.add(key);rows.push(item);
              }
              if(old?.error||old?.data?.financial_effect!=='none'||!Array.isArray(old?.data?.invoices))throw Error(old?.error?.message||'Faturas históricas indisponíveis');
              for(const item of old.data.invoices){
                const invoiceKey=[item.card_name,item.due_date].join('|');
                if(seenLegacy.has(invoiceKey)||!Array.isArray(item.purchases)||item.purchases.length!==Number(item.detail_lines)||Math.abs(Number(item.detail_difference))>0.02)
                  throw Error('Composição histórica inconsistente');
                seenLegacy.add(invoiceKey);legacy.push(item);
              }
            }
            if(state.key!==key)return;
            state.documentary=evidence.data.invoices.filter(x=>x.due_date>=r.from&&x.due_date<=r.to);
            state.rows=rows.sort((a,b)=>String(a.due_date).localeCompare(String(b.due_date))||String(a.card_name).localeCompare(String(b.card_name)));
            state.legacy=legacy.sort((a,b)=>String(a.due_date).localeCompare(String(b.due_date)));
            state.status='ready';
          }catch(e){if(state.key===key){state.status='error';state.error=String(e?.message||e);state.rows=[];state.documentary=[];state.legacy=[]}}
          if(state.key===key&&V==='Despesas'&&v168?.expense?.tab==='cards')render();
        }
        function panel(){
          const r=range(),period=date(r.from)+' a '+date(r.to),rows=state.rows;
          let body='';
          if(state.status==='loading')body='<p>Conferindo faturas documentadas neste período…</p>';
          else if(state.status==='error')body='<p role="alert">'+esc(state.error)+' Nenhum resultado parcial é exibido.</p><button class="v168-btn" data-v183-card-retry>Tentar novamente</button>';
          else if(state.status==='ready'){
            const good=rows.filter(x=>x.reconciliation_status==='reconciled'&&Math.abs(Number(x.difference)||0)<=0.02).length;
            body='<p><b>'+rows.length+' fatura(s) do cadastro atual neste recorte; '+good+' com documento e evento do Fluxo correspondentes.</b> Essa conciliação compara cartão, competência, vencimento, sinal e valor. Não comprova que o banco já debitou a fatura; a confirmação de pagamento permanece separada no detalhe. Para vencimentos anteriores a hoje, ausência de evento nesta consulta não comprova ausência de pagamento no caixa histórico. Cartões ou ciclos sem fatura individual permanecem sem conferência.</p>'+
              (rows.length?'<div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Cartão</th><th>Vencimento</th><th>Documento</th><th>Fluxo</th><th>Diferença</th><th>Situação</th><th>Origem</th></tr></thead><tbody>'+rows.map(row=>{
                const ok=row.reconciliation_status==='reconciled'&&Math.abs(Number(row.difference)||0)<=0.02;
                const historical=String(row.due_date||'')<today()&&row.reconciliation_status==='invoice_event_count_mismatch'&&Number(row.flow_amount)===0;
                return'<tr><td>'+esc(row.card_name||'Cartão não identificado')+'</td><td>'+esc(date(row.due_date))+'</td><td>'+money(row.documented_amount)+'</td><td>'+(historical?'—':money(row.flow_amount))+'</td><td>'+(historical?'—':money(row.difference))+'</td><td>'+(ok?'Documento ↔ Fluxo':historical?'Conferência histórica pendente':esc(row.reconciliation_status||'Revisar'))+'</td><td><button class="v168-btn" data-v181-flow-date="'+esc(row.due_date||'')+'">Abrir no Fluxo</button></td></tr>';
              }).join('')+'</tbody></table></div>':'<p>Não há fatura individual cadastrada neste recorte. Os agregados históricos ainda precisam de composição e conferência por cartão.</p>');
          }
          const inventory=Array.isArray(v175?.cards?.data?.inventory?.cards)?v175.cards.data.inventory.cards:[];
          const cards=[...new Map(inventory.map(x=>[[x.bank,x.card_name,x.last4].join('|'),x])).values()];
          const cardList='<section class="v183-card-families" aria-label="Cartões identificados no histórico"><h3>Cartões identificados no histórico ('+cards.length+')</h3>'+
            (cards.length?'<ul style="display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px;list-style:none;padding:0">'+cards.map(x=>'<li style="padding:10px;border:1px solid #d8e1e9;border-radius:9px"><b>'+esc((x.bank||'Banco não identificado')+' · '+(x.card_name||'Cartão não identificado'))+'</b>'+(x.last4?'<small style="display:block">Final '+esc(x.last4)+'</small>':'')+'<small style="display:block">Evidência: '+esc(date(x.first_seen))+' a '+esc(date(x.last_seen))+'</small></li>').join('')+'</ul>':'<p>Inventário histórico indisponível. Os cartões ainda não podem ser conferidos integralmente.</p>')+
            '<p>Presença no histórico não comprova fatura individual para todos os meses. Produtos sem identificação documental continuam pendentes.</p></section>';
          const evidence=state.status==='ready'&&state.documentary.length?'<section aria-label="Faturas documentais ainda não integradas ao Fluxo"><h3>Faturas com documento, ainda sem conciliação operacional</h3><p>Estas evidências não criam nova saída, despesa ou dívida. Um débito de mesmo banco, data e valor é apenas candidato; pagamento deste cartão não foi confirmado.</p>'+state.documentary.map(x=>{
            const purchases=Array.isArray(x.purchases)?x.purchases:[];
            const cents=purchases.reduce((sum,p)=>sum+Math.round(Number(p.amount)*100),0);
            const total=Math.round(Number(x.invoice_amount)*100);
            const detail=purchases.length&&Number.isFinite(cents)&&cents===total
              ?'<details><summary>Ver '+purchases.length+' lançamento(s) · total '+money(x.invoice_amount)+'</summary><ul>'+purchases.map(p=>'<li>'+esc(date(p.date))+' · '+esc(p.description)+' · '+money(p.amount)+'</li>').join('')+'</ul></details>'
              :'<p>Composição documental ainda não conciliada com o total.</p>';
            return'<div style="border-top:1px solid #d8e1e9;padding:12px 0"><b>'+esc(x.bank)+' · '+esc(x.card_label)+' · final '+esc(x.card_last4)+'</b><p>Vencimento '+esc(date(x.due_date))+' · fatura '+money(x.invoice_amount)+' · pagamento bancário não confirmado'+(x.bank_debit_candidate?' · débito candidato identificado':'')+'</p>'+detail+'</div>';
          }).join('')+'</section>':'';
          const legacy=state.status==='ready'&&state.legacy.length?'<section aria-label="Faturas históricas importadas"><h3>Faturas históricas importadas ('+state.legacy.length+')</h3><p>Os itens destas faturas fecham com o total importado. Elas ainda não integram o cadastro atual; sua exibição não adiciona saída ao Fluxo nem confirma pagamento no banco.</p>'+state.legacy.map(x=>
            '<details style="border-top:1px solid #d8e1e9;padding:12px 0"><summary><b>'+esc(x.card_name)+'</b> · '+esc(date(x.due_date))+' · '+money(x.documented_amount)+' · '+x.purchases.length+' itens</summary><p>Composição conferida na importação. Pagamento bancário deste cartão ainda não confirmado.</p><ul>'+x.purchases.map(p=>'<li>'+esc(date(p.date))+' · '+esc(p.description||'Lançamento')+(p.card_final?' · final '+esc(p.card_final):'')+' · '+money(p.amount)+'</li>').join('')+'</ul></details>'
          ).join('')+'</section>':'';
          return'<article class="v168-card v183-card-period"><div class="v168-cardhead"><div><span>Faturas documentadas · '+esc(period)+'</span><h2>Cartões e faturas do período</h2></div></div>'+cardList+body+legacy+evidence+'</article>';
        }
        despesas=function(){
          const t=document.createElement('template');t.innerHTML=oldExpenses();const root=t.content.querySelector('.v168-expenses');
          if(root&&v168?.expense?.tab==='cards'){
            const host=root.querySelector('.v175-cards'),old=root.querySelector('.v181-reconciliation');
            if(host){old?.remove();host.querySelector('.v175-inventory')?.remove();host.insertAdjacentHTML('afterbegin',panel());
              const planning=[...host.children].find(x=>x.matches?.('article.v168-card')&&!x.classList.contains('v183-card-period'));
              if(planning){const details=document.createElement('details');details.className='v183-planning';details.innerHTML='<summary>Parcelas e projeções futuras</summary>';planning.before(details);details.appendChild(planning)}
            }
          }
          return t.innerHTML;
        };
        render=function(){const result=oldRender();
          if(V==='Despesas'&&v168?.expense?.tab==='cards'){
            const r=range(),key=r.from+'|'+r.to;
            if(state.status==='idle'||(state.key!==key&&state.status!=='loading'))queueMicrotask(load);
            document.querySelector('[data-v183-card-retry]')?.addEventListener('click',()=>{state.status='idle';load()});
            document.querySelectorAll('.v183-card-period [data-v181-flow-date]').forEach(button=>button.onclick=async()=>{
              const due=button.dataset.v181FlowDate;
              if(!/^\d{4}-\d\d-\d\d$/.test(due))return;
              V='Fluxo Diário';FLOWYEAR=Number(due.slice(0,4));renderNav();render();
              // The existing route schedules its default interval in a microtask.
              // Let that run, then the exact date becomes the newest Flow request.
              await new Promise(resolve=>setTimeout(resolve,0));
              if(!window.__LTS_V162_FLOW_RECOVERY_STATUS?.default_range_applied){
                document.getElementById('flowDefaultRange')?.click();
                await new Promise(resolve=>setTimeout(resolve,0));
              }
              await loadFlowRange(due,due);
              const day=document.getElementById('d-'+due);
              day?.scrollIntoView({behavior:'smooth',block:'center'});
              const expand=day?.querySelector('button');if(expand?.textContent?.trim()==='+')expand.click();
            });
          }
          return result;
        };
        // Authentication may still be fetching the product state. The base renderer
        // dereferences D.flow, so wait for the core load before first rendering.
        if(D && !N.classList.contains('hidden'))render();
      };
      const script=d.createElement('script');script.id='v183-card-period-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_CARD_PERIOD?.installed;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
})();
