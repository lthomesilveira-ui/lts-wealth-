(function(){'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_BUDGET||!window.__LTS_V337_MONTH||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,previous=render;
  const s={owner:null,month:'',parentMonth:null,mode:'month',status:'idle',data:null,sequence:0,queued:false,dialog:null};
  const day=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const gen=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!!D&&!N.classList.contains('hidden')&&V==='Dashboard';
  const money=v=>v===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v/100);
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function sync(){
   if(s.owner!==gen()||!D){s.owner=gen();s.sequence++;s.status='idle';s.data=null;s.parentMonth=null;s.dialog?.remove();s.dialog=null;}
   const parent=window.__LTS_V337_MONTH.state.month||day().slice(0,7);
   if(parent!==s.parentMonth){s.parentMonth=parent;setMonth(parent);}
   if(!s.month)s.month=day().slice(0,7);
  }
  function setMonth(v){if(!/^\d{4}-\d{2}$/.test(v))return;if(s.month.slice(0,4)!==v.slice(0,4)){s.sequence++;s.status='idle';s.data=null;}s.month=v;}
  async function load(force=false){
   sync();if(!visible()||s.status==='loading'||!force&&s.status!=='idle')return;
   const owner=s.owner,year=Number(s.month.slice(0,4)),seq=++s.sequence;s.status='loading';paint();
   try{const r=await S.rpc('lts_browser_budget_read_v441',{p_year:year});if(r.error)throw Error();const m=api.build(r.data);
    if(owner!==gen()||seq!==s.sequence||year!==Number(s.month.slice(0,4)))return;s.data=m;s.status='ready';
   }catch{if(owner===gen()&&seq===s.sequence)s.status='error';}
   finally{if(owner===gen()&&seq===s.sequence)paint();}
  }
  function edit(category){
   if(!s.data||s.status==='loading'||s.dialog)return;
   const year=s.data.year,month=Number(s.month.slice(5)),scope=s.mode,view=api.view(s.data,scope,s.month),row=view.rows.find(r=>r.category===category);
   const initial=category===null?view.incomeTarget:row?.target;
   const amount=initial===null?'':String(Math.round(initial/(scope==='year'?12:1))/100);
   const owner=s.owner,seq=s.sequence,revision=s.data.revision,d=document.createElement('dialog');s.dialog=d;d.className='v441-dialog';d.id='v441BudgetEdit';
   d.innerHTML='<h2>'+esc(category===null?'Renda regular de referência':category)+'</h2><label>Valor mensal em reais<input type="number" min="0" max="100000000" step="0.01" inputmode="decimal" value="'+esc(amount)+'" aria-label="Valor mensal da meta"></label><p>'+(scope==='year'?'Aplicar este valor em cada um dos 12 meses de '+year+'.':'Aplicar somente a '+s.month+'.')+'</p><p>Esta meta não altera pagamentos nem as projeções do Fluxo.</p><p role="status"></p><div><button type="button" data-cancel>Cancelar</button><button type="button" data-save>Salvar meta</button></div>';
   const close=()=>{d.remove();if(s.dialog===d)s.dialog=null;};d.querySelector('[data-cancel]').onclick=close;d.addEventListener('cancel',e=>{e.preventDefault();if(!d.dataset.saving)close();});
   d.querySelector('[data-save]').onclick=async()=>{
    const input=d.querySelector('input'),n=Number(input.value),c=api.cents(input.value),status=d.querySelector('[role=status]');
    if(!input.value||c===null||n<0||n>100000000||Math.abs(n*100-c)>.00001){status.textContent='Informe um valor válido com até dois centavos.';return;}
    if(owner!==gen()||seq!==s.sequence){status.textContent='O período mudou. Feche e confira novamente.';return;}
    d.dataset.saving='true';d.querySelectorAll('button,input').forEach(b=>b.disabled=true);status.textContent='Salvando…';
    try{const r=await S.rpc('lts_browser_budget_save_v441',{p_year:year,p_month:scope==='year'?null:month,p_targets:category===null?{}:{[category]:c/100},p_income:category===null?c/100:null,p_expected:revision});
     if(r.error||r.data?.saved!==true)throw Error();if(owner!==gen())return;close();await load(true);
    }catch{if(d.isConnected){status.textContent='Não foi possível confirmar a meta. Feche e atualize o orçamento antes de tentar novamente.';d.querySelector('[data-cancel]').disabled=false;delete d.dataset.saving;}}
   };
   document.body.append(d);d.showModal();d.querySelector('input').focus();
  }
  function paint(){
   sync();let host=document.getElementById('v441Budget');if(!visible()){host?.remove();return;}
   const anchor=document.getElementById('v337Overview');if(!anchor)return;
   if(!host){host=document.createElement('section');host.id='v441Budget';host.className='v168-card v441-budget';anchor.after(host);}
   const year=Number(s.month.slice(0,4)),currentYear=Number(day().slice(0,4));
   let html='<header><div><span class="v441-kicker">Planejamento</span><h2>Orçado × Realizado</h2></div><div class="v441-controls"><button data-mode="month" aria-pressed="'+(s.mode==='month')+'">Mensal</button><button data-mode="year" aria-pressed="'+(s.mode==='year')+'">Anual</button>'+(s.mode==='month'?'<input type="month" aria-label="Mês do orçamento" min="'+(currentYear-1)+'-01" max="'+(currentYear+5)+'-12" value="'+s.month+'">':'<input type="number" aria-label="Ano do orçamento" min="'+(currentYear-1)+'" max="'+(currentYear+5)+'" value="'+year+'">')+'</div></header>';
   if(s.status==='error')html+='<p class="v441-warning" role="status">Não foi possível atualizar o orçamento.'+(s.data?' Os valores anteriores continuam abaixo.':'')+' <button data-retry>Tentar novamente</button></p>';
   if(!s.data)html+='<p role="status">'+(s.status==='error'?'Os valores deste período não estão disponíveis.':'Carregando orçamento…')+'</p>';
   else{
    const v=api.view(s.data,s.mode,s.month),kpi=(label,n)=>'<div><span>'+label+'</span><strong class="'+(n!==null&&n<0?'v441-negative':'')+'">'+money(n)+'</strong></div>';
    html+='<p class="v441-period">'+(s.mode==='year'?year:s.month)+' · '+(v.started?'registrado até '+s.data.asOf.split('-').reverse().join('/'):'período ainda não iniciado')+(s.mode==='year'?' · Orçado para 12 meses; realizado acumulado até a data acima.':'')+'</p>';
    html+='<div class="v441-kpis">'+kpi('Renda regular de referência',v.incomeTarget)+kpi('Despesas orçadas',v.target)+kpi('Saldo orçado',v.plannedBalance)+kpi('Resultado registrado sem extras',v.started?v.operating:null)+'</div>';
    if(v.plannedBalance!==null&&v.plannedBalance<0)html+='<p class="v441-warning">As metas superam a renda regular em <strong>'+money(-v.plannedBalance)+'</strong>. Ajuste as metas abaixo.</p>';
    if(s.data.reference.months<6||s.data.reference.salaryMonths<1)html+='<p class="v441-warning">A referência histórica está incompleta. Confira as metas e a renda antes de usar este orçamento.</p>';
    if(s.data.proposed)html+='<p class="v441-muted">Metas iniciais sugeridas pelo histórico. Você pode ajustar cada categoria.</p>';
    html+='<div class="v441-extras">Bônus registrado: <strong>'+money(v.started?v.bonus:null)+'</strong> · Outras entradas fora da renda regular: <strong>'+money(v.started?v.extra-v.bonus:null)+'</strong><button data-income>Ajustar renda</button></div>';
    html+='<div class="v441-table" role="table" aria-label="Orçamento por categoria"><div class="v441-row v441-columns" role="row"><b>Categoria</b><b>Orçado</b><b>Realizado registrado</b><b>Diferença</b><span></span></div>';
    for(const r of v.rows)html+='<div class="v441-row" role="row"><strong>'+esc(window.LTSCategoryDisplay?.category(r.category)||r.category)+'</strong><span data-label="Orçado">'+money(r.target)+(r.suggested?' <small>referência</small>':'')+'</span><span data-label="Realizado">'+money(v.started?r.actual:null)+'</span><span data-label="Diferença" class="'+(r.gap!==null&&r.gap<0?'v441-negative':'')+'">'+money(v.started?r.gap:null)+'</span><button data-edit="'+esc(r.category)+'">Ajustar</button></div>';
    html+='</div>';
    if(v.pending)html+='<p class="v441-muted">O realizado inclui '+money(v.pending)+' em compras recebidas que ainda aguardam confirmação bancária.</p>';
    if(s.data.unknown)html+='<p class="v441-warning">Parte do histórico de cartões não tem categoria recuperada. O valor permanece identificado na lista.</p>';
    html+='<details class="v441-premises"><summary>Premissas do orçamento</summary><p>Metas sugeridas usam a média dos seis meses completos anteriores. Gastos pontuais do histórico podem ser reduzidos ao ajustar as metas. A renda usa a mediana dos três últimos meses completos com salário registrado, sem bônus, férias e 13º.</p><p>Compras entram por competência. Pagamentos de fatura não são outra despesa. A provisão de R$ 15 mil do Fluxo não é somada novamente neste orçamento.</p><p>Bônus e outras entradas extraordinárias aparecem somente quando registrados. As metas não representam dinheiro disponível hoje.</p><p>Histórico de referência: '+esc(s.data.reference.from)+' a '+esc(s.data.reference.to)+'.</p></details>';
    if(s.status==='loading')html+='<p role="status">Atualizando orçamento…</p>';
   }
   host.innerHTML=html;
   host.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{s.mode=b.dataset.mode;paint();});
   const input=host.querySelector('input');if(input)input.onchange=()=>{const value=s.mode==='year'?input.value+'-'+s.month.slice(5):input.value;
    const y=Number(value.slice(0,4));if(/^\d{4}-(0[1-9]|1[0-2])$/.test(value)&&y>=currentYear-1&&y<=currentYear+5){setMonth(value);paint();}};
   host.querySelectorAll('[data-edit]').forEach(b=>b.onclick=()=>edit(b.dataset.edit));host.querySelector('[data-income]')?.addEventListener('click',()=>edit(null));host.querySelector('[data-retry]')?.addEventListener('click',()=>load(true));
   if(s.status==='idle'&&!s.queued){s.queued=true;queueMicrotask(()=>{s.queued=false;load();});}
  }
  const style=document.createElement('style');style.textContent='.v441-budget{margin:0 0 18px}.v441-budget header,.v441-controls{display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap}.v441-budget h2{margin:4px 0 10px}.v441-kicker{font-size:11px;text-transform:uppercase;color:#3475cf;font-weight:700}.v441-budget button,.v441-budget input,.v441-dialog button,.v441-dialog input{font:inherit;min-height:42px;box-sizing:border-box;border:1px solid #cad8e7;background:white;border-radius:8px;padding:8px 10px;max-width:100%;color:#173a61}.v441-controls [aria-pressed=true]{background:#eaf2fc;font-weight:700}.v441-controls input{width:155px}.v441-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:16px 0}.v441-kpis>div{background:#f5f8fc;border-radius:10px;padding:12px}.v441-kpis span{display:block;font-size:12px;color:#526174}.v441-kpis strong{display:block;font-size:20px;margin-top:7px;overflow-wrap:anywhere}.v441-warning{background:#fff7e8;border-left:3px solid #bc8b33;padding:10px 12px;font-size:13px}.v441-negative{color:#a13030!important}.v441-extras{font-size:13px;line-height:1.8;margin:12px 0}.v441-extras button{margin-left:10px}.v441-row{display:grid;grid-template-columns:minmax(180px,2fr) repeat(3,minmax(100px,1fr)) auto;gap:12px;align-items:center;padding:12px 0;border-bottom:1px solid #e2e9f1;font-size:13px}.v441-row>span{overflow-wrap:anywhere}.v441-row small{display:block;color:#69788a;font-size:11px}.v441-row>strong{overflow-wrap:anywhere}.v441-columns{font-size:11px;color:#526174}.v441-muted,.v441-period{font-size:12px;color:#617083;line-height:1.6}.v441-premises{margin-top:16px;font-size:12px;color:#526174;line-height:1.6}.v441-premises summary{cursor:pointer}.v441-dialog{color:#17324f;border:1px solid #cad8e7;border-radius:16px;padding:22px;width:min(500px,calc(100vw - 28px));max-height:90vh;overflow:auto;box-sizing:border-box}.v441-dialog::backdrop{background:#11243b77}.v441-dialog label{display:grid;gap:8px}.v441-dialog p{font-size:13px;line-height:1.6}.v441-dialog>div{display:flex;justify-content:flex-end;gap:10px}@media(max-width:800px){.v441-kpis{grid-template-columns:1fr 1fr}.v441-kpis strong{font-size:17px}.v441-row{grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.v441-columns{display:none}.v441-row>strong{grid-column:1/3}.v441-row>button{grid-column:3;grid-row:1}.v441-row>span{grid-row:2;font-size:12px}.v441-row>span:before{content:attr(data-label);display:block;color:#617083;font-size:10px;margin-bottom:5px}.v441-extras button{display:block;margin:8px 0 0}}';document.head.append(style);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};
  window.addEventListener('lts:product-refresh-ready',()=>{s.sequence++;s.status='idle';s.data=null;if(visible())paint();});
  window.__LTS_V441_BUDGET={state:s,refresh:()=>load(true)};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V337_MONTH)return false;if(!w.__LTS_V441_BUDGET){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);}return !!w.__LTS_V441_BUDGET;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-budget-ui.js',install);
})();
