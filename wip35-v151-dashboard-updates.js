(function(){
  const w=window,d=document;
  const MARK='dashboard-updates-cockpit-v1';
  if(w.LTS_V151_COCKPIT===MARK)return;
  const n=x=>Number(x||0)||0;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n(v));
  const fmt=v=>{const s=String(v||'').slice(0,10),m=s.match(/^(\d{4})-(\d{2})-(\d{2})$/);return m?`${m[3]}/${m[2]}/${m[1]}`:s||'—'};
  const pct=v=>`${Math.abs(v).toLocaleString('pt-BR',{minimumFractionDigits:1,maximumFractionDigits:1})}%`;
  let observer=null,expenseRetry=0;

  function css(){
    if(d.getElementById('wip35-v151-css'))return;
    const s=d.createElement('style');s.id='wip35-v151-css';s.textContent=`
    .v151{max-width:1220px;margin:0 auto;display:flex;flex-direction:column;gap:14px;color:#132b46}
    .v151-head{display:flex;justify-content:space-between;gap:18px;align-items:flex-end}.v151-kicker{display:block;font-size:9px;letter-spacing:.09em;text-transform:uppercase;font-weight:900;color:#9a7441}.v151-head h1{font-size:30px;letter-spacing:-.035em;margin:4px 0 5px}.v151-head p{font-size:11px;color:#718093;margin:0}.v151-asof{font-size:9px;color:#718093;white-space:nowrap}
    .v151-strip{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:9px}.v151-kpi{border:1px solid #e0e6ec;background:#fff;border-radius:15px;padding:12px 13px;box-shadow:0 7px 22px rgba(20,42,70,.045);min-width:0}.v151-kpi span{display:block;font-size:8px;font-weight:900;text-transform:uppercase;letter-spacing:.04em;color:#758397}.v151-kpi b{display:block;font-size:18px;margin-top:6px;letter-spacing:-.02em;white-space:nowrap}.v151-kpi small{display:block;font-size:8px;color:#8a96a5;margin-top:4px;line-height:1.3}.v151-kpi.alert b{color:#a64642}
    .v151-grid{display:grid;grid-template-columns:1.08fr .92fr;gap:12px}.v151-card{background:#fff;border:1px solid #dfe5eb;border-radius:18px;padding:15px;box-shadow:0 8px 26px rgba(20,42,70,.05);min-width:0}.v151-cardhead{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:11px}.v151-cardhead span{display:block;font-size:8px;text-transform:uppercase;font-weight:900;letter-spacing:.06em;color:#9a7441}.v151-cardhead h2{font-size:18px;margin:3px 0 0}.v151-chip{font-size:8px;border:1px solid #dfe5eb;border-radius:999px;padding:5px 8px;color:#68778a;background:#f9fafb;white-space:nowrap}
    .v151-liqrows{display:flex;flex-direction:column;gap:0}.v151-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;padding:8px 2px;border-top:1px solid #edf1f4;align-items:center}.v151-row:first-child{border-top:0}.v151-row span{font-size:10px;color:#42546a}.v151-row b{font-size:11px;white-space:nowrap}.v151-row.total{margin-top:3px;padding:10px;border-radius:10px;background:#f2f5f8;border:0}.v151-row.total span,.v151-row.total b{font-weight:900;color:#17304d}.v151-row.subtle{background:#fbfaf7;padding-left:9px;padding-right:9px;border-radius:9px;margin-top:5px}
    .v151-account{display:flex;gap:8px;align-items:center}.v151-bankdot{width:7px;height:7px;border-radius:50%;background:#b8945b;display:inline-block}
    .v151-commit{display:grid;grid-template-columns:1fr 1fr;gap:8px}.v151-stat{border:1px solid #e7ebef;border-radius:12px;padding:11px}.v151-stat span{font-size:8px;color:#7b8796;font-weight:850}.v151-stat b{display:block;font-size:15px;margin-top:5px}.v151-stat small{display:block;font-size:8px;color:#8b96a5;margin-top:4px;line-height:1.3}.v151-alertline{margin-top:9px;border-radius:10px;padding:9px 10px;background:#fff8e9;border:1px solid #ead9b8;font-size:9px;line-height:1.4;color:#73562b}
    .v151-chartwrap{display:grid;grid-template-columns:minmax(0,1fr) 170px;gap:10px;align-items:stretch}.v151-chart{border:1px solid #edf0f3;border-radius:12px;padding:9px;background:#fbfcfd;overflow:hidden}.v151-chart svg{display:block;width:100%;height:auto;min-height:190px}.v151-chartmeta{display:flex;flex-direction:column;gap:8px}.v151-mini{border:1px solid #e5e9ed;border-radius:11px;padding:10px}.v151-mini span{display:block;font-size:7px;text-transform:uppercase;color:#7c8997;font-weight:900}.v151-mini b{display:block;font-size:14px;margin-top:5px}.v151-mini.bad b{color:#a64642}.v151-mini.good b{color:#347253}.v151-mini small{display:block;font-size:8px;color:#8c97a5;margin-top:4px}
    .v151-wealthmain{display:grid;grid-template-columns:1fr 1fr 1fr;gap:7px}.v151-wealthmain div{border:1px solid #e5e9ed;border-radius:11px;padding:10px}.v151-wealthmain span{display:block;font-size:7px;text-transform:uppercase;color:#7c8997;font-weight:900}.v151-wealthmain b{display:block;font-size:13px;margin-top:5px}.v151-assetlist{margin-top:9px}.v151-assetlist .v151-row{padding-top:7px;padding-bottom:7px}
    .v151-attn{background:#fff;border:1px solid #dfe5eb;border-radius:18px;padding:15px;box-shadow:0 8px 26px rgba(20,42,70,.05)}.v151-attn>h2{font-size:18px;margin:0 0 11px}.v151-attngrid{display:grid;grid-template-columns:repeat(3,1fr);gap:9px}.v151-attncol{border:1px solid #e5e9ed;border-radius:12px;padding:11px;min-width:0}.v151-attncol h3{font-size:11px;margin:0 0 8px}.v151-attnitem{padding:7px 0;border-top:1px solid #eef1f4}.v151-attnitem:first-of-type{border-top:0}.v151-attnitem b{display:block;font-size:9px}.v151-attnitem span{display:block;font-size:8px;color:#7e8a99;margin-top:3px;line-height:1.35}.v151-empty{font-size:9px;color:#8793a1;padding:8px 0}
    .v151-update-summary{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin:8px 0 12px}.v151-update-sum{border:1px solid #e3e8ed;border-radius:11px;background:#fbfcfd;padding:9px}.v151-update-sum span{display:block;font-size:7px;text-transform:uppercase;font-weight:900;color:#7d8998}.v151-update-sum b{display:block;font-size:14px;margin-top:3px}.v151-research-title{font-size:7px!important;text-transform:uppercase!important;font-weight:900!important;color:#66788a!important}.v151-research-found{font-size:12px!important;margin-top:3px!important}.v151-research-note{display:block;font-size:8px;color:#6d7b8c;margin-top:4px;line-height:1.35}.v151-research-pill{font-size:8px;font-weight:900;padding:5px 7px;border-radius:999px;background:#edf4f8;color:#31546e;white-space:nowrap}
    .v151-exp-state{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin:11px 0}.v151-exp-box{border:1px solid #e3e8ed;border-radius:12px;background:#fff;padding:11px}.v151-exp-box span{display:block;font-size:7px;text-transform:uppercase;font-weight:900;color:#778596}.v151-exp-box b{display:block;font-size:15px;margin-top:4px}.v151-exp-box small{display:block;font-size:8px;color:#8692a0;margin-top:4px;line-height:1.35}.v151-exp-box.action{border-color:#dbc69f;background:#fffaf0}.v151-exp-note{font-size:8px;color:#687789;margin-top:5px}.v151-hide{display:none!important}
    @media(max-width:950px){.v151-strip{grid-template-columns:repeat(2,1fr)}.v151-strip .v151-kpi:last-child{grid-column:1/-1}.v151-grid{grid-template-columns:1fr}.v151-chartwrap{grid-template-columns:1fr}.v151-chartmeta{display:grid;grid-template-columns:1fr 1fr}.v151-attngrid{grid-template-columns:1fr}}
    @media(max-width:560px){.v151{gap:10px}.v151-head{align-items:flex-start;flex-direction:column}.v151-head h1{font-size:25px}.v151-strip{grid-template-columns:1fr 1fr;gap:7px}.v151-kpi{padding:10px}.v151-kpi b{font-size:15px}.v151-grid{gap:9px}.v151-card{padding:12px}.v151-commit,.v151-wealthmain,.v151-update-summary,.v151-exp-state{grid-template-columns:1fr}.v151-chartmeta{grid-template-columns:1fr 1fr}.v151-attn{padding:12px}}
    `;(d.head||d.documentElement).appendChild(s);
  }

  function chartSvg(c){
    const l=c.liquidity||{}, hz=(c.horizons||[]).filter(x=>x&&x.current_liquidity_balance!=null).slice(0,4);
    const pts=[{label:'Hoje',date:c.as_of,value:n(l.through_d3)}].concat(hz.map(x=>({label:x.id==='30d'?'30 dias':x.id==='90d'?'90 dias':x.id==='year_end'?'Fim do ano':(x.label||fmt(x.date)),date:x.date,value:n(x.current_liquidity_balance)})));
    if(pts.length<2)return '<div class="v151-empty">Trajetória ainda sem pontos suficientes.</div>';
    const W=620,H=220,pad={l:44,r:15,t:18,b:38},vals=pts.map(x=>x.value).concat([0]),lo=Math.min(...vals),hi=Math.max(...vals),span=Math.max(1,hi-lo),lo2=lo-span*.12,hi2=hi+span*.12;
    const x=i=>pad.l+(W-pad.l-pad.r)*(pts.length===1?0:i/(pts.length-1));
    const y=v=>pad.t+(H-pad.t-pad.b)*(1-(v-lo2)/(hi2-lo2));
    const path=pts.map((p,i)=>`${i?'L':'M'} ${x(i).toFixed(1)} ${y(p.value).toFixed(1)}`).join(' ');
    const zero=y(0);
    const circles=pts.map((p,i)=>`<circle cx="${x(i)}" cy="${y(p.value)}" r="4" fill="${p.value<0?'#a64642':'#17304d'}"/><text x="${x(i)}" y="${H-18}" text-anchor="middle" font-size="9" fill="#718093">${esc(p.label)}</text>`).join('');
    return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Evolução projetada do caixa"><line x1="${pad.l}" y1="${zero}" x2="${W-pad.r}" y2="${zero}" stroke="#bdc6cf" stroke-dasharray="5 4"/><text x="4" y="${zero+3}" font-size="8" fill="#8b96a4">R$ 0</text><path d="${path}" fill="none" stroke="#17304d" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>${circles}</svg>`;
  }

  function actionItems(c){
    const a=(c.work?.top_actions||[]).slice(0,3);
    if(!a.length)return '<div class="v151-empty">Nenhuma ação prioritária agora.</div>';
    return a.map(x=>`<div class="v151-attnitem"><b>${esc(x.title||'Revisar pendência')}</b><span>${esc(x.detail||x.description||'Abra Atualizações para revisar.')}</span></div>`).join('');
  }
  function alertItems(c){
    const out=[],pa=c.planning_audited||{},next=c.cards?.next_due||{};
    if(pa.management_point_date)out.push(`<div class="v151-attnitem"><b>Ponto de atenção · ${fmt(pa.management_point_date)}</b><span>Planejamento aponta gestão antecipada do caixa.</span></div>`);
    if(next.due_date)out.push(`<div class="v151-attnitem"><b>Próximo cartão · ${fmt(next.due_date)}</b><span>${next.amount!=null?brl(next.amount):''}${next.card_name?' · '+esc(next.card_name):''}</span></div>`);
    if(n(c.work?.classification_groups)>0)out.push(`<div class="v151-attnitem"><b>${n(c.work.classification_groups)} classificação(ões) para revisar</b><span>O LTS separa o que já tem evidência do que ainda precisa de contexto.</span></div>`);
    return out.join('')||'<div class="v151-empty">Nenhum alerta material no cockpit.</div>';
  }
  function insightItems(c){
    const out=[],cur=c.expenses?.current_month||{},prev=c.expenses?.previous_month||{},a=n(cur.spend),b=n(prev.spend);
    if(a&&b){const delta=(a-b)/Math.abs(b)*100;out.push(`<div class="v151-attnitem"><b>Despesas do mês ${delta>=0?'acima':'abaixo'} do anterior</b><span>${brl(a)} vs ${brl(b)} · ${pct(delta)} ${delta>=0?'a mais':'a menos'}</span></div>`)}
    out.push(`<div class="v151-attnitem"><b>Liquidez D+3</b><span>${brl(c.liquidity?.through_d3)} disponíveis sem somar FGTS.</span></div>`);
    if(c.wealth?.net_worth_central!=null)out.push(`<div class="v151-attnitem"><b>Patrimônio líquido</b><span>${brl(c.wealth.net_worth_central)} na estimativa central atual.</span></div>`);
    return out.slice(0,3).join('');
  }

  function dashboard(){
    const c=w.D?.dashboard_cockpit||{},l=c.liquidity||{},cards=c.cards||{},work=c.work||{},pa=c.planning_audited||{},we=c.wealth||{},accounts=l.accounts||[],wx=w.D?.wealth_executive||{},assets=wx.assets||{},cipo=assets.cipo_396||{},volvo=assets.volvo_xc40||{};
    if(!c.version)return `<div class="v151"><div class="v151-head"><div><span class="v151-kicker">Dashboard</span><h1>Sua vida financeira, em uma tela.</h1><p>Atualizando o cockpit…</p></div></div></div>`;
    const worst=pa.worst_before_brl;
    const accRows=accounts.map(x=>`<div class="v151-row"><span class="v151-account"><i class="v151-bankdot"></i>${esc(x.institution||'Conta')}</span><b>${brl(x.balance)}</b></div>`).join('');
    const next=cards.next_due||{};
    const management=pa.management_point_date?`Ponto de atenção: ${fmt(pa.management_point_date)}`:'Sem ponto de gestão no horizonte';
    const assetRows=[
      cipo.market_central!=null?`<div class="v151-row"><span>CIPÓ 396 · valor central</span><b>${brl(cipo.market_central)}</b></div>`:'',
      volvo.market_central!=null?`<div class="v151-row"><span>Volvo XC40 · valor central</span><b>${brl(volvo.market_central)}</b></div>`:''
    ].join('');
    return `<div class="v151">
      <div class="v151-head"><div><span class="v151-kicker">Dashboard</span><h1>Sua vida financeira, em uma tela.</h1><p>Recursos, compromissos, trajetória e decisões — sem esconder o detalhe que importa.</p></div><div class="v151-asof">Posição ${fmt(c.as_of)}</div></div>
      <div class="v151-strip">
        <div class="v151-kpi"><span>Disponível D+3</span><b>${brl(l.through_d3)}</b><small>contas + Cofrinho + RSU disponível</small></div>
        <div class="v151-kpi"><span>FGTS</span><b>${brl(l.fgts_d30)}</b><small>fora do disponível D+3</small></div>
        <div class="v151-kpi"><span>Cartões em aberto</span><b>${brl(cards.open_cycles_total)}</b><small>faturas ainda abertas</small></div>
        <div class="v151-kpi"><span>Patrimônio líquido</span><b>${we.net_worth_central!=null?brl(we.net_worth_central):'—'}</b><small>estimativa central atual</small></div>
        <div class="v151-kpi ${n(worst)<0?'alert':''}"><span>Menor saldo projetado</span><b>${worst!=null?brl(worst):'—'}</b><small>${pa.management_point_date?fmt(pa.management_point_date):'sem alerta no horizonte'}</small></div>
      </div>
      <div class="v151-grid">
        <section class="v151-card" id="v151Liquidity"><div class="v151-cardhead"><div><span>Recursos</span><h2>Liquidez</h2></div><i class="v151-chip">posição atual</i></div>
          <div class="v151-liqrows">${accRows}<div class="v151-row total"><span>Total contas correntes</span><b>${brl(l.bank_cash)}</b></div><div class="v151-row"><span>Cofrinho</span><b>${brl(l.d0)}</b></div><div class="v151-row"><span>RSU disponível D+3</span><b>${brl(l.d3_vested)}</b></div><div class="v151-row subtle"><span>FGTS</span><b>${brl(l.fgts_d30)}</b></div><div class="v151-row total"><span>Total disponível D+3</span><b>${brl(l.through_d3)}</b></div></div>
        </section>
        <section class="v151-card"><div class="v151-cardhead"><div><span>Próximas saídas</span><h2>Compromissos próximos</h2></div><i class="v151-chip">${n(work.actionable_count)} ação(ões)</i></div>
          <div class="v151-commit"><div class="v151-stat"><span>Faturas abertas</span><b>${brl(cards.open_cycles_total)}</b><small>valor atualmente em aberto</small></div><div class="v151-stat"><span>Próximo cartão</span><b>${next.amount!=null?brl(next.amount):'—'}</b><small>${next.due_date?fmt(next.due_date):'sem vencimento'}${next.card_name?' · '+esc(next.card_name):''}</small></div><div class="v151-stat"><span>Vencido / a confirmar</span><b>${brl(cards.closed_or_due_total)}</b><small>posição operacional do cartão</small></div><div class="v151-stat"><span>Dívidas conhecidas</span><b>${we.known_debt_total!=null?brl(we.known_debt_total):'—'}</b><small>posição patrimonial, não nova saída inferida</small></div></div>
          <div class="v151-alertline">${esc(management)}</div>
        </section>
        <section class="v151-card"><div class="v151-cardhead"><div><span>Trajetória</span><h2>Evolução do caixa</h2></div><i class="v151-chip">${pa.management_point_date?fmt(pa.management_point_date):'horizonte coberto'}</i></div>
          <div class="v151-chartwrap"><div class="v151-chart">${chartSvg(c)}</div><div class="v151-chartmeta"><div class="v151-mini bad"><span>Pior antes da cobertura</span><b>${pa.worst_before_brl!=null?brl(pa.worst_before_brl):'—'}</b><small>${pa.management_point_date?fmt(pa.management_point_date):''}</small></div><div class="v151-mini good"><span>Pior após cobertura</span><b>${pa.worst_after_brl!=null?brl(pa.worst_after_brl):'—'}</b><small>${pa.fgts_request_by?'FGTS até '+fmt(pa.fgts_request_by):''}</small></div></div></div>
        </section>
        <section class="v151-card"><div class="v151-cardhead"><div><span>Posição</span><h2>Patrimônio e posição financeira</h2></div><i class="v151-chip">resumo</i></div>
          <div class="v151-wealthmain"><div><span>Ativos</span><b>${we.assets_central!=null?brl(we.assets_central):'—'}</b></div><div><span>Dívidas</span><b>${we.known_debt_total!=null?brl(we.known_debt_total):'—'}</b></div><div><span>Patrimônio líquido</span><b>${we.net_worth_central!=null?brl(we.net_worth_central):'—'}</b></div></div><div class="v151-assetlist">${assetRows||'<div class="v151-empty">Detalhes patrimoniais disponíveis na aba Patrimônio.</div>'}</div>
        </section>
      </div>
      <section class="v151-attn"><h2>O que exige minha atenção</h2><div class="v151-attngrid"><div class="v151-attncol"><h3>Ações</h3>${actionItems(c)}</div><div class="v151-attncol"><h3>Alertas</h3>${alertItems(c)}</div><div class="v151-attncol"><h3>Insights</h3>${insightItems(c)}</div></div></section>
    </div>`;
  }

  function evidenceType(x){
    const ev=String(x?.enrichment_evidence||'').toLocaleLowerCase('pt-BR'),name=String(x?.merchant_name||'');
    if(/lavander/.test(ev))return 'Lavanderia';
    if(/loja franca|duty.?free/.test(ev))return 'Duty free / loja franca';
    if(/farm[aá]cia/.test(ev))return 'Farmácia';
    if(/estacionamento|valet/.test(ev))return 'Estacionamento';
    if(/combust[ií]vel/.test(ev))return 'Posto / combustível';
    if(/restaurante|lanchonete|confeitaria/.test(ev))return 'Alimentação / restaurante';
    if(/brinquedo/.test(ev))return 'Loja de brinquedos';
    if(/chocolate/.test(ev))return 'Loja de chocolates';
    if(/cosm[eé]tico/.test(ev))return 'Cosméticos';
    return name?'Estabelecimento identificado':'Pesquisa realizada';
  }
  function updateMessage(x){
    const st=String(x?.enrichment_status||'');
    if(x?.suggested_category)return {title:'Sugestão do LTS',found:String(x.suggested_category),note:'Categoria sugerida com evidência; sua confirmação continua necessária.',pill:'categoria sugerida'};
    if(st==='marketplace_needs_item_context')return {title:'O LTS encontrou',found:evidenceType(x),note:'Marketplace identificado. Falta o item/finalidade da compra para classificar.',pill:'falta item'};
    if(st==='payment_intermediary_needs_context')return {title:'O LTS encontrou',found:evidenceType(x),note:'Intermediador identificado. Falta o consumo final para classificar.',pill:'falta consumo'};
    if(st==='identified_needs_taxonomy')return {title:'O LTS encontrou',found:evidenceType(x),note:'O estabelecimento está identificado; a categoria do LTS ainda precisa de revisão.',pill:'falta categoria LTS'};
    if(st==='identified_needs_context')return {title:'O LTS encontrou',found:evidenceType(x),note:'O estabelecimento está identificado; falta a finalidade desta compra.',pill:'falta contexto'};
    if(st==='person_name_needs_user_context')return {title:'Só falta seu contexto',found:'Pessoa identificada na descrição',note:'O LTS não faz pesquisa invasiva de pessoa física.',pill:'contexto'};
    if(st==='search_ambiguous'||st==='search_no_result')return {title:'Pesquisa já feita',found:'Resultado inconclusivo',note:'O LTS pesquisou, mas não encontrou evidência suficiente para sugerir categoria.',pill:'inconclusivo'};
    if(x?.merchant_identified)return {title:'O LTS encontrou',found:evidenceType(x),note:'Estabelecimento identificado; falta contexto para a categoria financeira.',pill:'identificado'};
    return {title:'Ainda precisa de contexto',found:'Sem sugestão segura',note:'O LTS não vai inventar uma categoria sem evidência.',pill:'revisar'};
  }
  function enhanceUpdates(){
    if(String(w.V)!=='Atualizações')return;
    const root=d.getElementById('v146UpdatesRoot');if(!root)return;
    const q=w.D?.card_classification_review||{},items=q.items||[];
    if(!d.getElementById('v151UpdateSummary')){
      const sug=items.filter(x=>x?.suggested_category).length,identified=items.filter(x=>!x?.suggested_category&&x?.merchant_identified).length,other=Math.max(0,items.length-sug-identified);
      const el=d.createElement('div');el.id='v151UpdateSummary';el.className='v151-update-summary';el.innerHTML=`<div class="v151-update-sum"><span>Com sugestão</span><b>${sug}</b></div><div class="v151-update-sum"><span>Estabelecimento já identificado</span><b>${identified}</b></div><div class="v151-update-sum"><span>Ainda precisa de contexto</span><b>${other}</b></div>`;
      const summary=root.querySelector('.v146u-summary');summary?.insertAdjacentElement('afterend',el);
    }
    const map=new Map(items.map(x=>[String(x?.description_key||''),x]));
    root.querySelectorAll('.v146u-row[data-v146-key]').forEach(row=>{
      const x=map.get(String(row.dataset.v146Key||''));if(!x)return;
      const box=row.querySelector('.v146u-reco');if(!box||box.dataset.v151==='1')return;
      const m=updateMessage(x);box.dataset.v151='1';box.classList.toggle('has',!!x?.suggested_category||!!x?.merchant_identified);
      box.innerHTML=`<div><span class="v151-research-title">${esc(m.title)}</span><b class="v151-research-found">${esc(m.found)}</b><small class="v151-research-note">${esc(m.note)}</small></div><div class="v146u-pills"><i class="v151-research-pill">${esc(m.pill)}</i>${x?.suggestion_confidence?`<i>${Math.round(n(x.suggestion_confidence)*100)}% evidência</i>`:''}</div>`;
    });
  }

  function enhanceExpenses(){
    if(String(w.V)!=='Despesas'){expenseRetry=0;return;}
    let root=d.getElementById('v150ExpensesRoot')||d.querySelector('#A > .v150')||d.querySelector('#A .v150');
    if(root&&!root.id)root.id='v150ExpensesRoot';
    const data=w.__V150_EXP?.data;
    if(!root||!data){
      if(expenseRetry<6){const delays=[40,100,180,320,520,850],ms=delays[expenseRetry++]||850;setTimeout(enhanceExpenses,ms)}
      return;
    }
    expenseRetry=0;
    if(d.getElementById('v151ExpenseState'))return;
    const states=new Map((data.unassigned_states||[]).map(x=>[String(x.state),x]));
    const hist=states.get('documentary_detail_not_recovered')||{},sys=states.get('detail_available_system_review')||{},act=states.get('classification_and_context_pending')||{};
    const el=d.createElement('section');el.id='v151ExpenseState';el.className='v151-exp-state';el.innerHTML=`<div class="v151-exp-box"><span>Histórico sem detalhe recuperado</span><b>${brl(hist.total)}</b><small>${n(hist.rows)} registro(s) · não transformar em compra inventada.</small></div><div class="v151-exp-box"><span>LTS ainda investigando</span><b>${brl(sys.total)}</b><small>${n(sys.rows)} registro(s) com detalhe disponível para revisão do sistema.</small></div><div class="v151-exp-box action"><span>Realmente para classificar/contextualizar</span><b>${brl(act.total)}</b><small>${n(act.rows)} registro(s) que podem precisar de decisão.</small></div>`;
    const kpis=root.querySelector('.v150-kpis');
    if(kpis)kpis.insertAdjacentElement('afterend',el);else root.insertBefore(el,root.children[2]||root.firstChild||null);
    const note=d.createElement('div');note.className='v151-exp-note';note.textContent='Casa é contexto. Moradia é natureza do gasto. O LTS mantém as duas dimensões separadas.';el.insertAdjacentElement('afterend',note);
    root.querySelectorAll('.v150-card').forEach(card=>{if(/O que significa Não atribuído/i.test(card.textContent||''))card.classList.add('v151-hide')});
    root.querySelectorAll('.v150-kpi').forEach(k=>{const sp=k.querySelector('span');if(sp&&/Não atribuído/i.test(sp.textContent||'')){sp.textContent='Sem contexto consolidado';const sm=k.querySelector('small');if(sm)sm.textContent='inclui histórico, investigação do LTS e fila real'}});
  }

  function stamp(){
    try{
      d.querySelectorAll('.brand small').forEach(x=>x.textContent='WIP35-v151 · Homologação');
      d.querySelectorAll('.footer').forEach(x=>x.textContent='Versão WIP35-v151');
      let p=w,labels=[];for(let i=0;i<16;i++){try{const b=p.document?.getElementById('badge');if(b)b.textContent='CANDIDATA v151 · validação interna';p.document?.querySelectorAll?.('.brand small,.footer').forEach(x=>labels.push(x.textContent||''));if(p===p.parent)break;p=p.parent}catch(e){break}}
      w.__LTS_V151_VISIBLE_VERSION_STATUS={version:MARK,label:'v151',older_version_visible:labels.some(x=>/v14[0-9]\b|v150\b/i.test(x))};
    }catch(e){}
  }
  function afterRender(){css();stamp();queueMicrotask(()=>{enhanceUpdates();enhanceExpenses()})}
  function install(){
    if(typeof w.render!=='function'||!w.D)return false;
    css();
    w.__LTS_V151_DASHBOARD_FN=dashboard;
    w.dashboard=dashboard;
    w.__v143Dashboard=dashboard;
    w.__LTS_V151_AFTER_RENDER=afterRender;
    if(!observer&&typeof MutationObserver==='function'){
      const root=d.getElementById('A')||d.body;
      observer=new MutationObserver(()=>queueMicrotask(afterRender));
      observer.observe(root,{childList:true,subtree:true});
      w.__LTS_V151_DECORATION_OBSERVER=observer;
    }
    w.LTS_V151_COCKPIT=MARK;
    w.__LTS_V151_STATUS={version:MARK,layout_reference:'approved-executive-cockpit-image',dashboard_recomposed:true,updates_evidence_visibility:true,expense_unassigned_clarity:true,financial_writer_changed:false,classification_inference:false,classification_writer_added:false,navigation_owner_changed:false,permanent_polling:false,bounded_retry:true};
    try{if(String(w.V)==='Dashboard')w.render()}catch(e){}
    afterRender();return true;
  }
  if(!install()) [80,180,350,700,1200,2200,4000,7000].forEach(ms=>setTimeout(install,ms));
  [250,700,1500,3000,6000,10000,15000].forEach(ms=>setTimeout(()=>{if(w.LTS_V151_COCKPIT===MARK){w.dashboard=dashboard;w.__v143Dashboard=dashboard;afterRender()}},ms));
})();