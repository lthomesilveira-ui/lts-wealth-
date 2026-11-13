(function(){'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_BUDGET||!window.__LTS_V337_MONTH||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,strategy=window.parent.LTSV442Strategy,previous=render;
  const s={owner:null,month:'',parentMonth:null,mode:'month',status:'idle',data:null,sequence:0,queued:false,dialog:null};
  const day=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const gen=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!!D&&!N.classList.contains('hidden')&&V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='monthly';
  const money=v=>v===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v/100);
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function sync(){
   if(s.owner!==gen()||!D){s.owner=gen();s.sequence++;s.status='idle';s.data=null;s.parentMonth=null;s.dialog?.remove();s.dialog=null;}
   if(!s.month)s.month=day().slice(0,7);
  }
  function setMonth(v){if(!/^\d{4}-\d{2}$/.test(v))return;if(s.month.slice(0,4)!==v.slice(0,4)){s.sequence++;s.status='idle';s.data=null;}s.month=v;}
  async function load(force=false){
   sync();
   // A confirmed save can finish while an older budget read is still in flight.
   // Settle that read before requesting the saved revision; never reuse it.
   if(force&&s.status==='loading'&&s.request){const old=s.request,owner=s.owner;s.sequence++;await Promise.resolve(old).catch(()=>{});if(owner!==gen())return;sync();if(s.request===old)s.status='idle';}
   if(!visible()||s.status==='loading'||!force&&s.status!=='idle')return;
   const owner=s.owner,year=Number(s.month.slice(0,4)),seq=++s.sequence;s.status='loading';paint();
   try{const request=Promise.all([S.rpc('lts_browser_budget_read_v441',{p_year:year}),year>=Number(day().slice(0,4))?S.rpc('lts_browser_flow_v241',{p_from:day(),p_to:year+'-12-31'}):Promise.resolve({data:{flow:{current_future:{events:[]}}}}),S.rpc('lts_browser_card_cycles_v229',{})]);s.request=request;const responses=await request;if(responses.some(r=>r.error))throw Error();const m=api.build(strategy.derive(responses[0].data,responses[1].data,responses[2].data));
    if(owner!==gen()||seq!==s.sequence||year!==Number(s.month.slice(0,4)))return;s.data=m;s.status='ready';
   }catch{if(owner===gen()&&seq===s.sequence)s.status='error';}
   finally{if(owner===gen()&&seq===s.sequence)paint();}
  }
  const typeLabel=t=>({fixed:'Compromissos fixos',essential:'Essencial variável',discretionary:'Discricionário',seasonal:'Sazonal'}[t]||'A conferir');
  function popup(title,html){
   if(s.dialog)return null;const d=document.createElement('dialog');s.dialog=d;d.className='v441-dialog';d.innerHTML='<h2>'+esc(title)+'</h2>'+html+'<button data-close>Fechar</button>';
   const close=()=>{d.remove();if(s.dialog===d)s.dialog=null;};d.querySelector('[data-close]').onclick=close;d.addEventListener('cancel',e=>{e.preventDefault();close();});document.body.append(d);d.showModal();return{d,close};
  }
  function analysis(category){
   if(!s.data)return;const v=api.view(s.data,s.mode,s.month),r=v.rows.find(x=>x.category===category);if(!r)return;
   const x=popup(window.LTSCategoryDisplay?.category(category)||category,'<p>'+esc(typeLabel(r.type))+' · '+(r.target===null?'Plano ainda incompleto':r.suggested?'Proposta fundamentada, não aprovada':'Meta aprovada')+'</p><p>'+esc(r.reason)+'</p><p>Referência histórica mensal: <strong>'+money(r.reference)+'</strong></p><p>Valores já registrados e compromissos conhecidos: <strong>'+money(r.minimum)+'</strong></p>'+(r.minimum>r.target&&r.target!==null?'<p class="v441-warning">A meta aprovada está abaixo dos compromissos conhecidos. Ela não reduz o valor a pagar.</p>':'')+'<div>'+r.details.slice(0,40).map(z=>'<p>'+esc(z.description||'Compromisso')+(z.installment?' · parcela '+z.installment+'/'+z.total_installments:'')+' · '+money(api.cents(z.amount))+'</p>').join('')+'</div><p><button data-entries>Lançamentos do realizado</button> <button data-adjust>Ajustar meta</button></p>');
   if(!x)return;x.d.querySelector('[data-adjust]').onclick=()=>{x.close();edit(category);};x.d.querySelector('[data-entries]').onclick=()=>{x.close();entries(category);};
  }
  async function entries(category){
   const owner=s.owner,seq=s.sequence,year=s.month.slice(0,4),from=s.mode==='year'?year+'-01-01':s.month+'-01',to=s.mode==='year'?year+'-12-31':new Date(Date.UTC(Number(year),Number(s.month.slice(5)),0)).toISOString().slice(0,10);
   const x=popup('Lançamentos · '+(window.LTSCategoryDisplay?.category(category)||category),'<div data-content role="status">Carregando lançamentos…</div>');if(!x)return;
   try{let all=[],offset=0,rounds=0;
    if(from<=day())do{const r=await S.rpc('lts_browser_expense_detail_v353',{p_from:from,p_to:to<day()?to:day(),p_scope:{},p_offset:offset,p_limit:10000,p_query:null});if(r.error)throw Error();if(owner!==gen()||seq!==s.sequence||!x.d.isConnected)return;all.push(...(r.data?.rows||[]));offset=r.data?.next_offset??null;if(++rounds>100)throw Error();}while(offset!==null);
    const label=z=>{const c=z.current_category??z.original_category??z.category,n=String(c||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();return z.coverage_mode==='card_invoice_aggregate_fallback'?'Cartão — categoria não recuperada':!c||['a classificar','sem categoria','nao identificado','—'].includes(n)?'Sem classificação':c;};const seen=new Set(),rows=all.filter(z=>label(z)===category).filter(z=>{if(typeof z.key!=='string'||!z.key)throw Error();if(seen.has(z.key))return false;seen.add(z.key);return true;}),v=api.view(s.data,s.mode,s.month).rows.find(z=>z.category===category),total=rows.reduce((a,z)=>a+(api.cents(z.amount)||0),0);
    x.d.querySelector('[data-content]').innerHTML='<p>'+from+' a '+to+' · '+rows.length+' lançamento(s) · '+money(total)+'</p>'+(v&&total!==v.actual?'<p class="v441-warning">O detalhe difere do orçamento. Atualize os dados antes de decidir.</p>':'')+rows.map(z=>'<article><p><strong>'+esc(z.description||'Lançamento')+'</strong> · '+money(api.cents(z.amount))+'</p><p>'+esc(z.period||z.competence_month||z.event_date||z.date||'')+' · '+esc(z.account_source||'')+'</p></article>').join('')+(rows.length?'':'<p>Nenhum lançamento registrado neste período.</p>');
   }catch{if(x.d.isConnected)x.d.querySelector('[data-content]').textContent='Não foi possível carregar os lançamentos. Feche e tente novamente.';}
  }
  function edit(category){
   if(!s.data||s.status==='loading'||s.dialog)return;
   const year=s.data.year,month=Number(s.month.slice(5)),scope=s.mode,view=api.view(s.data,scope,s.month),row=view.rows.find(r=>r.category===category);
   const initial=category===null?view.incomeTarget:row?.target;
   const amount=initial===null?'':String(Math.round(initial/(scope==='year'?12:1))/100);
   const owner=s.owner,seq=s.sequence,revision=s.data.revision,d=document.createElement('dialog');s.dialog=d;d.className='v441-dialog';d.id='v441BudgetEdit';
   d.innerHTML='<h2>'+esc(category===null?'Renda regular de referência':category)+'</h2><label>Valor mensal em reais<input type="number" min="0" max="100000000" step="0.01" inputmode="decimal" value="'+esc(amount)+'" aria-label="Valor mensal da meta"></label><p>'+(scope==='year'?'Aplicar este valor em cada um dos 12 meses de '+year+'.':'Aplicar somente a '+s.month+'.')+'</p><p>Esta meta não altera pagamentos nem as projeções do Fluxo.</p><p role="status"></p><div><button type="button" data-cancel>Cancelar</button><button type="button" data-save>Aprovar e salvar</button></div>';
   const close=()=>{d.remove();if(s.dialog===d)s.dialog=null;};d.querySelector('[data-cancel]').onclick=close;d.addEventListener('cancel',e=>{e.preventDefault();if(!d.dataset.saving)close();});
   d.querySelector('[data-save]').onclick=async()=>{
    const input=d.querySelector('input'),n=Number(input.value),c=api.cents(input.value),status=d.querySelector('[role=status]');
    if(!input.value||c===null||n<0||n>100000000||Math.abs(n*100-c)>.00001){status.textContent='Informe um valor válido com até duas casas decimais.';return;}
    if(category!==null){const raw=s.data.rows.find(x=>x.category===category),selected=scope==='year'?raw.months:[raw.months[month-1]],minimum=Math.max(...selected.map(x=>api.cents(x.strategy?.floor??0)));if(c<minimum){status.textContent='Há '+money(minimum)+' em valores já registrados ou compromissos conhecidos. Ajuste a meta a partir desse valor; uma renegociação precisa ser refletida nos compromissos.';return;}}
    if(owner!==gen()||seq!==s.sequence){status.textContent='O período mudou. Feche e confira novamente.';return;}
    d.dataset.saving='true';d.querySelectorAll('button,input').forEach(b=>b.disabled=true);status.textContent='Salvando…';
    try{const r=await S.rpc('lts_browser_budget_save_v441',{p_year:year,p_month:scope==='year'?null:month,p_targets:category===null?{}:{[category]:c/100},p_income:category===null?c/100:null,p_expected:revision});
     if(r.error||r.data?.saved!==true)throw Error();if(owner!==gen())return;close();await load(true);
    }catch{if(d.isConnected){status.textContent='Não foi possível confirmar a meta. Feche e atualize o orçamento antes de tentar novamente.';d.querySelector('[data-cancel]').disabled=false;delete d.dataset.saving;s.status='error';paint();}}
   };
   document.body.append(d);d.showModal();d.querySelector('input').focus();
  }
  function paint(){
   sync();let host=document.getElementById('v441Budget');if(!visible()){host?.remove();return;}
   const page=document.querySelector('.v168-expenses'),anchor=page?.querySelector('.v175-monthly');if(!anchor)return;
   if(!host){host=document.createElement('section');host.id='v441Budget';host.className='v168-card v441-budget';anchor.after(host);}
   const year=Number(s.month.slice(0,4)),currentYear=Number(day().slice(0,4));
   let html='<header><div><span class="v441-kicker">Planejamento</span><h2>Orçamento estratégico</h2></div><div class="v441-controls"><button data-mode="month" aria-pressed="'+(s.mode==='month')+'">Mensal</button><button data-mode="year" aria-pressed="'+(s.mode==='year')+'">Anual</button>'+(s.mode==='month'?'<input type="month" aria-label="Mês do orçamento" min="'+(currentYear-1)+'-01" max="'+(currentYear+5)+'-12" value="'+s.month+'">':'<input type="number" aria-label="Ano do orçamento" min="'+(currentYear-1)+'" max="'+(currentYear+5)+'" value="'+year+'">')+'</div></header>';
   if(s.status==='error')html+='<p class="v441-warning" role="status">Não foi possível atualizar o orçamento.'+(s.data?' Os valores anteriores continuam abaixo.':'')+' <button data-retry>Tentar novamente</button></p>';
   if(!s.data)html+='<p role="status">'+(s.status==='error'?'Os valores deste período não estão disponíveis.':'Carregando orçamento…')+'</p>';
   else{
    const v=api.view(s.data,s.mode,s.month),kpi=(label,n)=>'<div><span>'+label+'</span><strong class="'+(n!==null&&n<0?'v441-negative':'')+'">'+money(n)+'</strong></div>';
    html+='<p class="v441-period">'+(s.mode==='year'?year:s.month)+' · '+(v.started?'registrado até '+s.data.asOf.split('-').reverse().join('/'):'período ainda não iniciado')+(s.mode==='year'?' · Orçado para 12 meses; realizado acumulado até a data acima.':'')+'</p>';
    html+='<div class="v441-kpis">'+kpi('Renda líquida recorrente',v.incomeTarget)+kpi(v.hasIncompletePlan?'Propostas definidas':v.rows.some(r=>r.suggested)?'Despesas propostas':'Orçado aprovado',v.hasIncompletePlan?v.proposedSubtotal:v.target)+kpi('Saldo do plano completo',v.plannedBalance)+kpi('Resultado registrado sem extras',v.started?v.operating:null)+'</div>';
    if(v.cashUnallocated.length){
     html+='<section class="v441-cash-reserve"><h3>Reservas de caixa por vencimento</h3><p>Pagamentos já previstos no calendário, sem faturas de cartão: <strong>'+money(v.cashWithoutCompetence)+'</strong>. Renda líquida recorrente prevista: <strong>'+money(v.incomeTarget)+'</strong>.</p>';
     if(v.cashCoverageGap>0)html+='<p class="v441-warning">Só este conjunto de pagamentos supera o salário previsto em '+money(v.cashCoverageGap)+', antes de outras despesas e faturas. Cortar gastos variáveis isoladamente pode não resolver. Avalie o calendário e alternativas para os compromissos; nenhuma renegociação ou entrada extraordinária está garantida.</p>';
     html+='<p class="v441-muted">Esta é uma visão de reserva de caixa por vencimento, não um total de consumo. Previsões podem mudar. A competência ainda não está comprovada; não some estes valores ao orçamento ou às faturas como novas despesas.</p><details><summary>Ver pagamentos previstos ('+v.cashUnallocated.length+')</summary>'+v.cashUnallocated.slice(0,100).map(x=>'<p>'+esc(x.date)+' · '+esc(x.description||x.category||'Pagamento previsto')+' · '+money(api.cents(x.amount))+'</p>').join('')+(v.cashUnallocated.length>100?'<p>Exibidos os primeiros 100 pagamentos. Consulte o restante no Fluxo.</p>':'')+'</details></section>';
    }
    if(v.hasIncompletePlan)html+='<p class="v441-warning">O plano ainda não tem cobertura completa por categoria. '+v.unplannedCategories+' categoria(s) sem meta definida. As propostas definidas são um subtotal, não o plano completo. '+(v.proposedDeficit>0?'Este subtotal já supera a renda em '+money(v.proposedDeficit)+'. ':'')+'Piso conhecido: '+money(v.minimum)+'. Não interprete os valores ausentes como zero.</p>';
    if(v.plannedBalance!==null&&v.plannedBalance<0)html+='<p class="v441-warning">O plano supera a renda líquida em <strong>'+money(-v.plannedBalance)+'</strong>. A proposta não cabe na renda recorrente. Avalie alternativas sem apagar os compromissos.</p>';
    if(s.data.reference.months<6||s.data.reference.salaryMonths<1)html+='<p class="v441-warning">A referência histórica está incompleta. Confira as metas e a renda antes de usar este orçamento.</p>';
    if(s.data.strategy?.pastWithoutPlan)html+='<p class="v441-muted">Há '+s.data.strategy.pastWithoutPlan+' mês(es) encerrado(s) sem orçamento aprovado. A visão anual preserva esta ausência.</p>';
    if(s.data.proposed)html+='<p class="v441-muted">Propostas fundamentadas permanecem separadas das metas aprovadas. Valores já registrados e compromissos são o piso, não um orçamento completo.</p>';
    html+='<div class="v441-extras">Renda regular registrada: <strong>'+money(v.started?v.incomeRegular:null)+'</strong> · Bônus registrado: <strong>'+money(v.started?v.bonus:null)+'</strong> · 13º registrado: <strong>'+money(v.started?v.thirteenth:null)+'</strong> · Outras entradas extraordinárias: <strong>'+money(v.started?v.extra-v.bonus-v.thirteenth:null)+'</strong><button data-income>Ajustar renda</button></div>';
    html+='<div class="v441-table" role="table" aria-label="Orçamento por categoria"><div class="v441-row v441-columns" role="row"><b>Categoria</b><b>Orçado</b><b>Realizado registrado</b><b>Diferença</b><span></span></div>';
    for(const r of v.rows)html+='<div class="v441-row" role="row"><strong>'+esc(window.LTSCategoryDisplay?.category(r.category)||r.category)+'<small>'+esc(typeLabel(r.type))+'</small></strong><span data-label="Orçado">'+money(r.target)+(r.target===null?' <small>sem plano completo</small>':r.suggested?' <small>proposta</small>':' <small>aprovado</small>')+'</span><span data-label="Realizado">'+money(v.started?r.actual:null)+'</span><span data-label="Diferença" class="'+(r.gap!==null&&r.gap<0?'v441-negative':'')+'">'+money(v.started?r.gap:null)+'</span><button data-why="'+esc(r.category)+'">Detalhes</button></div>';
    html+='</div>';
    if(v.minimum>v.incomeTarget&&v.incomeTarget!==null)html+='<p class="v441-warning">Valores já registrados e compromissos conhecidos: '+money(v.minimum)+', acima da renda. Rever metas não cancela essas obrigações.</p>';
    if(v.plannedBalance!==null&&v.plannedBalance<0)html+='<details class="v441-premises"><summary>Alternativas para o déficit</summary><p>Preserve as parcelas. Compare reduções viáveis por categoria, confira necessidades pelo detalhe e avalie renegociação de contratos. Um déficit não zera automaticamente gastos recorrentes. Bônus e 13º são extraordinários.</p></details>';
    if(v.pending)html+='<p class="v441-muted">O realizado inclui '+money(v.pending)+' em compras recebidas que ainda aguardam confirmação bancária.</p>';
    if(s.data.unknown)html+='<p class="v441-warning">Parte do histórico de cartões não tem categoria recuperada. O valor permanece identificado na lista.</p>';
    html+='<details class="v441-premises"><summary>Premissas do orçamento</summary><p>Renda líquida recorrente conforme salário previsto e recebimentos regulares; bônus, 13º e demais extraordinárias ficam separados. Obrigações e parcelas conhecidas são mantidas. O histórico descreve gastos passados; não define sozinho quanto deve ser gasto. Categorias sem proposta fundamentada continuam pendentes, sem percentuais genéricos e sem zeros artificiais para fechar a renda.</p><p>Compras entram uma vez por competência. Pagamentos de fatura, descontos já abatidos do salário e a provisão de novas compras do Fluxo não são somados novamente.</p><p>Sazonais sem calendário completo precisam de revisão. Nenhuma meta proposta altera pagamentos. Referência: '+esc(s.data.reference.from)+' a '+esc(s.data.reference.to)+'.</p></details>';
    if(s.status==='loading')html+='<p role="status">Atualizando orçamento…</p>';
   }
   host.innerHTML=html;
   host.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{s.mode=b.dataset.mode;paint();});
   const input=host.querySelector('input');if(input)input.oninput=input.onchange=()=>{const value=s.mode==='year'?input.value+'-'+s.month.slice(5):input.value;
    const y=Number(value.slice(0,4));if(/^\d{4}-(0[1-9]|1[0-2])$/.test(value)&&y>=currentYear-1&&y<=currentYear+5&&value!==s.month){setMonth(value);paint();}};
   host.querySelectorAll('[data-why]').forEach(b=>b.onclick=()=>analysis(b.dataset.why));host.querySelector('[data-income]')?.addEventListener('click',()=>edit(null));host.querySelector('[data-retry]')?.addEventListener('click',()=>load(true));
   if(s.status==='idle'&&!s.queued){s.queued=true;queueMicrotask(()=>{s.queued=false;load();});}
  }
  const style=document.createElement('style');style.textContent='.v441-budget{margin:0 0 18px}.v441-budget header,.v441-controls{display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap}.v441-budget h2{margin:4px 0 10px}.v441-kicker{font-size:11px;text-transform:uppercase;color:#3475cf;font-weight:700}.v441-budget button,.v441-budget input,.v441-dialog button,.v441-dialog input{font:inherit;min-height:42px;box-sizing:border-box;border:1px solid #cad8e7;background:white;border-radius:8px;padding:8px 10px;max-width:100%;color:#173a61}.v441-controls [aria-pressed=true]{background:#eaf2fc;font-weight:700}.v441-controls input{width:155px}.v441-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:16px 0}.v441-kpis>div{background:#f5f8fc;border-radius:10px;padding:12px}.v441-kpis span{display:block;font-size:12px;color:#526174}.v441-kpis strong{display:block;font-size:20px;margin-top:7px;overflow-wrap:anywhere}.v441-warning{background:#fff7e8;border-left:3px solid #bc8b33;padding:10px 12px;font-size:13px}.v441-negative{color:#a13030!important}.v441-extras{font-size:13px;line-height:1.8;margin:12px 0}.v441-extras button{margin-left:10px}.v441-row{display:grid;grid-template-columns:minmax(180px,2fr) repeat(3,minmax(100px,1fr)) auto;gap:12px;align-items:center;padding:12px 0;border-bottom:1px solid #e2e9f1;font-size:13px}.v441-row>span{overflow-wrap:anywhere}.v441-row small{display:block;color:#69788a;font-size:11px}.v441-row>strong{overflow-wrap:anywhere}.v441-columns{font-size:11px;color:#526174}.v441-muted,.v441-period{font-size:12px;color:#617083;line-height:1.6}.v441-premises{margin-top:16px;font-size:12px;color:#526174;line-height:1.6}.v441-premises summary{cursor:pointer}.v441-dialog{color:#17324f;border:1px solid #cad8e7;border-radius:16px;padding:22px;width:min(500px,calc(100vw - 28px));max-height:90vh;overflow:auto;box-sizing:border-box}.v441-dialog::backdrop{background:#11243b77}.v441-dialog label{display:grid;gap:8px}.v441-dialog p{font-size:13px;line-height:1.6}.v441-dialog>div{display:flex;justify-content:flex-end;gap:10px}@media(max-width:800px){.v441-kpis{grid-template-columns:1fr 1fr}.v441-kpis strong{font-size:17px}.v441-row{grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.v441-columns{display:none}.v441-row>strong{grid-column:1/3}.v441-row>button{grid-column:3;grid-row:1}.v441-row>span{grid-row:2;font-size:12px}.v441-row>span:before{content:attr(data-label);display:block;color:#617083;font-size:10px;margin-bottom:5px}.v441-extras button{display:block;margin:8px 0 0}}';document.head.append(style);
  const mobileStyle=document.createElement('style');mobileStyle.textContent='#v441Budget{scroll-margin-top:78px}.v441-budget button,.v441-budget input,.v441-dialog button,.v441-dialog input{min-height:44px}.v441-budget input,.v441-dialog input{font-size:16px}@media(max-width:359px){.v441-kpis{grid-template-columns:1fr}}';document.head.append(mobileStyle);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};
  window.addEventListener('lts:product-refresh-ready',()=>{s.sequence++;s.status='idle';s.data=null;if(visible())paint();});
  window.__LTS_V441_BUDGET={state:s,refresh:()=>load(true)};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V337_MONTH)return false;if(!w.__LTS_V441_BUDGET){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);}return !!w.__LTS_V441_BUDGET;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-budget-ui.js',install);
})();
