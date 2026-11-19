/* lts-v398-family-loan.js */
/* Family debt: balance, correction and planning are separate visible concepts. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,state=window.__LTS_V168_STATE;
  const amount=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
  const money=v=>amount(v)===null?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function line(label,value){const row=document.createElement('div'),name=document.createElement('span'),number=document.createElement('b');row.className='v365-pair';name.textContent=label;number.textContent=money(value);row.append(name,number);return row;}
  function paragraph(text){const p=document.createElement('p');p.textContent=text;return p;}
  function after(){
   if(V==='Atualizações'){
    const task=document.querySelector('#v365WealthTasks>p');if(task)task.textContent='Consulte os saldos e documentos pendentes em Patrimônio.';
   }
   if(V!=='Patrimônio'||state.wealth?.tab!=='overview')return;
   const j=state.wealth?.data,c=j?.financing?.summary?.commitments?.find(x=>x.id==='pai_mae'),p=c?.indexation;
   const root=document.querySelector('.v168-wealth');if(!root||!p||root.querySelector('[data-v398-family]'))return;
   const debt=root.querySelector('[data-v386-debt="pai_mae"] .v365-pair');
   if(debt){let small=debt.querySelector('small');if(!small){small=document.createElement('small');debt.querySelector('span')?.append(small);}small.textContent=p.complete?'Corrigido pela poupança · sem vencimento definido':'Correção a atualizar · sem vencimento definido';}
   const card=document.createElement('article');card.className='v168-card v398-family';card.dataset.v398Family='';
   const title=document.createElement('h2');title.textContent='Empréstimo Pai e Mãe';card.append(title);
   card.append(paragraph('Sem vencimento definido · correção pela poupança'));
   card.append(line('Valor original',p.original_principal_brl),line('Correção acumulada',p.accrued_savings_brl));
   if(amount(p.confirmed_repayments_brl)>0)card.append(line('Pagamentos confirmados',p.confirmed_repayments_brl));
   card.append(line('Saldo devedor',p.balance_brl));
   card.append(paragraph(p.complete?'Correção até '+date(p.corrected_through)+'. O saldo diminui quando um pagamento é confirmado.':'Falta atualizar o índice da poupança para apresentar o saldo corrigido.'));
   const plan=document.createElement('details'),summary=document.createElement('summary');summary.textContent='Planejamento de pagamentos';plan.append(summary);
   plan.append(paragraph(String(c.remaining_events??0)+' parcelas estimadas no fluxo. As datas são uma previsão de planejamento.'));
   if(c.planned_next_payment_date)plan.append(line('Próxima previsão · '+date(c.planned_next_payment_date),c.planned_next_payment_amount));
   plan.append(line('Total previsto no fluxo',c.remaining_scheduled_outflow));
   plan.append(paragraph('As previsões não reduzem o saldo devedor e não são somadas novamente à dívida.'));card.append(plan);
   const origin=document.createElement('details'),originTitle=document.createElement('summary');originTitle.textContent='Origem e atualização';origin.append(originTitle);
   origin.append(paragraph('Valor original e início em '+date(p.starts_on)+' registrados na planilha original e confirmados com você. Correção pelos índices da poupança publicados pelo Banco Central, a cada aniversário mensal completo.'));
   card.append(origin);root.querySelector('.v365-columns')?.after(card);
  }
  const style=document.createElement('style');style.textContent='.v398-family{margin-top:16px}.v398-family p{color:#64748b;font-size:13px;line-height:1.5}.v398-family details{margin-top:12px}.v398-family summary{cursor:pointer;font-size:13px;font-weight:600}.v398-family .v365-pair>span{min-width:0}.v398-family .v365-pair>b{white-space:nowrap}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V398_FAMILY={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V398_FAMILY?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V398_FAMILY?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v398-family-loan.js',install);
})();

;
/* lts-v402-d01-composition.js */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render;let selected='';
  const money=v=>v===null||v===undefined?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function time(v){if(!v||Number.isNaN(new Date(v).getTime()))return '';return new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short',timeZone:'America/Sao_Paulo'}).format(new Date(v));}
  function pair(root,label,amount){const row=document.createElement('div'),span=document.createElement('span'),b=document.createElement('b');row.className='v402-d01-pair';span.textContent=label;b.textContent=money(amount);row.append(span,b);root.append(row);}
  function after(){
   if(V!=='Fluxo Diário'||ACC!=='Consolidado'||typeof FLOWQ==='undefined')return;
   const controls=document.querySelector('.flow-sticky-controls');if(!controls||document.getElementById('v402-d01-origin'))return;
   const days=[...(FLOWQ?.historical?.days||[]),...(FLOWQ?.current_future?.days||[])].filter(d=>d.fix86_columns?.d0_composition?.has_anchor);
   if(!days.length)return;
   if(!days.some(d=>d.date===selected))selected=days[0].date;
   const box=document.createElement('details'),summary=document.createElement('summary'),select=document.createElement('select'),body=document.createElement('div');
   box.id='v402-d01-origin';summary.textContent='D0/D1 · composição';box.append(summary);
   const label=document.createElement('label');label.textContent='Data ';select.setAttribute('aria-label','Data da composição D0/D1');
   for(const d of days){const o=document.createElement('option');o.value=d.date;o.textContent=date(d.date);select.append(o);}select.value=selected;label.append(select);box.append(label,body);
   function show(){selected=select.value;body.replaceChildren();const d=days.find(x=>x.date===selected),p=d.fix86_columns.d0_composition;
    for(const c of p.components||[])pair(body,'Saldo líquido · '+c.code,c.net_brl);
    pair(body,'Posição do Itaú · '+date(p.snapshot_date),p.snapshot_brl);
    for(const m of p.recorded_movements||[])pair(body,(m.asset_delta_brl<0?'Resgate':'Aplicação')+' · '+date(m.event_date),m.asset_delta_brl);
    for(const x of p.bank_redemptions||[])if(!x.represented_by_recorded_movement&&!x.representation_conflict)pair(body,'Resgate · '+date(x.event_date),-Number(x.bank_amount_brl));
    pair(body,'Cofrinho disponível',p.available_brl);pair(body,'Saldo em conta',d.fix86_columns.saldo_final);pair(body,'Saldo com D0/D1',d.fix86_columns.saldo_apos_d0_1);
    const consulted=time(p.source_observed_at);if(consulted){const line=document.createElement('p');line.textContent='Consultado em '+consulted+'.';body.append(line);}
    const note=document.createElement('p');note.textContent=p.complete?'Ações e FGTS são apresentados separadamente.':'Saldo do Cofrinho a conferir no banco.';body.append(note);
   }
   select.addEventListener('change',show);show();controls.after(box);
   const today=days.find(d=>d.date===new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo'}).format(new Date()));
   const current=today?.fix86_columns?.d0_composition;
   if(current&&(current.complete===false||current.provider_comparison_equal===false||current.daily_provider_position_available===false)){
    const warning=document.createElement('p');warning.id='v402-d01-warning';warning.setAttribute('role','status');warning.textContent=current.complete!==false&&current.daily_provider_position_available===false?'Atualização do saldo do Cofrinho pendente.':'Saldo do Cofrinho a conferir no banco.';box.before(warning);
   }
  }
  const style=document.createElement('style');style.textContent='#v402-d01-origin{margin:8px 0 12px;padding:8px 12px;border:1px solid #dce4ed;border-radius:10px;font-size:13px}#v402-d01-origin summary{cursor:pointer;font-weight:600}#v402-d01-origin label{display:block;margin:10px 0}#v402-d01-origin select{font-size:16px;min-height:44px;max-width:100%}.v402-d01-pair{display:flex;justify-content:space-between;gap:10px;padding:5px 0}.v402-d01-pair span{min-width:0;overflow-wrap:anywhere}.v402-d01-pair b{white-space:nowrap}#v402-d01-origin p{color:#64748b;line-height:1.45;margin:8px 0 2px}#v402-d01-warning{color:#8b4b08;font-size:13px;line-height:1.4;margin:8px 0}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V402_D01={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V402_D01?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V402_D01?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v402-d01-composition.js',install);
})();

;
/* lts-v407-wealth-summary.js */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,ids=['cipo_396','volvo','coopharma','pai_mae'];
  const money=value=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);
  function cents(value){
   if(value===null||value===undefined||!['string','number'].includes(typeof value)||!/^[-]?\d+(?:\.\d{1,2}0*)?$/.test(String(value)))return null;
   const n=Number(value),c=Math.round(n*100);return Number.isFinite(n)&&Number.isSafeInteger(c)?c:null;
  }
  function validDate(value){return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;}
  function assess(j){
   const gross=cents(j?.wealth_v167?.assets_central_including_pensions),known=cents(j?.wealth?.summary?.known_debt_total),commitments=j?.financing?.summary?.commitments,sourceDate=j?.financing?.summary?.as_of,asOf=validDate(sourceDate)?sourceDate:j?.as_of;
   if(gross===null||known===null||known<0||!validDate(asOf)||!Array.isArray(commitments))return {available:false};
   let documented=0,total=0;const missing=[];
   for(const id of ids){
    const rows=commitments.filter(c=>c?.id===id);if(rows.length>1)return {available:false};
    const c=rows[0],value=cents(c?.current_documentary_debt_balance);
    if(value!==null&&value>=0&&validDate(c?.current_debt_as_of)&&c.current_debt_as_of<=asOf){documented++;total+=value;}else missing.push(id);
   }
   const net=gross-known;
   if(!documented||!Number.isSafeInteger(total)||total!==known||!Number.isSafeInteger(net))return {available:false};
   return {available:true,gross:gross/100,known:known/100,net:net/100,documented,missing};
  }
  function pair(root,label,value){const row=document.createElement('div'),name=document.createElement('span'),amount=document.createElement('b');row.className='v407-wealth-pair';name.textContent=label;amount.textContent=money(value);row.append(name,amount);root.append(row);}
  function after(){
   if(V!=='Patrimônio'||window.__LTS_V168_STATE?.wealth?.tab!=='overview')return;
   const card=document.querySelector('.v365-wealth-totals .v386-incomplete-value')?.closest('article');if(!card||card.dataset.v407Partial==='true')return;
   const result=assess(window.__LTS_V168_STATE.wealth.data);if(!result.available)return;
   card.dataset.v407Partial='true';card.querySelector('span').textContent='Patrimônio líquido parcial';
   const value=card.querySelector('strong');value.classList.remove('v386-incomplete-value');value.textContent=money(result.net);
   card.querySelector('small').textContent='Estimativa com os saldos disponíveis. Há dívida a atualizar.';
   const detail=document.createElement('details'),summary=document.createElement('summary');detail.className='v407-wealth-basis';summary.textContent='Composição do subtotal';detail.append(summary);
   pair(detail,'Patrimônio bruto conhecido',result.gross);pair(detail,'Dívidas com saldo informado',result.known);pair(detail,'Patrimônio líquido parcial',result.net);card.append(detail);
  }
  const style=document.createElement('style');style.textContent='[data-v407-partial] strong{white-space:nowrap}.v407-wealth-basis{margin-top:10px;font-size:12px;font-weight:400}.v407-wealth-basis>summary{cursor:pointer;min-height:24px;line-height:1.5;color:#536174}.v407-wealth-pair{display:flex;flex-wrap:wrap;justify-content:space-between;gap:3px 8px;margin-top:7px}.v407-wealth-pair>span{font-size:12px!important;color:#536174}.v407-wealth-pair>b{white-space:nowrap;font-size:12px}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};window.__LTS_V407_WEALTH={installed:true,assess,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_WEALTH?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_WEALTH?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-wealth-summary.js',install);
})();

;
/* lts-v407-document-review.js */
/* Recover document visibility without approving or posting financial records. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,attempts=new Map(),objectURLs=new Set();
  // The embedded client implements Auth/RPC only. Complete only the private-document
  // operations it already exposes in the UI, using the existing session and server checks.
  async function documentRequest(endpoint,{method='GET',body,headers={},binary=false}={}){
   const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),method==='POST'?120000:30000);
   try{
    const {data,error}=await S.auth.getSession(),session=data?.session;if(error||!session?.access_token)throw Error('Sessão expirada. Entre novamente.');
    const response=await fetch(U+endpoint,{method,body,headers:{apikey:K,Authorization:'Bearer '+session.access_token,...headers},signal:controller.signal});
    if(!response.ok)throw Error(response.status===401||response.status===403?'Sessão sem acesso ao documento. Entre novamente.':'Não foi possível concluir a consulta do documento.');
    return {data:binary?await response.blob():await response.json(),error:null};
   }catch(error){return {data:null,error:{message:error?.message||'Não foi possível concluir a consulta do documento.'}};}
   finally{clearTimeout(timer);}
  }
  if(typeof S.auth.getUser!=='function')S.auth.getUser=async()=>{const result=await documentRequest('/auth/v1/user');return result.error?{data:{user:null},error:result.error}:{data:{user:result.data},error:null};};
  if(!S.storage?.from)S.storage={from(bucket){
   function target(path){const parts=String(path||'').split('/');if(bucket!=='lts-documents'||parts.length<2||parts.some(p=>!p||p==='.'||p==='..'||p.includes('\\')))throw Error('Caminho de documento inválido.');return encodeURIComponent(bucket)+'/'+parts.map(encodeURIComponent).join('/');}
   return {
    async upload(path,file,options={}){try{if(options.upsert===true)throw Error('Substituição de documento não permitida.');return await documentRequest('/storage/v1/object/'+target(path),{method:'POST',body:file,headers:{'Content-Type':options.contentType||file.type||'application/octet-stream','x-upsert':'false'}});}catch(error){return {data:null,error:{message:error.message}};}},
    async download(path){try{return await documentRequest('/storage/v1/object/authenticated/'+target(path),{binary:true});}catch(error){return {data:null,error:{message:error.message}};}}
   };
  }};
  const state={open:false,status:'idle',data:null,error:'',promise:null,generation:0};
  let uploadForm = null;
  let documentPanel = null;
  const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
  const date=v=>{const s=String(v||'').slice(0,10);return /^\d{4}-\d\d-\d\d$/.test(s)?s.split('-').reverse().join('/'):'Data a confirmar';};
  const money=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?'Valor a confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const phase={received:'Recebido',interpreted:'Leitura disponível',reconciled:'Conciliado',needs_decision:'Revisão pendente',resolved:'Concluído'};
  function confirmed(attempt,id){attempt.confirmed=true;attempt.inboxId=id;attempt.input.disabled=false;attempt.input.value='';attempt.button.disabled=false;attempt.button.textContent='Enviar para revisão';attempt.message.textContent='Arquivo recebido para revisão. Consulte Documentos enviados.';}
  function pair(root,label,value){if(value===undefined||value===null||value==='')return;const row=el('p',undefined,'v407-doc-pair');row.append(el('span',label),el('strong',String(value)));root.append(row);}
  function releaseURLs(){for(const u of objectURLs)URL.revokeObjectURL(u);objectURLs.clear();}
  function reset(){
   state.generation++;state.open=false;state.status='idle';state.data=null;state.error='';state.promise=null;
   attempts.clear();releaseURLs();uploadForm?.remove();uploadForm=null;
   if(documentPanel)documentPanel.open=false;
   paint();
   documentPanel=null;
  }
  async function refresh(){
   if(state.promise)return state.promise;
   const generation=state.generation;state.status='loading';state.error='';paint();
   state.promise=(async()=>{try{
    const {data,error}=await S.rpc('lts_browser_document_review_queue_v1',{p_limit:6});
    if(generation!==state.generation)return;
    if(error||data?.contract!=='v149-evidence-review-readonly-canonical-v1'||data.write_allowed!==false||data.financial_writer_called!==false||!Array.isArray(data.items)||!Number.isSafeInteger(data.queue_documents)||data.queue_documents<data.items.length)throw Error('unavailable');
    state.data=data;state.status='ready';
   }catch{if(generation===state.generation){state.status='error';state.error='Não foi possível atualizar os documentos. Tente consultar novamente.';}}
   finally{if(generation===state.generation){state.promise=null;paint();}}})();return state.promise;
  }
  async function showFile(item,button,box){
   const previousURL=box.querySelector('a[download]')?.href;
   if(previousURL&&objectURLs.delete(previousURL))URL.revokeObjectURL(previousURL);
   const generation=state.generation;button.disabled=true;box.replaceChildren(el('p','Abrindo arquivo…'));
   try{
    const {data:meta,error}=await S.rpc('lts_browser_document_meta_v1',{p_inbox_id:item.inbox_id});
    if(generation!==state.generation)return;
    if(error||meta?.ok!==true||typeof meta.storage_path!=='string')throw Error('unavailable');
    for(const attempt of attempts.values())if(attempt.path===meta.storage_path)confirmed(attempt,item.inbox_id);
    const {data:blob,error:downloadError}=await S.storage.from('lts-documents').download(meta.storage_path);
    if(generation!==state.generation||!box.isConnected)return;
    if(downloadError||!(blob instanceof Blob))throw Error('unavailable');
    const url=URL.createObjectURL(blob);objectURLs.add(url);box.replaceChildren();
    const link=el('a','Baixar arquivo');link.href=url;link.download=String(meta.original_name||item.original_name||'documento');link.className='v168-btn';box.append(link);
    // Raster previews stay inert; SVG/HTML and other formats are downloads only.
    if(/^image\/(png|jpeg|gif|webp|bmp)$/i.test(String(meta.mime_type||''))){const image=el('img');image.src=url;image.alt=String(item.original_name||'Documento enviado');box.append(image);}
   }catch{box.replaceChildren(el('p','Não foi possível abrir o arquivo. Consulte novamente antes de reenviar.'));}
   finally{button.disabled=false;}
  }
  function paint(){
   const host=document.getElementById('v407DocumentsBody');if(!host)return;
   releaseURLs();host.replaceChildren();
   const tools=el('div',undefined,'v407-doc-tools'),button=el('button',state.status==='loading'?'Consultando…':'Atualizar documentos','v168-btn');button.type='button';button.disabled=state.status==='loading';button.onclick=refresh;tools.append(button);host.append(tools);
   if(state.error){const warning=el('p',state.error);warning.setAttribute('role','status');host.append(warning);}
   const data=state.data;if(!data){if(state.status!=='error')host.append(el('p','Consulte os documentos enviados para conferir os arquivos e as informações disponíveis.'));return;}
   const items=data.items;
   if(!data.queue_documents){host.append(el('p','Nenhum documento aguardando revisão nesta consulta.'));return;}
   host.append(el('p',items.length<data.queue_documents?'Mostrando '+items.length+' documentos recentes de '+data.queue_documents+' aguardando revisão.':'Documentos aguardando revisão: '+data.queue_documents+'.'));
   for(const item of items){
    const article=el('article',undefined,'v407-document'),heading=el('h3',String(item.original_name||'Documento enviado'));
    article.append(heading,el('p',(phase[item.phase]||'Em revisão')+' · '+date(item.updated_at)));
    const view=el('button','Ver arquivo','v168-btn'),file=el('div',undefined,'v407-doc-file');view.type='button';view.onclick=()=>showFile(item,view,file);article.append(view,file);
    const detail=el('details'),summary=el('summary','Conferir informações');detail.append(summary);
    const association=item.document_association&&typeof item.document_association==='object'?item.document_association:{};
    const links=el('section');links.append(el('h4','Vínculo informado'));
    const types={bank_statement:'Extrato bancário',card_statement:'Fatura de cartão',card_invoice:'Fatura de cartão',financing_statement:'Financiamento',other_financial_document:'Outro documento'};
    for(const [label,value]of [['Banco',association.institution||association.bank],['Conta',association.account],['Cartão',association.card||association.card_name],['Competência',association.competence||association.competency||association.month],['Data de referência',association.reference_date?date(association.reference_date):null],['Documento',types[association.document_type]],['Observação',association.note]])if(typeof value==='string'||typeof value==='number')pair(links,label,value);
    if(links.children.length===1)links.append(el('p','Vínculo não disponível nesta consulta. Confira o arquivo antes de usar as informações.'));
    detail.append(links);const entries=Array.isArray(item.review_payload?.entries)?item.review_payload.entries:[];
    detail.append(el('h4','Informações extraídas'));
    if(!entries.length)detail.append(el('p','Sem lançamentos extraídos. O arquivo continua disponível para conferência.'));
    for(const entry of entries){const row=el('div',undefined,'v407-doc-entry');row.append(el('strong',String(entry.description||'Lançamento a conferir')));pair(row,'Data',date(entry.event_date));pair(row,'Valor',money(entry.amount));pair(row,'Conta',entry.account);pair(row,'Cartão',entry.card);pair(row,'Categoria',entry.category);detail.append(row);}
    if(item.evidence_truncated||Number(item.entry_count)>entries.length)detail.append(el('p','Mostrando '+entries.length+' de '+item.entry_count+' linhas. Consulte o arquivo para conferir o conteúdo completo.'));
    detail.append(el('p','A consulta não aprova nem cria lançamentos.'));article.append(detail);host.append(article);
   }
  }
  function createUploadForm(){
   const form=el('form',undefined,'v476-upload');
   const typeLabel=el('label','Tipo de documento'),type=el('select');
   for(const [value,label] of [
    ['other_financial_document','Comprovante ou recibo'],['bank_statement','Extrato bancário'],
    ['card_statement','Fatura de cartão'],['financing_statement','Financiamento']
   ]){
    const option=el('option',label);option.value=value;type.append(option);
   }
   typeLabel.append(type);
   const fileLabel=el('label','Arquivo'),input=el('input');
   input.type='file';input.accept='application/pdf,image/*,.pdf,.csv,.txt,.tsv,.xls,.xlsx';
   fileLabel.append(input);
   const button=el('button','Enviar para revisão','v168-btn'),message=el('p');
   button.type='submit';message.setAttribute('role','status');
   form.append(typeLabel,fileLabel,button,message);
   form.onsubmit=async event=>{
    event.preventDefault();
    if(button.disabled)return;
    const file=input.files[0];
    if(!file){message.textContent='Escolha um arquivo.';return;}
    if(!file.size||file.size>52428800){message.textContent='Escolha um arquivo com conteúdo de até 50 MB.';return;}
    const generation=state.generation;
    button.disabled=input.disabled=type.disabled=true;
    message.textContent='Enviando arquivo…';
    try{
     const digest=await crypto.subtle.digest('SHA-256',await file.arrayBuffer());
     if(generation!==state.generation)return;
     const args={p_sha256:Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join(''),
      p_original_name:file.name,p_size_bytes:file.size,p_mime_type:file.type||'application/octet-stream',p_document_type:type.value};
     const register=()=>S.rpc('lts_browser_review_document_file_v476',args);
     let result=await register();
     if(generation!==state.generation)return;
     const wasReceived=result.data?.state==='received';
     if(!result.error&&result.data?.ok&&result.data.state==='upload_required'){
      const path=result.data.storage_path;
      await S.storage.from('lts-documents').upload(path,file,{contentType:args.p_mime_type,upsert:false});
      if(generation!==state.generation)return;
      // A lost upload response or a simultaneous submission is resolved by the private registration.
      result=await register();
     }
     if(generation!==state.generation)return;
     if(result.error||!result.data?.ok||result.data.state!=='received'||!result.data.inbox_id)throw Error();
     input.value='';
     message.textContent=wasReceived?'Este arquivo já foi recebido.':'Arquivo recebido para revisão.';
     if(state.promise)await state.promise;
     if(generation===state.generation)await refresh();
    }catch{
     if(generation===state.generation)message.textContent='Não foi possível confirmar o envio. Tente novamente com o mesmo arquivo.';
    }finally{
     if(generation===state.generation)button.disabled=input.disabled=type.disabled=false;
    }
   };
   return form;
  }
  function mount(){
   if(!D){if(documentPanel||state.data||state.promise||attempts.size)reset();return;}
   if(V!=='Atualizações'){
    if(documentPanel){releaseURLs();documentPanel.remove();documentPanel=null;}
    return;
   }
   const root=document.querySelector('.v168-updates');if(!root)return;
   // The parent can redraw while a private file is opening. Keep the live controls and their pending read.
   if(documentPanel){
    if(documentPanel.parentElement!==root)root.append(documentPanel);
    return;
   }
   root.querySelector('#v407Documents')?.remove();
   const box=el('details',undefined,'v168-card v407-documents');box.id='v407Documents';box.open=state.open;box.append(el('summary','Enviar e consultar documentos'));
   documentPanel=box;
   if(!uploadForm)uploadForm=createUploadForm();
   box.append(uploadForm);
   const body=el('div');body.id='v407DocumentsBody';box.append(body);root.append(box);
   box.addEventListener('toggle',()=>{if(documentPanel!==box)return;state.open=box.open;if(box.open&&state.status==='idle')refresh();});paint();
  }
  // The original parser is retained: review-only structured entries, never a ledger write.
  function structured(rawText){
   const raw=rawText.replace(/^\uFEFF/,'').slice(0,2000000),lines=raw.split(/\r?\n/).filter(x=>x.trim());if(lines.length<2)throw Error('Arquivo sem linhas suficientes.');
   const cand=[',',';','\t','|'],sep=cand.sort((a,b)=>lines[0].split(b).length-lines[0].split(a).length)[0];
   const split=line=>{const out=[];let cur='',q=false;for(let i=0;i<line.length;i++){const ch=line[i];if(ch==='"'){if(q&&line[i+1]==='"'){cur+='"';i++;}else q=!q;}else if(ch===sep&&!q){out.push(cur.trim());cur='';}else cur+=ch;}out.push(cur.trim());return out;};
   const h=split(lines[0]),norm=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim(),find=(o,names)=>{for(const k of Object.keys(o)){const nk=norm(k);if(names.some(w=>nk===w||nk.includes(w)))return o[k];}return null;};
   const amount=v=>{let s=String(v??'').trim().replace(/R\$\s*/gi,'').replace(/\s/g,'');if(!s)return null;if(/^[-+]?\d{1,3}(\.\d{3})*,\d{1,2}$/.test(s))s=s.replace(/\./g,'').replace(',','.');else if(/^[-+]?\d+,\d{1,2}$/.test(s))s=s.replace(',','.');const n=Number(s);return Number.isFinite(n)?n:null;};
   const day=v=>{const s=String(v??'').trim();let m=s.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);if(m)return `${m[1]}-${m[2].padStart(2,'0')}-${m[3].padStart(2,'0')}`;m=s.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$/);if(m){let y=Number(m[3]);if(y<100)y+=2000;return `${y}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;}return null;};
   const entries=lines.slice(1,1001).map((line,i)=>{const vals=split(line),o={};h.forEach((k,j)=>o[k||`col_${j+1}`]=vals[j]??'');let value=amount(find(o,['valor','amount','value','total']));const deb=amount(find(o,['debito','débito'])),cred=amount(find(o,['credito','crédito']));if(value==null){if(deb!=null)value=-Math.abs(deb);else if(cred!=null)value=Math.abs(cred);}const desc=String(find(o,['descricao','descrição','description','historico','histórico','memo','estabelecimento','merchant'])||'').trim(),dt=day(find(o,['data','date','dia','lancamento','purchase date','transaction date'])),account=String(find(o,['conta','account','banco','bank'])||'').trim()||null,card=String(find(o,['cartao','cartão','card'])||'').trim()||null,nature=(value??0)<0?'expense':'income',missing=[];if(!dt)missing.push('data');if(value==null||value===0)missing.push('valor');if(!desc)missing.push('descrição');if(!account&&!card)missing.push('conta/cartão');return {source_entry_index:i,event_date:dt,amount:value==null?null:Number(value.toFixed(2)),nature,account,card,category:'A classificar',cost_center:null,counterparty:null,description:desc||`Linha ${i+1}`,missing,requires_review:true,write_allowed:false,parser_version:'browser-delimited-v1'};}).filter(x=>x.event_date||x.amount!=null||x.description);
   return {raw,interpretation:{version:'browser-delimited-v1',kind:'delimited_text',entries,total_rows_seen:Math.max(0,lines.length-1),interpreted_entries:entries.length,review_required:true,write_allowed:false}};
  }
  async function send({input,button,message,context,parseText}){
   const file=input?.files?.[0];if(!file||!button||!message){if(message)message.textContent='Escolha um arquivo.';return;}
   if(button.disabled)return;
   if(!Number.isFinite(file.size)||file.size<=0||file.size>52428800){message.textContent='Escolha um arquivo com conteúdo de até 50 MB.';return;}
   const key=JSON.stringify([file.name,file.size,file.type,file.lastModified,context]),existing=attempts.get(key);
   if(existing){message.textContent=existing.confirmed?'Este arquivo já foi recebido. Consulte Documentos enviados.':'Um envio deste arquivo ainda precisa de confirmação. Consulte Documentos enviados antes de reenviar.';if(existing.confirmed)input.value='';else button.disabled=true;return;}
   const attempt={started:false,confirmed:false,input,button,message};attempts.set(key,attempt);button.disabled=true;input.disabled=true;button.textContent='Enviando…';message.textContent='Enviando arquivo…';
   try{
    const text=parseText&&(file.type.startsWith('text/')||/\.(csv|txt|tsv)$/i.test(file.name))?structured(await file.text()):null;
    const {data:user,error:userError}=await S.auth.getUser();if(userError||!user?.user?.id)throw Error('Sessão expirada. Entre novamente.');
    const safe=String(file.name||'documento').replace(/[^a-zA-Z0-9._-]/g,'_').slice(-120),path=user.user.id+'/'+today()+'/'+crypto.randomUUID()+'-'+safe;
    attempt.started=true;attempt.path=path;
    const {error:uploadError}=await S.storage.from('lts-documents').upload(path,file,{contentType:file.type||'application/octet-stream',upsert:false});if(uploadError)throw Error('O envio não foi confirmado.');
    const args={p_storage_path:path,p_original_name:file.name,p_mime_type:file.type||(text?'text/plain':'application/octet-stream'),p_size_bytes:file.size,p_task_context:context};
    let result,kind;
    if(text)result=await S.rpc('lts_browser_register_structured_text_v2',{...args,p_raw_text:text.raw,p_interpretation:text.interpretation});
    else{kind=file.type==='application/pdf'||/\.pdf$/i.test(file.name)?'pdf':file.type.startsWith('image/')?'photo':'file';result=await S.rpc('lts_browser_register_document_v2',{...args,p_input_type:kind});}
    if(result.error||result.data?.ok!==true||!result.data.inbox_id)throw Error('O registro não foi confirmado.');
    confirmed(attempt,result.data.inbox_id);
    if(parseText&&!text&&kind==='file'){try{await interpretDoc(result.data.inbox_id);}catch{/* The source remains available for manual review. */}}
    // A failed refresh is not a failed upload. The registered source is kept.
    state.status='idle';await refresh();if(parseText){try{await load();}catch{/* Registration was confirmed independently. */}}
   }catch(error){
    if(attempt.started){button.textContent='Confirmação pendente';message.textContent='Não foi possível confirmar o envio. O arquivo foi preservado se recebido. Consulte Documentos enviados antes de reenviar.';state.status='idle';}
    else{attempts.delete(key);input.disabled=false;button.disabled=false;button.textContent='Enviar para revisão';message.textContent=error?.message==='Sessão expirada. Entre novamente.'?error.message:'Não foi possível preparar o arquivo. Confira o formato e tente novamente.';}
   }
  }
  upload=()=>send({input:document.getElementById('file'),button:document.getElementById('ubtn'),message:document.getElementById('up'),context:inputTaskContext(),parseText:true});
  if(typeof u133UploadDocument==='function')u133UploadDocument=button=>send({input:document.getElementById('u133DocFile'),button,message:document.getElementById('u133DocMsg'),context:{source:'updates_document_panel_v133',document_type:document.getElementById('u133DocType')?.value||'other_financial_document',requested_action:'ingest_reconcile'},parseText:false});
  const style=el('style');style.textContent='.v407-documents{margin-top:16px}.v407-documents>summary{cursor:pointer;font-size:16px;font-weight:650;min-height:44px;display:flex;align-items:center}.v407-documents p{font-size:13px;line-height:1.5;color:#526174;overflow-wrap:anywhere}.v407-doc-tools{display:flex;gap:8px;margin:12px 0}.v407-document{border-top:1px solid #dce4ed;padding:14px 0}.v407-document h3{font-size:15px;overflow-wrap:anywhere;margin:0 0 4px}.v407-document h4{font-size:13px;margin:12px 0 4px}.v407-document summary{cursor:pointer;min-height:44px;padding-top:12px}.v407-doc-entry{border-top:1px solid #e8edf3;padding:10px 0}.v407-doc-entry>strong{font-size:13px;overflow-wrap:anywhere}.v407-doc-pair{display:flex;justify-content:space-between;gap:12px;margin:4px 0}.v407-doc-pair>span,.v407-doc-pair>strong{min-width:0;overflow-wrap:anywhere}.v407-doc-pair>strong{text-align:right}.v407-doc-file img{display:block;max-width:100%;max-height:500px;object-fit:contain;margin-top:12px}.v407-documents .v168-btn{min-height:44px;max-width:100%;white-space:normal;overflow-wrap:anywhere}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);mount();return result;};
  style.textContent+='.v476-upload{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,13rem),1fr));align-items:end;gap:12px;margin:12px 0}.v476-upload label{display:grid;gap:5px;min-width:0}.v476-upload select,.v476-upload input{box-sizing:border-box;width:100%;min-width:0;min-height:44px;font:inherit}.v476-upload p{grid-column:1/-1;margin:0}.v476-upload p:empty{display:none}';
  for(const name of ['signOut','signInWithPassword'])if(typeof S.auth[name]==='function'){const previous=S.auth[name].bind(S.auth);S.auth[name]=function(){reset();return previous(...arguments);};}
  window.addEventListener('pagehide',()=>{
   releaseURLs();
   documentPanel?.querySelectorAll('.v407-doc-file').forEach(box=>box.replaceChildren());
  });
  window.__LTS_V407_DOCUMENTS={installed:true,refresh,mount};mount();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_DOCUMENTS?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_DOCUMENTS?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-document-review.js',install);
})();

;
/* lts-v408-cipo-source.js */
/* Documentary acquisition groups. This module never changes financial values. */
(function () {
  'use strict';
  function createAPI() {
    const schema = 'cipo-acquisition-documentary-v408';
    function integer(value) {
      const n = Number(value);
      if (!Number.isSafeInteger(n) || n < 1) throw Error('Invalid source row');
      return n;
    }
    function cents(value) {
      if (!/^\d+(?:\.\d{1,2})?$/.test(String(value))) throw Error('Invalid amount');
      const n = Math.round(Number(value) * 100);
      if (!Number.isSafeInteger(n)) throw Error('Amount outside supported range');
      return n;
    }
    function day(value) {
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) throw Error('Invalid date');
      const d = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(d.getTime()) || d.toISOString().slice(0, 10) !== value) throw Error('Invalid date');
      return value;
    }
    function build(payload) {
      if (payload == null) return null;
      if (payload.schema !== schema || payload.property_code !== 'cipo396'
        || payload.evidence_kind !== 'workbook_acquisition_composition') throw Error('Unexpected evidence');
      const verifiedOn = day(payload.verified_on);
      if (!Array.isArray(payload.groups) || payload.groups.length !== 32
        || !Array.isArray(payload.residuals) || payload.residuals.length !== 5
        || !Array.isArray(payload.source_files) || payload.source_files.length !== 2) throw Error('Incomplete evidence');
      const files = new Map();
      for (const file of payload.source_files) {
        if (!file.file || files.has(file.file) || !/^[a-f0-9]{64}$/.test(file.sha256 || '')) throw Error('Invalid source file');
        files.set(file.file, file);
      }
      if (payload.source_files.filter(x => x.primary === true).length !== 1) throw Error('Missing primary source');
      const keys = new Set(), sourceRefs = new Set(), sourceRows = new Set(), ids = new Set();
      let count = 0, total = 0, constructor = 0, broker = 0, dateDifferences = 0;
      const groups = payload.groups.map(group => {
        const row = integer(group.source_row), scheduledDate = day(group.scheduled_date);
        if (!group.id || ids.has(group.id) || sourceRows.has(row) || group.source_sheet !== 'Sonho'
          || group.individual_allocation !== null || !Array.isArray(group.cash_rows) || !group.cash_rows.length) throw Error('Invalid acquisition group');
        ids.add(group.id); sourceRows.add(row);
        for (const [key, column] of [['schedule_date', 'W'], ['constructor', 'Y'], ['broker', 'Z'], ['total', 'AA']]) {
          if (group.source_cells?.[key] !== column + row) throw Error('Invalid group source');
        }
        const a = cents(group.constructor_brl), b = cents(group.broker_brl), t = cents(group.total_brl);
        if (a + b !== t || t <= 0) throw Error('Components do not reconcile');
        let cashTotal = 0;
        const cash = group.cash_rows.map(item => {
          const ref = item.source_table + ':' + item.source_ref;
          if (item.source_table !== 'evento_base' || !/^\d+$/.test(String(item.source_ref))
            || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref)) throw Error('Duplicate or invalid cash identity');
          keys.add(item.row_key); sourceRefs.add(ref);
          const amount = cents(item.amount), date = day(item.event_date);
          if (amount <= 0 || !Array.isArray(item.workbook_rows) || item.workbook_rows.length !== 2) throw Error('Incomplete cash source');
          const seenFiles = new Set();
          for (const evidence of item.workbook_rows) {
            const n = integer(evidence.row);
            if (!files.has(evidence.file) || seenFiles.has(evidence.file)
              || evidence.sheet !== 'Pagamentos e Recebimentos' || evidence.property_label !== 'Cipó 396'
              || evidence.description_cell !== 'A' + n || evidence.amount_cell !== 'B' + n
              || evidence.date_cell !== 'C' + n || evidence.property_cell !== 'G' + n) throw Error('Incomplete workbook identity');
            seenFiles.add(evidence.file);
          }
          count++; cashTotal += amount;
          return { date, cents: amount, sourceRows: item.workbook_rows.map(x => ({ file: x.file, sheet: x.sheet, row: x.row })) };
        });
        const differs = cash.some(item => item.date !== scheduledDate);
        if (cashTotal !== t || group.date_difference !== differs) throw Error('Cash group does not reconcile');
        if (differs) dateDifferences++;
        total += t; constructor += a; broker += b;
        return { id: group.id, sourceRow: row, scheduledDate, constructorCents: a, brokerCents: b, totalCents: t, cash, dateDifference: differs };
      });
      const residuals = payload.residuals.map(item => {
        const ref = item.source_table + ':' + item.source_ref;
        if (!['evento_base', 'financial_events'].includes(item.source_table) || !item.source_ref
          || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref) || !item.reason) throw Error('Invalid residual identity');
        keys.add(item.row_key); sourceRefs.add(ref);
        const amount = cents(item.amount);
        if (!amount) throw Error('Invalid residual amount');
        return { date: day(item.event_date), cents: amount, description: item.description, reason: item.reason };
      });
      const residualTotal = residuals.reduce((sum, item) => sum + item.cents, 0);
      if (count !== 43 || dateDifferences !== 3 || total !== cents(payload.documented_total_brl)
        || constructor !== cents(payload.constructor_total_brl) || broker !== cents(payload.broker_total_brl)
        || residualTotal !== cents(payload.residual_total_brl)
        || payload.counts?.groups !== 32 || payload.counts?.documented_rows !== 43
        || payload.counts?.residual_rows !== 5 || payload.counts?.date_difference_groups !== 3) throw Error('Evidence totals do not reconcile');
      return { groups, residuals, verifiedOn, totalCents: total, constructorCents: constructor, brokerCents: broker,
        residualTotalCents: residualTotal, rowCount: count, dateDifferences, files: payload.source_files.map(x => ({ ...x })) };
    }
    function renderPanel(document, model) {
      const el = (tag, text, className) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (className) e.className = className; return e; };
      const money = n => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(n / 100);
      const date = value => value.split('-').reverse().join('/');
      const pair = (label, amount) => { const e = el('div', null, 'v408-pair'); e.append(el('span', label), el('b', money(amount))); return e; };
      const section = el('section', null, 'v408-cipo-source'); section.dataset.v408Cipo = '';
      section.append(el('p', 'Conferência de ' + date(model.verifiedOn) + ': ' + model.rowCount + ' lançamentos documentados. Falta detalhar 5 lançamentos (' + money(model.residualTotalCents) + ').', 'v408-material'));
      const details = el('details'); details.append(el('summary', 'Composição histórica da aquisição'));
      details.append(el('p', 'A planilha separa os pagamentos entre construtora e corretora. Os valores abaixo compõem a aquisição do imóvel.'));
      const totals = el('div', null, 'v408-totals'); totals.append(pair('Construtora', model.constructorCents), pair('Corretora', model.brokerCents), pair('Total documentado', model.totalCents)); details.append(totals);
      details.append(el('p', '32 grupos reúnem os 43 lançamentos. A composição é apresentada por grupo, sem dividir seus componentes entre os pagamentos de caixa.'));
      const list = el('div', null, 'v408-groups');
      for (const group of model.groups) {
        const item = el('details', null, 'v408-group');
        const dates = [...new Set(group.cash.map(x => x.date))].sort();
        const label = dates.length === 1 ? date(dates[0]) : date(dates[0]) + ' a ' + date(dates[dates.length - 1]);
        const title = el('summary'); title.append(el('span', label + ' · ' + group.cash.length + (group.cash.length === 1 ? ' lançamento' : ' lançamentos')), el('b', money(group.totalCents))); item.append(title);
        if (group.constructorCents) item.append(pair('Construtora', group.constructorCents));
        if (group.brokerCents) item.append(pair('Corretora', group.brokerCents));
        if (group.dateDifference) item.append(el('p', 'A grade registra ' + date(group.scheduledDate) + '. As datas originais de caixa são as apresentadas abaixo.', 'v408-date-difference'));
        for (const cash of group.cash) item.append(pair('Caixa · ' + date(cash.date), cash.cents));
        const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem'));
        origin.append(el('p', 'Sonho · linha ' + group.sourceRow + ' · colunas W, Y, Z e AA.'));
        for (const file of model.files) {
          const rows = group.cash.flatMap(x => x.sourceRows.filter(y => y.file === file.file).map(y => y.row));
          origin.append(el('p', file.file + ' · Pagamentos e Recebimentos · ' + (rows.length === 1 ? 'linha ' : 'linhas ') + rows.join(', ') + '.'));
        }
        item.append(origin); list.append(item);
      }
      details.append(list);
      const residual = el('details', null, 'v408-residuals'); residual.append(el('summary', 'Cinco lançamentos ainda em conferência'));
      for (const item of model.residuals) { const row = el('div', null, 'v408-residual'); row.append(pair(date(item.date), item.cents), el('p', item.reason)); residual.append(row); }
      details.append(residual);
      const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem e limites'));
      origin.append(el('p', 'Planilha original de julho de 2026 e sua cópia compactada. A cópia confere as mesmas células; não é uma segunda confirmação bancária.'));
      origin.append(el('p', 'Há três grupos com datas diferentes entre a grade e o caixa. Ambas são preservadas. Esta composição não informa principal amortizado ou juros do financiamento bancário.'));
      origin.append(el('p', 'Os 44 pagamentos bancários já documentados e os nove outros itens de aquisição permanecem separados desta composição.'));
      for (const file of model.files) origin.append(el('p', file.file + ' · SHA-256 ' + file.sha256));
      details.append(origin); section.append(details); return section;
    }
    return { build, renderPanel };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V408_CIPO?.installed) return;
    const api = factory(), prior = render, state = window.__LTS_V168_STATE, seen = new WeakMap();
    function after() {
      if (V !== 'Patrimônio' || state.wealth?.tab !== 'assets') return;
      const card = document.querySelector('[data-v309-contract="cipo_396"]');
      if (!card) return;
      const docs = state.wealth?.data?.financing?.documentary?.items || [];
      const entries = docs.filter(x => x.commitment_id === 'cipo_396' && x.metadata?.acquisition_documentary_bridge_v408).map(x => x.metadata.acquisition_documentary_bridge_v408);
      const payload = entries[0];
      if (seen.get(card) === payload && card.querySelector('[data-v408-cipo]')) return;
      card.querySelector('[data-v408-cipo]')?.remove();
      if (!payload) return;
      seen.set(card, payload);
      try {
        if (entries.some(x => JSON.stringify(x) !== JSON.stringify(payload))) throw Error('Conflicting evidence copies');
        card.append(api.renderPanel(document, api.build(payload)));
      } catch {
        const warning = document.createElement('p'); warning.dataset.v408Cipo = ''; warning.className = 'v408-material';
        warning.textContent = 'A composição histórica precisa ser conferida antes de ser exibida. Atualize os dados de patrimônio.'; card.append(warning);
      }
    }
    const style = document.createElement('style'); style.id = 'v408-cipo-style';
    style.textContent = '.v408-cipo-source{margin-top:14px;padding-top:10px;border-top:1px solid #dce3e9}.v408-cipo-source p{font-size:13px;line-height:1.5;color:#536174}.v408-material{font-size:13px;line-height:1.5;color:#825b22!important}.v408-cipo-source details{margin-top:10px}.v408-cipo-source summary{cursor:pointer;font-size:13px;font-weight:600;padding:8px 0}.v408-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:7px 0;font-size:13px}.v408-pair b,.v408-group>summary>b{white-space:nowrap;font-variant-numeric:tabular-nums}.v408-groups{margin:12px 0}.v408-group{border-top:1px solid #e5eaf0;padding:3px 0}.v408-group>summary{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap}.v408-group[open]{padding-bottom:8px}.v408-origin{font-size:12px;overflow-wrap:anywhere}.v408-origin p{font-size:12px}.v408-date-difference{color:#825b22!important}.v408-residual{padding:5px 0;border-bottom:1px solid #e5eaf0}.v408-residual p{margin:2px 0 9px}.v408-totals{margin:10px 0}@media(max-width:700px){.v408-pair{gap:8px}.v408-group>summary span{min-width:0;flex:1}.v408-cipo-source summary{font-size:12px}.v408-pair span{min-width:0}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    window.__LTS_V408_CIPO = { installed: true, after }; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed) return false;
      if (w.__LTS_V408_CIPO?.installed) return true;
      const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script);
      return !!w.__LTS_V408_CIPO?.installed;
    } catch { return false; }
  }
  let tries = 0;
  function start() { if (!install() && ++tries < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { tries = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v408-cipo-source.js', install);
})();

;
/* lts-v411-rsu-policy.js */
/* Gross and estimated net awards. Financial values are supplied by the server. */
(function () {
  'use strict';
  function createAPI() {
    const fail = () => { throw Error('Invalid RSU policy response'); };
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (typeof value !== 'number' && typeof value !== 'string') return fail();
      const text = String(value);
      if (!/^\d+(?:\.\d{1,2})?$/.test(text)) return fail();
      const [whole, fraction = ''] = text.split('.');
      const result = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail();
      return Number(result);
    }
    function quantity(value) {
      if ((typeof value !== 'number' && typeof value !== 'string') || !/^\d+(?:\.\d+)?$/.test(String(value))) return fail();
      const n = Number(value); if (!Number.isFinite(n) || n < 0) return fail(); return n;
    }
    function day(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) return fail();
      const parsed = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) return fail();
      return value;
    }
    function sum(values) {
      const result = values.reduce((a, b) => a + BigInt(b), 0n);
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail(); return Number(result);
    }
    function amounts(source, keys = ['gross_value_brl', 'net_value_brl', 'reserve_value_brl']) {
      const [gross, net, reserve] = keys.map(k => cents(source[k]));
      if (sum([net, reserve]) !== gross) return fail(); return { gross, net, reserve };
    }
    function grant(source) {
      const grantDate = day(source.grant_date, true), eligible = source.acceleration_eligible;
      if (![true, false, null].includes(eligible)) return fail();
      if (eligible === true && (!grantDate || grantDate >= '2026-01-01' || !source.grant_id)) return fail();
      if (grantDate && grantDate >= '2026-01-01' && eligible !== false) return fail();
      if (source.grant_year != null && (!grantDate || Number(source.grant_year) !== Number(grantDate.slice(0, 4)))) return fail();
      return { grantId: source.grant_id || null, grantDate, eligible };
    }
    function build(payload) {
      if (!payload || payload.version !== 'rsu-policy-v411' || payload.schema_version !== 1) return fail();
      const p = payload.policy;
      if (p?.enabled === false) return null;
      if (p?.enabled !== true || Number(p.reserve_rate) !== 0.30 || Number(p.net_factor) !== 0.70
        || p.cash_already_available_untouched !== true || p.retention_award_excluded !== true
        || !Array.isArray(p.scope) || p.scope.length !== 2 || !p.scope.includes('RSU') || !p.scope.includes('Cash RSU')) return fail();
      const keys = new Set(), awardIds = new Set();
      if (!Array.isArray(payload.future_schedule)) return fail();
      const schedule = payload.future_schedule.map(row => {
        if (!row.group_key || keys.has(row.group_key) || !['RSU', 'Cash RSU'].includes(row.asset_type)
          || !Array.isArray(row.components) || !row.components.length || ![true, false, null].includes(row.acceleration_eligible)) return fail();
        keys.add(row.group_key);
        const a = amounts(row), eligibilityDate = day(row.eligibility_date), availableDate = day(row.available_date);
        if (availableDate < eligibilityDate) return fail();
        const components = row.components.map(item => {
          if (!item.award_id || awardIds.has(item.award_id)) return fail(); awardIds.add(item.award_id);
          const c = amounts(item), vesting = day(item.eligibility_date), available = day(item.available_date), g = grant(item);
          if (vesting !== eligibilityDate || available < vesting || available > availableDate) return fail();
          return { ...c, ...g, id: item.award_id, quantity: quantity(item.quantity), vesting, available,
            valuationBasis: item.valuation_basis || null, grantLinkStatus: item.grant_link_status || null };
        });
        if (sum(components.map(x => x.gross)) !== a.gross || sum(components.map(x => x.net)) !== a.net
          || sum(components.map(x => x.reserve)) !== a.reserve
          || row.acceleration_eligible === true && components.some(x => x.eligible !== true)) return fail();
        return { ...a, key: row.group_key, type: row.asset_type, eligibilityDate, availableDate,
          quantity: quantity(row.quantity), eligible: row.acceleration_eligible, components };
      });
      const s = payload.summary || {}, total = amounts(s, ['schedule_gross_brl', 'schedule_net_brl', 'schedule_reserve_brl']);
      const regular = { gross: cents(s.regular_gross_brl), net: cents(s.regular_net_brl) }, cash = { gross: cents(s.cash_gross_brl), net: cents(s.cash_net_brl) };
      if (sum([regular.gross, cash.gross]) !== total.gross || sum([regular.net, cash.net]) !== total.net
        || sum(schedule.map(x => x.gross)) !== total.gross || sum(schedule.map(x => x.net)) !== total.net
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.gross)) !== regular.gross
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.net)) !== regular.net) return fail();
      let reference = null;
      if (payload.morgan_reference !== null) {
        const r = payload.morgan_reference;
        if (!r || r.currency !== 'BRL' || r.replaces_dated_position !== false) return fail();
        const asOf = day(r.as_of_date, true);
        if (r.reference_date_known !== (asOf !== null)) return fail();
        const received = r.received_at ? new Date(r.received_at) : null;
        if (received && !Number.isFinite(received.getTime())) return fail();
        reference = { asOf, receivedAt: r.received_at || null, receivedOn: day(r.received_on ?? null, true), gross: cents(r.total_gross_brl), available: cents(r.available_total_brl),
          unavailableGross: cents(r.unavailable_gross_brl), regular: { gross: cents(r.regular_rsu_gross_brl), net: cents(r.regular_rsu_net_brl) },
          cash: { gross: cents(r.cash_rsu_gross_brl), net: cents(r.cash_rsu_net_brl) }, brokerageCash: cents(r.brokerage_cash_brl),
          unallocatedGross: cents(r.unallocated_gross_brl), unallocatedNet: cents(r.unallocated_net_brl, true),
          knownGross: cents(r.known_awards_gross_brl), knownNet: cents(r.known_awards_net_brl), knownAfterReserve: cents(r.known_after_reserve_brl) };
        if (sum([reference.available, reference.unavailableGross]) !== reference.gross
          || sum([reference.regular.gross, reference.cash.gross, reference.unallocatedGross]) !== reference.unavailableGross
          || sum([reference.regular.gross, reference.cash.gross]) !== reference.knownGross
          || sum([reference.regular.net, reference.cash.net]) !== reference.knownNet
          || sum([reference.knownNet, reference.brokerageCash]) !== reference.knownAfterReserve
          || reference.unallocatedGross > 0 && reference.unallocatedNet !== null) return fail();
      }
      let acceleration = null;
      if (payload.acceleration !== null) {
        const a = payload.acceleration;
        if (!a || a.status !== 'conditional' || a.confirmed_date !== null || a.calendar_unchanged !== true
          || a.grant_cutoff !== '2026-01-01' || typeof a.event !== 'string' || !a.event.trim() || !Array.isArray(a.grants)) return fail();
        const ids = new Set();
        const grants = a.grants.map(g => {
          const v = grant(g); if (!v.grantId || ids.has(v.grantId) || !v.grantDate || !['RSU', 'Cash RSU'].includes(g.asset_type)) return fail();
          ids.add(v.grantId); return { ...v, type: g.asset_type, quantity: quantity(g.quantity) };
        });
        const mapped = a.schedule_mapped_count, unmapped = a.schedule_unmapped_count;
        if (![mapped, unmapped].every(n => Number.isInteger(n) && n >= 0)) return fail();
        acceleration = { event: a.event, grants, priceUsd: cents(a.contract_price_usd), eligibleQuantity: quantity(a.eligible_quantity),
          excludedQuantity: quantity(a.excluded_quantity), grossUsd: cents(a.eligible_gross_usd), netUsd: cents(a.eligible_net_usd),
          gross: cents(a.eligible_gross_brl, true), net: cents(a.eligible_net_brl, true),
          fxRate: a.fx_rate == null ? null : quantity(a.fx_rate), fxBasis: a.fx_basis || null, mapped, unmapped };
        if ((acceleration.gross === null) !== (acceleration.net === null)) return fail();
      }
      let payroll = null;
      if (payload.payroll_policy !== null) {
        const p = payload.payroll_policy;
        if (!p || p.coopharma_treatment !== 'subtract_documented_schedule_once' || p.actual_net_preserved !== true || p.forecasts_only !== true) return fail();
        payroll = { base: cents(p.monthly_base_brl) };
      }
      return { total, regular, cash, schedule, reference, acceleration, payroll };
    }
    function matchGroup(row, group) {
      if (!row || !group || row.group_key !== group.key || row.asset_type !== group.type) return false;
      try { return day(row.eligibility_date) === group.eligibilityDate && day(row.available_date) === group.availableDate
        && cents(row.gross_value_brl) === group.gross && cents(row.net_value_brl) === group.net
        && quantity(row.quantity) === group.quantity; } catch { return false; }
    }
    return { build, cents, day, matchGroup };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V411_RSU?.installed) return;
    const api = factory(), prior = render, ui = window.__LTS_V168_STATE;
    const state = { installed: true, version: 'v411', status: 'idle', token: 0, model: null, error: null };
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity(), marketRevision = null;
    const money = (n, currency = 'BRL') => n === null || n === undefined ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency }).format(n / 100);
    const number = n => new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 6 }).format(n);
    const date = d => d ? d.split('-').reverse().join('/') : 'não informada';
    const el = (tag, text, cls) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (cls) e.className = cls; return e; };
    const pair = (label, value) => { const p = el('div', null, 'v411-pair'); p.append(el('span', label), el('b', money(value))); return p; };
    function disclosure(title) { const d = el('details', null, 'v411-origin'); d.append(el('summary', title)); return d; }
    function table(regular, cash, total) {
      const t = el('table', null, 'v411-values'); t.setAttribute('aria-label', 'RSUs: valores brutos e líquidos estimados');
      const head = el('thead'), hr = el('tr'); for (const s of ['Tipo', 'Bruto', 'Líquido estimado']) hr.append(el('th', s)); head.append(hr); t.append(head);
      const body = el('tbody');
      for (const [name, value] of [['RSUs', regular], ['Cash RSUs', cash], ['Total', total]]) {
        const tr = el('tr'); tr.append(el('th', name), el('td', money(value?.gross)), el('td', money(value?.net))); body.append(tr);
      }
      t.append(body); return t;
    }
    function warning(message) { const p = el('p', message, 'v411-warning'); p.setAttribute('role', 'status'); return p; }
    function retry() { const b = el('button', 'Atualizar valores', 'v168-btn'); b.type = 'button'; b.dataset.v411Refresh = ''; b.onclick = () => refresh(); return b; }
    function statusNote() {
      if (state.status === 'error') { const p = warning('Não foi possível conferir os valores líquidos das RSUs. Atualize antes de usar a projeção.'); p.append(document.createTextNode(' '), retry()); return p; }
      return el('p', 'Conferindo valores brutos e líquidos…', 'v411-loading');
    }
    function projection(model) {
      const card = el('article', null, 'v168-card v411-projection'); card.dataset.v411Projection = '';
      card.append(el('h2', 'RSUs e Cash RSUs · agenda normal'), table(model?.regular, model?.cash, model?.total));
      if (!model) card.append(statusNote());
      else card.append(el('p', 'Líquido estimado após reserva de 30% para planejamento. Os vestings futuros permanecem fora do dinheiro disponível hoje.', 'v411-note'));
      return card;
    }
    function referencePanel(r) {
      const card = el('article', null, 'v168-card v411-reference'); card.dataset.v411Reference = '';
      card.append(el('h2', 'Posição informada pela corretora'), pair('Total bruto informado', r.gross));
      const total = { gross: r.knownGross, net: r.knownNet };
      card.append(table(r.regular, r.cash, total), pair('Dinheiro já disponível', r.brokerageCash), pair('Componentes identificados após reserva + dinheiro', r.knownAfterReserve));
      if (!r.asOf) card.append(warning('A data desta posição não foi informada. Ela permanece separada da posição datada.'));
      if (r.unallocatedGross > 0) card.append(warning('Falta identificar ' + money(r.unallocatedGross) + ' do total bruto. O líquido completo ainda está em apuração.'));
      const origin = disclosure('Origem e data');
      origin.append(el('p', 'Data da posição: ' + date(r.asOf) + '.'));
      if (r.receivedAt) origin.append(el('p', 'Recebido em ' + new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Sao_Paulo' }).format(new Date(r.receivedAt)) + ' (Brasília).'));
      else if (r.receivedOn) origin.append(el('p', 'Recebido em ' + date(r.receivedOn) + '.'));
      origin.append(el('p', 'A referência documental e a agenda de vestings usam bases distintas e não são somadas. Dinheiro já disponível não recebe nova reserva. Retention Award permanece separado.')); card.append(origin); return card;
    }
    function accelerationPanel(a) {
      const card = el('article', null, 'v168-card v411-acceleration'); card.dataset.v411Acceleration = '';
      card.append(el('h2', 'Antecipação condicional'), el('p', a.event, 'v411-note'), warning('Data ainda não confirmada. A agenda normal permanece em vigor.'));
      card.append(el('p', 'A quantidade é o saldo ainda não adquirido da referência. Vestings ocorridos antes do fechamento devem ser excluídos; o valor final depende do saldo no fechamento.', 'v411-note'));
      card.append(pair('Bruto elegível no cenário', a.gross), pair('Líquido estimado no cenário', a.net));
      const detail = disclosure('Concessões e premissas do cenário');
      detail.append(el('p', 'Somente concessões anteriores a 2026 participam desta condição. As concessões de 2026 mantêm seus vestings originais.'));
      detail.append(el('p', 'Preço contratual: ' + money(a.priceUsd, 'USD') + '. Valor bruto elegível: ' + money(a.grossUsd, 'USD') + '; líquido estimado: ' + money(a.netUsd, 'USD') + '.'));
      detail.append(el('p', a.fxRate === null ? 'Conversão para reais ainda indisponível.' : 'Câmbio considerado: ' + number(a.fxRate) + ' reais por dólar.'));
      for (const g of a.grants) detail.append(el('p', date(g.grantDate) + ' · ' + g.type + ' · ' + number(g.quantity) + ' unidades · ' + (g.eligible === true ? 'incluída na condição' : g.eligible === false ? 'fora desta antecipação' : 'elegibilidade em conferência')));
      if (a.unmapped > 0) card.append(warning('O cenário usa as concessões documentadas. Ainda falta vincular ' + a.unmapped + ' componente(s) à agenda; nenhuma data foi antecipada.'));
      card.append(detail); return card;
    }
    function componentOrigin(group) {
      const d = disclosure('Origem e composição desta parcela'); d.classList.add('v411-component-origin');
      for (const c of group.components) {
        const line = el('div', null, 'v411-component');
        line.append(el('p', number(c.quantity) + ' unidades · concessão ' + (c.grantDate ? date(c.grantDate) : 'a identificar') + '.'));
        line.append(pair('Bruto', c.gross), pair('Líquido estimado', c.net));
        line.append(el('p', 'Vesting ' + date(c.vesting) + ' · disponibilidade prevista ' + date(c.available) + '.'));
        line.append(el('p', c.eligible === true ? 'Concessão anterior a 2026; participa somente do cenário condicional.' : c.eligible === false ? 'Fora da antecipação; calendário original preservado.' : 'Concessão ainda sem vínculo documental nesta parcela.'));
        d.append(line);
      }
      d.append(el('p', 'Reserva de 30% como premissa de planejamento. Vesting e disponibilidade prevista não comprovam recebimento bancário.')); return d;
    }
    function patchQuoteModal() {
      if (!state.model) return;
      const modal = document.getElementById('v168Modal');
      if (!modal?.querySelector('#v168AwSave')) return;
      const note = [...modal.querySelectorAll('.v168-note')].find(n => /RSU normal|Cash RSU usa/.test(n.textContent));
      if (note) note.textContent = 'RSUs e Cash RSUs usam líquido estimado após reserva de 30% para planejamento. O valor bruto permanece no acompanhamento.';
    }
    function patchAgenda(root, model) {
      const agenda = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Vestings e disponibilidade');
      if (!agenda) return;
      const total = agenda.querySelector('.v168-cardhead strong'); if (total) total.textContent = money(model?.total.net);
      agenda.querySelectorAll('.v183-award-model-note').forEach(n => n.remove());
      const rows = ui.wealth?.data?.rsu?.future_schedule || [];
      [...agenda.querySelectorAll('.v168-award')].forEach((card, index) => {
        const row = rows[index], group = model?.schedule.find(x => x.key === row?.group_key), matches = api.matchGroup(row, group);
        const value = card.children[3];
        if (value) { value.replaceChildren(el('span', 'Bruto'), el('b', money(matches ? group.gross : null)), el('span', 'Líquido estimado'), el('b', money(matches ? group.net : null)), el('small', date(row?.available_date) + ' · disponibilidade prevista')); value.classList.add('v411-award-values'); }
        card.querySelectorAll('[data-v168-award-date]').forEach(input => input.closest('label')?.remove());
        card.querySelectorAll('[data-v168-award-save]').forEach(button => button.remove());
        card.querySelectorAll('.v183-award-source,.v411-component-origin,.v411-group-warning').forEach(n => n.remove());
        if (matches) card.append(componentOrigin(group));
        else { const p = warning(model ? 'Esta parcela precisa ser atualizada para conferir bruto e líquido.' : 'Líquido em conferência.'); p.classList.add('v411-group-warning'); card.append(p); }
      });
    }
    function patchKpi(root, label, value, note, displayedLabel) {
      const k = [...root.querySelectorAll('.v168-kpi')].find(x => x.querySelector('span')?.textContent.trim() === label);
      if (!k) return; const v = k.querySelector('strong'); if (v) v.textContent = money(value); const s = k.querySelector('small'); if (s) s.textContent = note;
      if (displayedLabel) k.querySelector('span').textContent = displayedLabel;
    }
    function patchDashboard(model) {
      const root = document.querySelector('.v168-dashboard'); if (!root) return;
      patchKpi(root, 'RSUs futuras', model?.regular.net, model ? 'Líquido estimado · bruto ' + money(model.regular.gross) : 'Líquido em conferência');
      patchKpi(root, 'Cash RSUs futuras', model?.cash.net, model ? 'Líquido estimado · bruto ' + money(model.cash.gross) : 'Líquido em conferência');
      for (const label of ['Total de posições futuras', 'Compensação futura', 'RSUs e Cash RSUs futuras']) patchKpi(root, label, model?.total.net, model ? 'Após reserva de 30% · bruto ' + money(model.total.gross) + ' · Retention Award separado' : 'Líquido em conferência', 'RSUs e Cash RSUs futuras');
      root.querySelector('[data-v411-dashboard]')?.remove();
      if (!model && state.status === 'error') { const p = statusNote(); p.dataset.v411Dashboard = ''; root.prepend(p); }
    }
    function patchWealth(model) {
      const root = document.querySelector('.v168-wealth'); if (!root) return;
      root.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration]').forEach(n => n.remove());
      if (ui.wealth?.tab === 'overview') {
        const card = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Valores a receber no futuro');
        if (card) card.replaceWith(projection(model)); return;
      }
      if (ui.wealth?.tab !== 'rsu') return;
      const anchor = root.querySelector('.v168-tabs') || root.querySelector('[role="tablist"]');
      const p = projection(model); if (anchor) anchor.after(p); else root.prepend(p);
      let last = p;
      if (model?.reference) { const card = referencePanel(model.reference); last.after(card); last = card; }
      if (model?.acceleration) { const card = accelerationPanel(model.acceleration); last.after(card); }
      patchAgenda(root, model);
      // Old comparison cards remain documentary history, not the current net policy.
      root.querySelectorAll('.v172-morgan > .v168-note').forEach(n => { n.textContent = 'Posição datada e agenda são bases distintas. A agenda atual considera reserva de 30% para RSUs e Cash RSUs.'; });
      const oldReference = root.querySelector('.v352-brokerage-reference');
      if (oldReference && model?.reference && !oldReference.parentElement?.classList.contains('v411-prior-reference')) {
        const d = disclosure('Referência anteriormente cadastrada'); d.classList.add('v411-prior-reference'); oldReference.before(d); d.append(oldReference);
      }
    }
    function patchFlow(model) {
      document.querySelector('[data-v411-flow-policy]')?.remove();
      const controls = document.querySelector('.flow-sticky-controls'); if (!controls) return;
      if (!model) { if (state.status === 'error') { const p = statusNote(); p.dataset.v411FlowPolicy = ''; controls.after(p); } return; }
      const d = disclosure('Premissas de RSU e salário'); d.dataset.v411FlowPolicy = '';
      d.append(el('p', 'RSUs e Cash RSUs: líquido estimado após reserva de 30%, disponível nas datas da agenda normal. A condição de antecipação permanece separada.'));
      if (model.payroll) d.append(el('p', 'Previsão de salário mensal: base ' + money(model.payroll.base) + ' menos a parcela Coopharma da competência. Valores já líquidos do holerite permanecem preservados.'));
      controls.after(d);
    }
    function after() {
      if (owner !== identity()) { owner = identity(); marketRevision = null; invalidate(); }
      if (!D || N.classList.contains('hidden')) return;
      if (!['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) return;
      if (state.status === 'idle') queueMicrotask(() => load());
      if (state.status === 'disabled') return;
      if (V === 'Dashboard') patchDashboard(state.model);
      if (V === 'Patrimônio') patchWealth(state.model);
      if (V === 'Fluxo Diário') patchFlow(state.model);
      patchQuoteModal();
    }
    async function load(force = false) {
      if (!D || N.classList.contains('hidden')) return;
      if (state.status === 'loading' || !force && state.status !== 'idle') return;
      const token = ++state.token, requestedOwner = identity(); state.status = 'loading'; state.error = null;
      try {
        const response = await S.rpc('lts_browser_rsu_policy_v411', {});
        if (token !== state.token || requestedOwner !== identity()) return;
        if (response?.error) throw Error('Policy unavailable');
        state.model = api.build(response?.data); state.status = state.model ? 'ready' : 'disabled';
      } catch {
        if (token !== state.token || requestedOwner !== identity()) return;
        state.model = null; state.status = 'error'; state.error = 'unavailable';
      }
      if (['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) render();
    }
    function invalidate() { state.token++; state.status = 'idle'; state.model = null; state.error = null; }
    function refresh() {
      invalidate();
      if (ui.wealth) { ui.wealth.data = null; ui.wealth.error = null; }
      window.__LTS_V178_REVIEW?.refresh?.(); render(); load();
    }
    const rpc = S.rpc.bind(S), writers = new Set(['lts_browser_save_all_award_assumptions_v1', 'lts_browser_save_award_assumption_v1', 'lts_browser_market_mode_v290']);
    S.rpc = function (name, args, ...rest) {
      const result = rpc(name, args, ...rest);
      if (name === 'lts_browser_market_quotes_v290') return Promise.resolve(result).then(response => {
        if (!response?.error && response?.data?.revision != null) {
          const changed = marketRevision !== null && marketRevision !== response.data.revision;
          marketRevision = response.data.revision;
          if (changed) { invalidate(); queueMicrotask(() => load()); }
        }
        return response;
      });
      if (!writers.has(name)) return result;
      return Promise.resolve(result).then(response => { if (!response?.error && response?.data?.ok) { invalidate(); queueMicrotask(() => load()); } return response; });
    };
    S.auth.onAuthStateChange?.(event => { if (event === 'SIGNED_OUT' || event === 'SIGNED_IN') { invalidate(); document.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration],[data-v411-flow-policy]').forEach(n => n.remove()); } });
    document.addEventListener('click', event => {
      if (event.target.closest?.('[data-v168-award-edit]')) patchQuoteModal();
    });
    document.addEventListener('click', event => { if (event.target.closest?.('#logout')) invalidate(); }, true);
    const style = el('style'); style.id = 'v411-rsu-style';
    style.textContent = '.v411-projection,.v411-reference,.v411-acceleration{margin:14px 0!important;min-width:0}.v411-values{border-collapse:collapse;width:100%;margin:12px 0;font-size:13px;table-layout:fixed}.v411-values th,.v411-values td{padding:10px 7px;border-bottom:1px solid #e1e7ed;text-align:right;overflow-wrap:anywhere;vertical-align:top}.v411-values th:first-child{text-align:left;width:24%}.v411-values td{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-values tbody tr:last-child{font-weight:700}.v411-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:8px 0;font-size:13px}.v411-pair span{min-width:0}.v411-pair b{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-note,.v411-warning,.v411-loading{font-size:13px;line-height:1.5;margin:10px 0;white-space:normal}.v411-warning{color:#875b18}.v411-loading,.v411-note{color:#536174}.v411-origin{margin:10px 0;font-size:12px;line-height:1.5;white-space:normal;overflow-wrap:anywhere}.v411-origin>summary{cursor:pointer;padding:9px 0;font-weight:600}.v411-origin p{margin:8px 0}.v411-component{padding:7px 0;border-top:1px solid #e1e7ed}.v411-component-origin,.v411-group-warning{grid-column:1/-1}.v411-award-values{display:flex;flex-direction:column;gap:3px}.v411-award-values>b{white-space:nowrap}.v411-award-values>span:nth-of-type(2){margin-top:7px}.v411-prior-reference{padding:0 8px}.v411-values th{font-weight:600}@media(max-width:600px){.v411-values{font-size:12px;display:block}.v411-values thead,.v411-values tbody{display:block}.v411-values tr{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);column-gap:8px}.v411-values th,.v411-values td{padding:8px 0;text-align:left}.v411-values th:first-child{width:auto;grid-column:1/-1;padding-bottom:1px;border-bottom:0}.v411-values thead th:first-child{display:none}.v411-values td{font-size:12px}.v411-pair{font-size:12px;gap:7px}.v411-projection h2,.v411-reference h2,.v411-acceleration h2{font-size:16px}.v411-origin>summary{min-height:24px}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    Object.assign(state, { after, refresh, load, invalidate }); window.__LTS_V411_RSU = state; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed || !w?.__LTS_V183_AWARD_PROVENANCE?.installed) return false;
      if (!w.__LTS_V411_RSU?.installed) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V411_RSU?.installed;
    } catch { return false; }
  }
  let generation = 0;
  function start() { const current = ++generation; let tries = 0; function attempt() { if (current !== generation) return; if (!install() && ++tries < 400) setTimeout(attempt, 100); } attempt(); }
  shell?.addEventListener('load', start); start(); window.LTSV339Boot?.watch('lts-v411-rsu-policy.js', install);
})();

;
/* lts-v412-projection-policy.js */
/* Projection amounts come from the owner-scoped server calculation. */
(function () {
  'use strict';
  function createAPI() {
    const invalid = () => { throw Error('Invalid projection response'); };
    const methods = new Set(['history_total_budget', 'fixed', 'salary_net', 'inflated_calendar', 'repeat_calendar']);
    function day(value) {
      if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\d$/.test(value)) return invalid();
      const date = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) return invalid();
      return value;
    }
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!['number', 'string'].includes(typeof value) || !/^\d+(?:\.\d{1,2})?$/.test(String(value))) return invalid();
      const [whole, fraction = ''] = String(value).split('.');
      const n = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (n > BigInt(Number.MAX_SAFE_INTEGER)) return invalid();
      return Number(n);
    }
    function windowDates(value) {
      if (!value) return invalid();
      const from = day(value.from), to = day(value.to);
      if (from > to) return invalid();
      return { from, to };
    }
    function annualTotals(row, asOf, horizon) {
      return row.annual_totals.map(year => {
        if (!Number.isInteger(year.year) || year.year < Number(asOf.slice(0, 4)) || year.year > Number(horizon.slice(0, 4))
          || typeof year.partial_year !== 'boolean') return invalid();
        return { year: year.year, total: cents(year.budget_total_brl, true),
          additional: cents(year.additional_brl, true), partial: year.partial_year };
      });
    }
    function approvedBudget(row, asOf, horizon) {
      if (row.method !== 'fixed' || row.direction !== 'expense' || typeof row.uses_history !== 'boolean'
        || row.reference_stale !== false || row.expected_months !== 12 || !Array.isArray(row.coverage)
        || typeof row.account !== 'string' || !row.account.trim()) return invalid();
      const amount = cents(row.reference_amount_brl);
      if (amount <= 0) return invalid();
      const historyWindow = row.reference_window === null ? null : windowDates(row.reference_window);
      let months = null;
      if (historyWindow) {
        const start = new Date(historyWindow.from + 'T12:00:00Z');
        const end = new Date(historyWindow.to + 'T12:00:00Z');
        const after = new Date(end);
        after.setUTCDate(after.getUTCDate() + 1);
        months = (after.getUTCFullYear() - start.getUTCFullYear()) * 12 + after.getUTCMonth() - start.getUTCMonth();
        if (start.getUTCDate() !== 1 || after.getUTCDate() !== 1 || months < 1 || historyWindow.to >= asOf
          || !Number.isInteger(row.coverage_months) || row.coverage_months < 0 || row.coverage_months > months) return invalid();
      } else if (row.coverage_months !== null || row.uses_history) return invalid();
      if (row.uses_history && row.coverage_months !== months) return invalid();
      let previousDate = asOf;
      for (const period of row.coverage) {
        const due = day(period.event_date);
        if (due <= previousDate || due > horizon || typeof period.trusted !== 'boolean') return invalid();
        previousDate = due;
        const known = cents(period.known_brl, true), additional = cents(period.additional_brl, true);
        const budget = cents(period.budget_total_brl);
        if (period.status === 'open_cycle_known_only') {
          if (row.account !== 'Bradesco' || !period.trusted || known === null || budget !== known || additional !== 0) return invalid();
          continue;
        }
        if (budget !== amount) return invalid();
        if (period.trusted ? known === null || additional !== Math.max(amount - known, 0)
          : known !== null || additional !== null || !row.warnings.includes('unreconciled_periods')) return invalid();
      }
      return { key: row.series_key, description: row.description, direction: row.direction, method: row.method,
        account: row.account, amount, rate: 0, historyWindow, referenceStale: false, templateYear: null,
        expected: months, covered: row.coverage_months, observed: null, spendingMonths: null, outliers: [],
        warnings: row.warnings.map(String), dueDayBasis: null, usesHistory: row.uses_history,
        approvedBudget: true, annual: annualTotals(row, asOf, horizon) };
    }
    function build(payload) {
      if (!payload || payload.version !== 'projection-policy-v412') return invalid();
      if (payload.enabled === false) return null;
      if (payload.enabled !== true || payload.schema_version !== 1 || !Array.isArray(payload.series)
        || !Array.isArray(payload.warnings) || payload.card_method !== 'total_budget_floor'
        || payload.outliers_excluded !== false || payload.missing_months_assumed_zero !== false
        || payload.financial_sources_modified !== false) return invalid();
      const asOf = day(payload.as_of), horizon = day(payload.horizon_end), nextReview = day(payload.next_review_on);
      if (horizon !== (Number(asOf.slice(0, 4)) + 5) + '-12-31' || nextReview <= asOf) return invalid();
      const historyWindow = windowDates(payload.history_window), keys = new Set();
      const series = payload.series.map(row => {
        if (!row || typeof row.series_key !== 'string' || !row.series_key.trim() || keys.has(row.series_key)
          || typeof row.description !== 'string' || !row.description.trim()
          || !Array.isArray(row.warnings) || !Array.isArray(row.annual_totals)) return invalid();
        keys.add(row.series_key);
        if (/^(?:owner|recurring)_[a-z][a-z0-9_]*$/.test(row.series_key) && Object.hasOwn(row, 'coverage')) {
          return approvedBudget(row, asOf, horizon);
        }
        const expected = row?.expected_months;
        const cardBudget = row?.method === 'history_total_budget' && /^card_/.test(row?.series_key || '');
        if (!methods.has(row.method)
          || !['income', 'expense'].includes(row.direction) || !(expected === 12 || expected === 3 && cardBudget)
          || !Number.isInteger(row.coverage_months) || row.coverage_months < 0 || row.coverage_months > expected
          || !Number.isInteger(row.observed_months) || row.observed_months < row.coverage_months || row.observed_months > expected
          || !Number.isInteger(row.months_with_spend) || row.months_with_spend < 0 || row.months_with_spend > row.observed_months
          || !Array.isArray(row.outlier_months) || !Array.isArray(row.warnings) || !Array.isArray(row.annual_totals)
          || typeof row.reference_stale !== 'boolean') return invalid();
        const rate = Number(row.annual_rate);
        if (!Number.isFinite(rate) || rate < 0 || rate > .25 || row.method !== 'inflated_calendar' && rate !== 0) return invalid();
        const referenceWindow = windowDates(row.reference_window), amount = cents(row.reference_amount_brl, true);
        let endsOn = null;
        if (row.ends_on !== undefined) {
          if (!cardBudget || row.direction !== 'expense') return invalid();
          endsOn = day(row.ends_on);
        }
        let provision = null;
        if (row.new_spend_provision !== undefined) {
          const value = row.new_spend_provision;
          if (!value || typeof value !== 'object' || Array.isArray(value)
            || !cardBudget || row.direction !== 'expense') return invalid();
          const startsOn = day(value.starts_on), provisionAmount = cents(value.amount_brl);
          if (!startsOn.endsWith('-01') || provisionAmount <= 0 || provisionAmount > 10000000000) return invalid();
          const leadMonths = value.lead_months === undefined ? null : value.lead_months;
          if (leadMonths !== null && (!Number.isInteger(leadMonths) || leadMonths < 0 || leadMonths > 12)) return invalid();
          provision = { startsOn, amount: provisionAmount, active: asOf >= startsOn,
            ...(leadMonths !== null ? { leadMonths, rolling: true } : {}) };
          if (provision.active && (row.uses_history !== false || amount !== provisionAmount)) return invalid();
        }
        if (expected === 3) {
          const start = new Date(referenceWindow.from + 'T12:00:00Z');
          const end = new Date(start); end.setUTCMonth(end.getUTCMonth() + expected); end.setUTCDate(end.getUTCDate() - 1);
          if (!referenceWindow.from.endsWith('-01') || end.toISOString().slice(0, 10) !== referenceWindow.to
            || referenceWindow.to >= asOf.slice(0, 7) + '-01') return invalid();
        }
        if (!provision?.active && !provision?.rolling && (row.method === 'history_total_budget' || row.uses_history === true) && amount !== null && row.coverage_months < expected && !row.reference_stale) return invalid();
        return { key: row.series_key, description: row.description, method: row.method, direction: row.direction,
          account: String(row.account || ''), amount, rate, historyWindow: referenceWindow, referenceStale: row.reference_stale,
          templateYear: Number.isInteger(row.template_year) ? row.template_year : null,
          expected, covered: row.coverage_months, observed: row.observed_months, spendingMonths: row.months_with_spend, outliers: row.outlier_months.map(day),
          warnings: row.warnings.map(String), dueDayBasis: row.due_day_basis || null,
          usesHistory: !provision?.active && !provision?.rolling && (row.uses_history === true || row.method === 'history_total_budget'),
          ...(provision ? { newSpendProvision: provision } : {}),
          ...(endsOn ? { endsOn } : {}),
          annual: annualTotals(row, asOf, horizon) };
      });
      return { asOf, horizon, nextReview, historyWindow, series, partialYear: payload.current_year_partial === true };
    }
    return { build, cents, day };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V412_PROJECTION?.installed) return;
    const api = factory(), previous = render, ui = window.__LTS_V168_STATE;
    const previousRange = loadFlowRange, previousRPC = S.rpc.bind(S);
    const state = { installed: true, status: 'idle', model: null, sequence: 0, readAt: 0, horizonKey: null, explicitRange: false, consumerSequence: 0 };
    let openingFullRange = false;
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity();
    const date = value => value.split('-').reverse().join('/');
    const money = value => value === null ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value / 100);
    const el = (tag, text, className) => { const node = document.createElement(tag); if (text != null) node.textContent = text; if (className) node.className = className; return node; };
    function reset() {
      if (owner === identity() && D && !N.classList.contains('hidden')) return false;
      owner = identity(); state.sequence++; state.consumerSequence++; state.status = 'idle'; state.model = null; state.readAt = 0; state.horizonKey = null; state.explicitRange = false;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      return true;
    }
    function fullRange(model = state.model) {
      if (!model) return null;
      const from = new Date(model.asOf + 'T12:00:00Z'); from.setUTCDate(from.getUTCDate() - 5);
      return { from: from.toISOString().slice(0, 10), to: model.horizon,
        previousEnd: (Number(model.asOf.slice(0, 4)) + 4) + '-12-31' };
    }
    // Only the old automatic defaults are extended. Explicit user periods keep
    // the exact dates requested by the existing navigation and editor handlers.
    loadFlowRange = function (from, to) {
      const range = fullRange();
      if (window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action && !openingFullRange) state.explicitRange = true;
      if (range && from === range.from && to === range.previousEnd
        && !state.explicitRange && !window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action) to = range.to;
      return previousRange.call(this, from, to);
    };
    S.rpc = function (name, args, ...rest) {
      const range = fullRange();
      if (range && args) {
        if (/^lts_browser_flow_v\d+$/.test(name) && V === 'Dashboard'
          && args.p_from === state.model.asOf && args.p_to === range.previousEnd) args = { ...args, p_to: range.to };
        if (/^lts_browser_recurring_future_gap_audit_v\d+$/.test(name)
          && args.p_as_of === state.model.asOf && args.p_horizon_end === range.previousEnd) args = { ...args, p_horizon_end: range.to };
      }
      return previousRPC(name, args, ...rest);
    };
    function openFullRange() {
      const range = fullRange(); if (!range) return;
      const layout = window.__LTS_V382_FLOW_LAYOUT, prior = layout?.explicit_period_action;
      state.explicitRange = false; openingFullRange = true;
      if (layout) layout.explicit_period_action = true;
      try { return loadFlowRange(range.from, range.to); }
      finally { openingFullRange = false; if (layout) layout.explicit_period_action = prior; }
    }
    async function refreshConsumers() {
      const model = state.model, generation = owner, token = ++state.consumerSequence;
      if (!model) return;
      const stillCurrent = () => generation === identity() && token === state.consumerSequence && state.model?.horizon === model.horizon;
      if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.loading = false; }
      const forecast = Promise.resolve(window.__LTS_V178_REVIEW?.refreshForecast?.()).catch(() => {});
      try {
        const response = await S.rpc('lts_browser_recurring_future_gap_audit_v5', { p_as_of: model.asOf, p_horizon_end: model.horizon });
        if (!stillCurrent()) return;
        if (response.error || !Array.isArray(response.data?.horizon_checks)) throw Error();
        if (ui?.updates) { ui.updates.recurring = response.data; ui.updates.error = null; }
        if (ui?.dashboard) { ui.dashboard.data ||= {}; ui.dashboard.data.recurring = response.data; }
      } catch { if (stillCurrent() && ui?.updates) ui.updates.error = 'Não foi possível atualizar as revisões. Tente novamente.'; }
      finally { await forecast; if (stillCurrent()) render(); }
    }
    function applyHorizon() {
      const range = fullRange(); if (!range) return;
      if (state.horizonKey !== range.to) {
        // The initial dashboard already requests the scenario's five-year
        // horizon. Loading the matching policy must not restart those readers.
        // A longer horizon, a later change and explicit refresh still recheck
        // every consumer through the existing guarded paths.
        const alignedOpening = state.horizonKey === null
          && window.parent.LTSV421Scenario?.horizon?.(state.model.asOf, null) === range.to;
        state.horizonKey = range.to;
        if (!alignedOpening) {
          if (ui?.dashboard) { ui.dashboard.token = (ui.dashboard.token || 0) + 1; ui.dashboard.started = false; ui.dashboard.loading = false; }
          queueMicrotask(() => { if (state.model?.horizon === range.to) refreshConsumers(); });
        }
      }
      if (V !== 'Fluxo Diário') return;
      for (const id of ['flowDefaultRange', 'goToday']) {
        const button = document.getElementById(id); if (!button) continue;
        if (id === 'flowDefaultRange') { button.textContent = '5 anteriores + fim de ' + range.to.slice(0, 4);
          button.title = 'Cinco dias anteriores e cinco anos futuros completos'; }
        button.onclick = openFullRange;
      }
      const year = document.getElementById('flowYear'), end = document.getElementById('flowTo');
      if (year && ![...year.options].some(option => option.value === range.to.slice(0, 4)))
        year.append(new Option(range.to.slice(0, 4), range.to.slice(0, 4)));
      if (end) end.max = range.to;
      if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING)
        queueMicrotask(() => { if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING) openFullRange(); });
    }
    function message(text) { const node = el('p', text, 'v412-warning'); node.setAttribute('role', 'status'); return node; }
    function warningTexts(model) {
      const texts = [];
      for (const row of model.series) {
        if (row.referenceStale) texts.push(row.description + ': usando a última média completa.');
        else if (row.warnings.includes('history_unavailable') || row.warnings.includes('partial_history')) texts.push(row.description + ': histórico incompleto.');
        if (row.warnings.includes('unreconciled_periods') || row.warnings.includes('calendar_unavailable')) texts.push(row.description + ': há previsões a conferir.');
      }
      return texts;
    }
    function provisionText(row) {
      const provision = row.newSpendProvision;
      if (provision.rolling) return 'Novos gastos: ' + money(provision.amount) + '/mês desde o ' + provision.leadMonths + 'º mês à frente, além das parcelas conhecidas. Neste cálculo: a partir de ' + date(provision.startsOn) + '.';
      return 'Novos gastos: ' + money(provision.amount) + '/mês a partir de ' + date(provision.startsOn) + ', além das parcelas.';
    }
    function methodText(row) {
      if (row.approvedBudget) return (row.usesHistory ? 'Média de ' + row.expected + ' meses.' : 'Valor mensal definido.')
        + ' Os gastos já previstos abatem a provisão do mês.';
      if (row.newSpendProvision?.active || row.newSpendProvision?.rolling) return provisionText(row);
      if (row.method === 'history_total_budget') return 'Média de ' + row.expected + ' meses completos' + (row.expected === 3 ? ', atualizada com as novas faturas.' : '.');
      if (row.method === 'inflated_calendar') return 'Reajuste estimado de ' + new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 2 }).format(row.rate) + ' ao ano. Cobranças confirmadas têm prioridade.';
      if (row.method === 'salary_net') return 'Salário previsto após o desconto do empréstimo em folha.';
      if (row.method === 'repeat_calendar') return 'Calendário e valores mantidos, sem aumento automático.';
      return 'Valor mantido, sem aumento automático.';
    }
    function origin(model) {
      const details = el('details', null, 'v412-origin'); details.append(el('summary', 'Premissas das projeções'));
      details.append(el('p', 'Planejamento até ' + date(model.horizon) + ', com extensão anual.'));
      warningTexts(model).forEach(text => details.append(message(text)));
      if (model.partialYear) details.append(el('p', 'O ano corrente considera somente as datas futuras; sua soma é parcial.'));
      for (const row of model.series) {
        const section = el('section', null, 'v412-rule'); section.append(el('h3', row.description));
        if (row.amount !== null && !row.newSpendProvision?.active && !row.newSpendProvision?.rolling) section.append(el('strong', money(row.amount) + (row.method === 'history_total_budget' ? ' · referência mensal' : ' · base nominal')));
        section.append(el('p', methodText(row)));
        if (row.newSpendProvision && !row.newSpendProvision.active && !row.newSpendProvision.rolling) section.append(el('p', provisionText(row)));
        if (row.endsOn) section.append(el('p', 'Projeção de novos gastos até ' + date(row.endsOn) + '; parcelas já existentes continuam.'));
        if (row.templateYear !== null) section.append(el('p', 'Calendário de referência: ' + row.templateYear + '.'));
        if (row.usesHistory) {
          section.append(el('p', 'Janela da média: ' + date(row.historyWindow.from) + ' a ' + date(row.historyWindow.to) + '.'));
          if (row.referenceStale) section.append(el('p', 'Revisão atual com ' + row.covered + ' de ' + row.expected + ' meses cobertos. A última base completa continua em uso.'));
          else if (row.spendingMonths !== null) section.append(el('p', row.covered + ' de ' + row.expected + ' meses cobertos; ' + row.spendingMonths + ' meses com gasto.'));
          if (row.outliers.length) section.append(el('p', 'Valores atípicos foram mantidos na média. Meses: ' + row.outliers.map(x => x.slice(5, 7) + '/' + x.slice(0, 4)).join(', ') + '.'));
        }
        if (String(row.dueDayBasis || '').startsWith('history_modal_day')) section.append(el('p', 'Dia de planejamento estimado pela data mais frequente do histórico; uma data documentada tem prioridade.'));
        details.append(section);
      }
      details.append(el('p', 'Faturas fechadas prevalecem. Parcelas antigas de gastos não recorrentes continuam até terminar; as reservas de novas compras não são somadas duas vezes.'));
      return details;
    }
    function panel(compact) {
      const card = el('article', null, 'v412-policy' + (compact ? ' v412-compact' : ' v168-card'));
      card.dataset.v412Policy = compact ? 'flow' : 'updates';
      const header = el('div', null, 'v412-heading');
      header.append(el(compact ? 'strong' : 'h2', state.model ? 'Projeções até ' + date(state.model.horizon) : 'Projeções futuras'));
      const button = el('button', state.status === 'queued' ? 'Atualização em andamento…' : state.status === 'refreshing' ? 'Solicitando…' : 'Atualizar projeções', 'v168-btn');
      button.type = 'button'; button.dataset.v412Refresh = ''; button.disabled = ['loading', 'refreshing', 'queued'].includes(state.status); button.onclick = () => refresh(); header.append(button); card.append(header);
      if (state.status === 'error') card.append(message('Não foi possível conferir as projeções. Atualize antes de usar as estimativas.'));
      else if (!state.model) card.append(el('p', 'Conferindo as projeções…', 'v412-loading'));
      else { const warnings = warningTexts(state.model); if (warnings.length) card.append(message('Há estimativas a conferir nas premissas.')); card.append(origin(state.model)); }
      return card;
    }
    function patchDialog() {
      const dialog = document.getElementById('v366RecurringDialog'); if (!dialog) return;
      const horizon = state.model?.horizon || (Number(new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric' }).format(new Date())) + 5) + '-12-31';
      for (const node of dialog.querySelectorAll('.v366-policy')) {
        if (node.textContent.startsWith('A continuidade cobre')) {
          const next = node.textContent.replace(/até o fim de \d{4}/, 'até ' + date(horizon));
          if (next !== node.textContent) node.textContent = next;
        }
      }
    }
    function paint() {
      reset(); if (!D || N.classList.contains('hidden')) return;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      if (state.status !== 'disabled') {
        if (V === 'Fluxo Diário') { const parent = document.querySelector('.flow-sticky-controls'); if (parent) parent.after(panel(true)); }
        if (V === 'Atualizações') { const parent = document.querySelector('.v168-updates'); if (parent) parent.prepend(panel(false)); }
        if (V === 'Dashboard' && state.status === 'error') {
          const parent = document.querySelector('.v168-dashboard');
          if (parent) { const warning = panel(false); warning.dataset.v412Policy = 'dashboard-warning'; parent.prepend(warning); }
        }
      }
      applyHorizon();
      patchDialog();
      if (['Dashboard', 'Fluxo Diário', 'Atualizações'].includes(V)) queueMicrotask(() => load());
    }
    async function load(force = false, recalculate = false) {
      reset(); if (!D || N.classList.contains('hidden') || ['loading', 'refreshing', 'queued'].includes(state.status)
        || !force && Date.now() - state.readAt < 300000) return;
      const generation = owner, token = ++state.sequence;
      state.status = recalculate ? 'refreshing' : 'loading';
      if (recalculate) render();
      try {
        const response = await S.rpc(recalculate ? 'lts_browser_projection_refresh_v412' : 'lts_browser_projection_policy_v412', {});
        if (response.error) throw Error();
        if (generation !== identity() || token !== state.sequence) return;
        if (recalculate && response.data?.refresh && window.__LTS_V415_REFRESH) {
          window.__LTS_V415_REFRESH.observeRefresh(response.data.refresh);
          if (!window.LTSV415ProductRefresh.ready(response.data.refresh)) {
            state.status = 'queued'; state.readAt = Date.now();
            if (response.data.version === 'projection-policy-v412') state.model = api.build(response.data);
            if (typeof toast === 'function') toast('Atualização solicitada.');
            return;
          }
        }
        const model = api.build(response.data);
        if (generation !== identity() || token !== state.sequence) return;
        const wasEnabled = !!state.model;
        state.model = model; state.status = model ? (recalculate ? 'refreshing' : 'ready') : 'disabled'; state.readAt = Date.now();
        if (model) applyHorizon();
        if (!model && wasEnabled) {
          state.consumerSequence++; state.horizonKey = null;
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.recurring = null; ui.updates.loading = false; }
          if (ui?.dashboard?.data) delete ui.dashboard.data.recurring;
          await window.__LTS_V178_REVIEW?.refreshForecast?.();
          if (V === 'Fluxo Diário' && FLOWQ?.from && FLOWQ?.to) await loadFlowRange(FLOWQ.from, FLOWQ.to);
        }
        if (recalculate && model) {
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          await refreshConsumers();
          if (V === 'Fluxo Diário' && typeof loadFlowRange === 'function') {
            const from = FLOWQ?.from, to = FLOWQ?.to;
            if (from && to) await loadFlowRange(from, to);
          }
        }
      } catch {
        if (generation === identity() && token === state.sequence) { state.model = null; state.status = 'error'; state.readAt = Date.now(); }
      } finally { if (generation === identity() && token === state.sequence) {
        if (state.status === 'refreshing') state.status = state.model ? 'ready' : 'disabled';
        render();
      } }
    }
    async function refresh() { return load(true, true); }
    const style = document.createElement('style'); style.textContent = '.v412-policy{box-sizing:border-box;margin:10px 0;padding:12px 14px;border:1px solid #dbe3eb;border-radius:12px;background:#fff;color:#20364b;max-width:100%}.v412-heading{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}.v412-heading h2{font-size:18px;margin:0}.v412-heading>strong{font-size:14px}.v412-heading button{min-height:40px}.v412-origin{font-size:12px;line-height:1.45;margin-top:7px}.v412-origin>summary{cursor:pointer;color:#52677a}.v412-origin p{margin:7px 0}.v412-rule{padding:10px 0;border-bottom:1px solid #e4eaf0}.v412-rule h3{font-size:13px;margin:0 0 5px}.v412-rule strong{white-space:nowrap}.v412-warning{color:#79500a;background:#fff7e5;padding:8px;border-radius:8px;font-size:12px;line-height:1.45;margin:8px 0}.v412-loading{font-size:12px;margin:7px 0}@media(max-width:400px){.v412-policy{padding:10px}.v412-heading{gap:7px}.v412-heading button{font-size:12px}}'; document.head.append(style);
    render = function () { const result = previous.apply(this, arguments); paint(); return result; };
    Object.assign(state, { load, refresh }); window.__LTS_V412_PROJECTION = state;
    window.addEventListener('lts:product-refresh-ready', () => {
      reset(); if (!D || N.classList.contains('hidden')) return;
      state.status = 'idle'; state.readAt = 0;
      load(true, false).then(() => { if (state.model && state.status === 'ready') refreshConsumers(); });
    });
    const observer = new MutationObserver(patchDialog); observer.observe(document.body, { childList: true, subtree: true });
    paint();
  }
  function install() {
    try { const w = shell?.contentWindow, d = shell?.contentDocument; if (!w?.__LTS_V411_RSU) return false;
      if (!w.__LTS_V412_PROJECTION) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V412_PROJECTION;
    } catch { return false; }
  }
  let attempts = 0; function start() { if (!install() && ++attempts < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { attempts = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v412-projection-policy.js', install);
})();


;
/* lts-v417-clean-reports.js */
/* Shorten only known process notices. Preserve failures, controls and financial content. */
(function () {
  'use strict';
  function clean(doc) {
    for (const p of doc.querySelectorAll('.v168-note.warn')) {
      const b=p.querySelector('[data-v333-actions-refresh]');
      if (!b || !p.textContent.startsWith('Não foi possível atualizar todas as ações.')) continue;
      for (const n of [...p.childNodes]) if (n.nodeType===3 && n.textContent.includes('Não foi possível atualizar todas as ações.')) n.textContent=n.textContent.replace('Não foi possível atualizar todas as ações.', 'Não foi possível atualizar as pendências.');
      b.textContent='Tentar novamente';
    }
    for (const span of doc.querySelectorAll('.v168-loadstatus span')) {
      const text=span.textContent;
      if (/^Resumo já disponível\.\s*Atualizando os detalhes sem apagar os valores exibidos…$/.test(text)) span.textContent='Atualizando…';
      if (/^Resumo preservado\.\s*\d+ leitura\(s\) não atualizaram; nenhuma informação anterior foi apagada\.$/.test(text)) span.textContent='Alguns dados não atualizaram.';
    }
  }
  if (typeof module!=='undefined' && module.exports) { module.exports={clean}; return; }
  const shell=document.getElementById('shell');
  function install() {
    try {
      const doc=shell?.contentDocument, win=shell?.contentWindow;
      if (!doc?.body || win.__LTS_V417_CLEAN_REPORTS?.body===doc.body) return;
      win.__LTS_V417_CLEAN_REPORTS?.observer?.disconnect();
      let queued=false;
      const update=()=>{queued=false;clean(doc);};
      const observer=new MutationObserver(()=>{if(!queued){queued=true;win.requestAnimationFrame(update);}});
      observer.observe(doc.body,{subtree:true,childList:true});
      win.__LTS_V417_CLEAN_REPORTS={installed:true,body:doc.body,observer,clean:()=>clean(doc)};
      update();
    } catch (_) { /* A navigation is retried at its load event. */ }
  }
  shell?.addEventListener('load',install); install();
})();

;
/* lts-v423-clarity.js */
/* Disclose pending bank evidence on demand; never insert a cash movement. */
(function(){'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){'use strict';
  if(window.__LTS_V423_CLARITY)return;
  const M=parent.LTSV423Clarity;let memo=null,flight=null,ticket=0,product=D,identity=BOOT?.generation;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n),date=d=>String(d||'').split('-').reverse().join('/');
  const oldTitle=flowSemanticTitle,oldMeta=flowSemanticMeta;
  flowSemanticTitle=function(e){return M.cardLabel(e)?.title||oldTitle(e)};
  flowSemanticMeta=function(e){return M.cardLabel(e)?.note||oldMeta(e)};
  const style=document.createElement('style');style.textContent='.v423-subgroups{padding:12px 16px;border-bottom:1px solid #dbe3ec}.v423-subgroups h3{margin:0 0 9px;font-size:15px}.v423-group-list{display:grid;gap:7px;max-height:220px;overflow:auto}.v423-group-list button{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left;background:#f6f8fa;border:1px solid #dbe3ec;border-radius:9px;padding:10px 12px;min-height:44px;color:inherit}.v423-group-list button[aria-pressed=true]{border-color:#2563eb;background:#eef5ff}.v423-group-list span{min-width:0;overflow-wrap:anywhere}.v423-group-list strong{white-space:nowrap}.v423-group-list small{display:block;font-size:12px;color:#64748b;margin-top:4px}.v423-bank-evidence .v365-pair small{display:block}.v423-bank-evidence p{font-size:13px;margin:9px 0}.v423-bank-evidence details{font-size:12px}.v423-bank-evidence h3{font-size:15px}.v423-bank-evidence .v365-pair{gap:12px}.v423-bank-evidence .v365-pair span{min-width:0;overflow-wrap:anywhere}';document.head.appendChild(style);
  function clear(){ticket++;memo=null;flight=null;}
  const status=window.__LTS_V423_CLARITY={installed:true,financialWrites:0,clear};
  function renderEvidence(day,root){
   if(!memo)return;
   for(const bank of ['Itaú','Bradesco','C6']){
    if(ACC!=='Consolidado'&&ACC!==bank)continue;
    const b=M.bridge(day,memo,bank);if(!b)continue;
    const old=[...root.querySelectorAll('.v365-bridge')].find(x=>x.querySelector('h3')?.textContent.startsWith(bank+' ·'));
    if(!old)continue;
    old.classList.add('v423-bank-evidence');old.dataset.v423='pending';
    const line=(label,value,when='')=>'<div class="v365-pair"><span>'+esc(label)+(when?'<small>'+esc(when)+'</small>':'')+'</span><b>'+money(value)+'</b></div>';
    old.innerHTML='<h3>'+esc(bank)+' · movimentos em confirmação</h3>'+line('Saldo calculado antes da conciliação',b.opening)+b.movements.map(m=>line(m.description,m.amount,date(m.date))).join('')+line('Saldo informado pelo banco',b.observed)+'<p>Os valores explicam a diferença. A confirmação dos lançamentos pelo banco ainda está pendente.</p><details><summary>Origem</summary><p>Posição bancária de '+esc(date(b.sourceDate))+'. Estes movimentos ainda não foram marcados como liquidados.</p></details>';
    const row=document.getElementById('d-'+day.date);const note=row?.querySelector('.v365-balance-status');if(note)note.textContent='Movimentos em confirmação';
   }
  }
  function update(){
   if(product!==D||identity!==BOOT?.generation){product=D;identity=BOOT?.generation;clear();}
   document.querySelectorAll('.v365-bridge,.v423-bank-evidence').forEach(node=>node.remove());
  }
  const previous=render;render=function(...args){const value=previous.apply(this,args);update();return value;};
  for(const name of ['signOut','signInWithPassword']){const prior=S.auth[name];if(typeof prior==='function')S.auth[name]=function(...a){clear();return prior.apply(this,a)};}
  update();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V365?.installed||!w.__LTS_V178_REVIEW?.installed)return false;if(!w.__LTS_V423_CLARITY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V423_CLARITY;}catch{return false}}
 function burst(){const k=++generation;let n=0;function step(){if(k!==generation)return;if(!install()&&++n<320)setTimeout(step,100)}step();}
 outer?.addEventListener('load',burst);burst();
})();

;
/* lts-v425-flow-options.js */
/* Presentation only. Existing readers, amounts, controls and handlers are unchanged. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V425_FLOW_OPTIONS)return;
  const previous=render;let lastView=null,queued=false;
  function materialReasons(){
   const reasons=[],p=window.__LTS_V412_PROJECTION,r=window.__LTS_V411_RSU;
   if(p?.status==='error')reasons.push('Não foi possível atualizar a previsão.');
   else if(p?.model?.series?.some(s=>s.amount===null&&s.usesHistory||s.warnings?.some(w=>['unreconciled_periods','calendar_unavailable'].includes(w))))reasons.push('Há previsões incompletas.');
   if(r?.status==='error')reasons.push('Líquido das ações a conferir.');
   return reasons;
  }
  function paint(){
   queued=false;
   const entering=lastView!=='Fluxo Diário';lastView=V;
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden'))return;
   const tools=document.querySelector('.v382-tools'),body=tools?.querySelector('.v382-tool-body'),controls=document.querySelector('.flow-sticky-controls');
   if(!body||!controls)return;
   tools.classList.add('v425-options');body.classList.add('v425-options-body');
   if(entering)tools.open=false;
   const summary=tools.querySelector(':scope>summary');summary.setAttribute('aria-label','Opções do Fluxo');
   function move(node,key){
    if(!node)return;
    const existing=body.querySelector('[data-v425-section="'+key+'"]');
    if(existing&&existing!==node)existing.remove();
    node.dataset.v425Section=key;
    if(node.parentElement!==body){if(node.tagName==='DETAILS')node.open=false;body.appendChild(node);}
   }
   move(controls.querySelector('.v225-balance-freshness>.lts-update-details'),'sources');
   move(document.querySelector('[data-v412-policy="flow"]'),'projection');
   move(document.querySelector('[data-v411-flow-policy]'),'rsu');
   move(document.getElementById('v402-d01-origin'),'applications');
   // Empty provenance containers occupy no vertical space. Their material
   // freshness warnings remain outside the options, with original semantics.
   for(const host of controls.querySelectorAll('.v225-balance-freshness'))host.classList.toggle('v425-empty',!host.textContent.trim());
   const reasons=materialReasons(),signature=reasons.join(' ');let notice=document.getElementById('v425-flow-attention');
   if(!signature){notice?.remove();return;}
   if(!notice){notice=document.createElement('div');notice.id='v425-flow-attention';notice.setAttribute('role','status');controls.after(notice);}
   if(notice.dataset.message!==signature){
    notice.dataset.message=signature;const text=document.createElement('span');text.textContent=signature;
    const button=document.createElement('button');button.type='button';button.textContent='Revisar';
    button.onclick=()=>{const t=document.querySelector('.v382-tools');if(!t)return;t.open=true;const target=t.querySelector('.v412-origin');if(target)target.open=true;t.querySelector(':scope>summary')?.focus();};
    notice.replaceChildren(text,button);
   }
  }
  function schedule(){if(!queued){queued=true;queueMicrotask(paint);}}
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  const observer=new MutationObserver(schedule);observer.observe(document.body,{subtree:true,childList:true});
  document.addEventListener('keydown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(event.key==='Escape'&&tools?.open){tools.open=false;tools.querySelector(':scope>summary')?.focus();event.preventDefault();}});
  document.addEventListener('pointerdown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(tools?.open&&!tools.contains(event.target))tools.open=false;});
  const style=document.createElement('style');style.textContent=`
   .v425-options>.v382-tool-body{width:380px;max-width:calc(100vw - 28px);max-height:65vh;max-height:65dvh;overflow:auto;overscroll-behavior:contain;box-sizing:border-box;text-align:left}
   .v425-options-body>[data-v425-section]{border:0!important;border-top:1px solid #e2e8f0!important;border-radius:0!important;margin:10px 0 0!important;padding:10px 0 0!important;min-width:0;max-width:100%;box-sizing:border-box}
   .v425-options-body>details>summary,.v425-options-body .v412-origin>summary{min-height:44px;display:flex;align-items:center;cursor:pointer;font-size:14px;line-height:1.4}
   .v425-options-body .v412-heading>strong{display:none}
   .v425-options-body .v412-heading{display:block}
   .v425-options-body .v412-heading button{width:100%;min-height:44px}
   .v425-options-body .v412-origin{margin-top:0}
   .v425-options-body p{overflow-wrap:anywhere}
   .v425-options-body .v225-freshness-bank{min-width:0}
   .flow-sticky-controls .v425-empty{display:none!important}
   #v425-flow-attention{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:8px 0;padding:8px 12px;border:1px solid #e7ce95;border-radius:10px;background:#fff8e8;color:#76500d;font-size:13px;line-height:1.4}
   #v425-flow-attention button{min-height:44px;flex:none;padding:8px 12px;border:1px solid #c9d5e2;border-radius:8px;background:#fff;color:#18344f;font-weight:600;cursor:pointer}
   @media(max-width:380px){.v425-options>.v382-tool-body{max-width:calc(100vw - 24px)}#v425-flow-attention{flex-wrap:wrap}}
  `;document.head.appendChild(style);
  window.__LTS_V425_FLOW_OPTIONS={installed:true,presentation_only:true,paint,materialReasons};paint();
 }
 function install(){try{
  const w=shell?.contentWindow,d=shell?.contentDocument;
  if(!w?.__LTS_V382_FLOW_LAYOUT||!w?.__LTS_V412_PROJECTION||!w?.__LTS_V402_D01)return false;
  if(w.__LTS_V425_FLOW_OPTIONS)return true;
  const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);return !!w.__LTS_V425_FLOW_OPTIONS;
 }catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100)}
 shell?.addEventListener('load',()=>{tries=0;start()});start();window.LTSV339Boot?.watch('lts-v425-flow-options.js',install);
})();

;
/* lts-v441-budget-model.js */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV441Budget=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const cents=v=>typeof v!=='number'&&!(typeof v==='string'&&/^[+-]?\d+(\.\d+)?$/.test(v))?null:Number.isFinite(Number(v))&&Number.isSafeInteger(Math.round(Number(v)*100))?Math.round(Number(v)*100):null;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0);
 const nullable=(v,positive=false)=>{const n=cents(v);if(v!==null&&(n===null||positive&&n<0))throw Error('invalid amount');return n;};
 function build(p){
  if(!p||p.ok!==true||p.version!=='budget-v441'||!Number.isInteger(p.year)||!/^\d{4}-\d{2}-\d{2}$/.test(p.as_of||'')
   ||!Number.isSafeInteger(p.plan_revision)||p.plan_revision<0||p.flow_provision_included!==false||p.basis!=='canonical_consumption_not_card_payment'
   ||!Array.isArray(p.rows)||!Array.isArray(p.months)||p.months.length!==12||!p.reference)throw Error('budget unavailable');
  const keys=Array.from({length:12},(_,i)=>p.year+'-'+String(i+1).padStart(2,'0')),seen=new Set();
  const rows=p.rows.map(r=>{
   if(typeof r.category!=='string'||!r.category.trim()||r.category.length>120||seen.has(r.category)||!Array.isArray(r.months)||r.months.length!==12)throw Error('invalid category');
   seen.add(r.category);
   return {category:r.category,reference:nullable(r.reference_monthly,true),months:r.months.map((m,i)=>{
    if(m.month!==keys[i]||!['owner','history','proposal'].includes(m.target_basis))throw Error('invalid month');
    return {month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),basis:m.target_basis,strategy:m.strategy||null};
   })};
  });
  const months=p.months.map((m,i)=>{
   if(m.month!==keys[i]||typeof m.started!=='boolean'||typeof m.complete!=='boolean')throw Error('invalid month');
   const v={month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),incomeTarget:nullable(m.income_target,true),
    incomeRegular:nullable(m.income_regular),extra:nullable(m.income_extraordinary),bonus:nullable(m.income_bonus??0),thirteenth:nullable(m.income_thirteenth??0),started:m.started,complete:m.complete};
   if(sum(rows.map(r=>r.months[i].actual))!==v.actual||sum(rows.map(r=>r.months[i].pending))!==v.pending||(rows.length?sum(rows.map(r=>r.months[i].target)):null)!==v.target)throw Error('totals mismatch');
   return v;
  });
  return {year:p.year,asOf:p.as_of,revision:p.plan_revision,proposed:p.proposed===true,rows,months,
   reference:{from:p.reference.from,to:p.reference.to,months:p.reference.months,expected:p.reference.expected_months,salaryMonths:p.reference.salary_months,salaryMonthly:nullable(p.reference.salary_monthly,true)},
   strategy:p.strategy||null,unknown:nullable(p.unclassified_actual),incomeGroups:p.actual_income_groups||[]};
 }
 function view(m,mode,month){
  const indices=mode==='year'?m.months.map((_,i)=>i):[Number(month.slice(5,7))-1];
  if(indices.some(i=>i<0||i>11)||month.slice(0,4)!==String(m.year))throw Error('invalid period');
  const cashUnallocated=(m.strategy?.cash_without_competence||[]).filter(x=>indices.some(i=>String(x.date).slice(0,7)===m.months[i].month)),cashWithoutCompetence=sum(cashUnallocated.map(x=>cents(x.amount)));
  const selected=indices.map(i=>m.months[i]),target=cashUnallocated.length?null:sum(selected.map(x=>x.target)),actual=sum(selected.map(x=>x.actual)),incomeTarget=sum(selected.map(x=>x.incomeTarget)),incomeRegular=sum(selected.map(x=>x.incomeRegular)),extra=sum(selected.map(x=>x.extra));
  const defined=m.rows.flatMap(r=>indices.map(i=>r.months[i].target)).filter(x=>x!==null),proposedSubtotal=defined.length?sum(defined):null;
  return {proposedSubtotal,proposedDeficit:proposedSubtotal!==null&&incomeTarget!==null?Math.max(0,proposedSubtotal-incomeTarget):null,unplannedCategories:m.rows.filter(r=>indices.some(i=>r.months[i].target===null)).length,cashUnallocated,cashWithoutCompetence,cashCoverageGap:cashUnallocated.length&&incomeTarget!==null?Math.max(0,cashWithoutCompetence-incomeTarget):null,hasIncompletePlan:cashUnallocated.length>0||selected.some(x=>x.target===null),target,actual,incomeTarget,incomeRegular,extra,bonus:sum(selected.map(x=>x.bonus)),thirteenth:sum(selected.map(x=>x.thirteenth)),minimum:sum(m.rows.map(r=>sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))))),pending:sum(selected.map(x=>x.pending)),
   plannedBalance:target===null||incomeTarget===null?null:incomeTarget-target,
   operating:incomeRegular===null||actual===null?null:incomeRegular-actual,
   afterExtras:incomeRegular===null||actual===null||extra===null?null:incomeRegular+extra-actual,
   started:selected.some(x=>x.started),complete:selected.every(x=>x.complete),
   rows:m.rows.map(r=>({category:r.category,reference:r.reference,target:sum(indices.map(i=>r.months[i].target)),actual:sum(indices.map(i=>r.months[i].actual)),
    gap:sum(indices.map(i=>r.months[i].target))===null?null:sum(indices.map(i=>r.months[i].target))-sum(indices.map(i=>r.months[i].actual)),
    type:r.months[indices[0]].strategy?.type||'unreviewed',reason:r.months[indices[0]].strategy?.reason||'',minimum:sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))),details:indices.flatMap(i=>r.months[i].strategy?.details||[]),needsReview:indices.some(i=>r.months[i].strategy?.needsReview===true),suggested:indices.some(i=>r.months[i].basis==='history'||r.months[i].basis==='proposal')}))};
 }
 function flow(p,asOf){
  const days=p?.current_future?.days;if(!Array.isArray(days))return null;
  const vals=days.filter(d=>/^\d{4}-\d{2}-\d{2}$/.test(d.date)&&d.date>=asOf).sort((a,b)=>a.date.localeCompare(b.date));
  if(!vals.length)return null;
  const extract=d=>({date:d.date,bank:cents(d.fix86_columns?.saldo_final??d.Consolidado?.bank_balance),liquid:cents(d.fix86_columns?.saldo_apos_d0_1),shares:cents(d.fix86_columns?.saldo_apos_rsu),restricted:cents(d.fix86_columns?.saldo_apos_fgts)});
  const rows=vals.map(extract),limit=new Date(asOf+'T12:00:00Z');limit.setUTCDate(limit.getUTCDate()+90);const end=limit.toISOString().slice(0,10),short=rows.filter(x=>x.date<=end);
  const first=key=>{if(!short.length||short.some(x=>x[key]===null))return {known:false,date:null,amount:null};const r=short.find(x=>x[key]<0);return {known:true,date:r?.date||null,amount:r?.[key]??null};};
  return {asOf,through:short.at(-1)?.date||null,today:rows.find(x=>x.date===asOf)||null,bank:first('bank'),liquid:first('liquid'),shares:first('shares'),restricted:first('restricted')};
 }
 return Object.freeze({build,view,flow,cents,sum});
});

;
/* lts-v442-strategy.js */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV442Strategy=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
 const cents=x=>x===null||x===undefined||!Number.isFinite(Number(x))?null:Math.round(Number(x)*100),money=x=>x===null?null:x/100;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0),round=x=>Math.ceil(x/1000)*1000;
 function kind(category){const c=norm(category);
  if(/financiamento|emprestimo|compromissos financeiros|condominio|seguro|assinatura|anuidade|armazenamento|spotify|google/.test(c))return'fixed';
  if(/ipva|iptu|impostos|tributos|licenciamento|viagen|passagem|hotel|duty free|batizado|casamento|eventos|documentos/.test(c))return'seasonal';
  if(/brinquedo|presente|vestuario|restaurante|ifood|rappi|bebida|cabele|cabeler|passeio|lazer|mercado livre|amazon|apple|moveis|decoracao|doacao/.test(c))return'discretionary';
  if(/saude|farmacia|educacao|aulas|mercado$|alimentacao|energia|enel|combustivel|rafiki|moradia|familia|benjamin/.test(c))return'essential';
  return'unreviewed';
 }
 function derive(input,flow,cards){
  if(!input||input.ok!==true||!Array.isArray(input.rows)||!Array.isArray(input.months)||input.months.length!==12)throw Error('budget unavailable');
  const p=structuredClone(input),asOf=p.as_of,current=asOf.slice(0,7),year=p.year,events=flow?.flow?.current_future?.events??flow?.current_future?.events;
  const cf=flow?.flow?.current_future??flow?.current_future,cardRows=cards?.cards;if(!Array.isArray(events)||!Array.isArray(cardRows)||cards.complete===false||!p.income_approvals||!p.category_aliases||Array.isArray(p.category_aliases)||typeof p.category_aliases!=='object')throw Error('commitments or approval metadata unavailable');
  if(year>=Number(asOf.slice(0,4))&&(flow.complete===false||cf.complete===false||!cf.from||cf.from>asOf||!cf.to||cf.to<year+'-12-31'))throw Error('commitment horizon incomplete');
  const amounts=new Map(),cardAmounts=new Map(),evidence=new Map(),withheld=[],unallocatedCash=[],unmapped=[],knownKeys=new Set(p.rows.map(r=>r.category)),seen=new Set(),salary=new Map();
  const key=(m,c)=>m+'\u0000'+c,categoryFor=c=>{if(knownKeys.has(c))return c;if(knownKeys.has(p.category_aliases[c]))return p.category_aliases[c];
   // Two established Portuguese labels for the same mortgage category. This
   // changes only planning assignment, never the original event or its amount.
   if(norm(c)==='financiamento imovel'){const same=[...knownKeys].filter(x=>norm(x)==='financiamento imobiliario');if(same.length===1)return same[0];}return c;};
  // Carry an existing decision only for the same identified purchase. A person
  // prefix or a similar merchant is never authority for a global category alias.
  const cardCategory=item=>{
   // The backend uses this one explicit unknown bucket. This keeps a received
   // unclassified item in that bucket without inventing a purpose or person.
   if(['a classificar','sem categoria','nao identificado','—',''].includes(norm(item.category)))return 'Sem classificação';
   const matches=(p.card_category_evidence||[]).filter(e=>
    typeof item.source_id==='string'&&item.source_id&&e.source_ref===item.source_id&&
    e.raw_category===item.category&&e.purchase_date===(item.purchase_date||item.posting_date)&&
    cents(e.amount)===cents(item.amount)&&typeof e.category==='string'&&e.category.trim());
   const categories=[...new Set(matches.map(e=>e.category))];
   return categories.length===1?categories[0]:item.category;
  };
  const add=(month,category,amount,detail)=>{if(!new RegExp('^'+year+'-(0[1-9]|1[0-2])$').test(month)||amount===0||amount<0&&!['installment','card_commitment'].includes(detail.kind))return;
   category=categoryFor(category);
   if(!category||!knownKeys.has(category)){unmapped.push({month,category:category||'Compromisso sem categoria',amount:money(amount),...detail});return;}
   const k=key(month,category),map=['installment','card_commitment'].includes(detail.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+amount);const a=evidence.get(k)||[];a.push({...detail,amount:money(amount)});evidence.set(k,a);
  };
  for(const e of events){const n=cents(e.signed_amount),description=e.description||'',c=norm(description+' '+e.category),source=String(e.source||'');
   if(n!==null&&n>0&&String(e.event_date)>asOf&&/^(salario( liquido)?|adiantamento quinzenal)$/.test(norm(description))&&!/bonus|13[º°o]?|decimo|ferias/.test(c)){const mk=String(e.event_date).slice(0,7);salary.set(mk,(salary.get(mk)||0)+n);}
   if(n===null||n>=0||e.internal_transfer||e.is_asset_movement||e.excluded_from_spend||/card|invoice|budget|historical_spending|projection_policy|planning_projection/.test(source)||/fatura|aeternum|mastercard|personnalite|c6 carbon/.test(c))continue;
   // Missing, blank, boolean or negative payroll amounts cannot prove a net deduction.
   const payrollAmount=v=>(typeof v==='number'||typeof v==='string'&&v.trim()!=='')&&cents(v)!==null&&cents(v)>=0;
   const payrollProof=(p.planning?.payroll_withholding||[]).find(w=>payrollAmount(w.base_income)&&payrollAmount(w.net_income)&&typeof e.source==='string'&&e.source.length>0&&typeof e.source_ref==='string'&&e.source_ref.length>0&&w.source===e.source&&w.source_ref===e.source_ref&&w.date===e.event_date&&cents(w.amount)===-n&&cents(w.base_income)-cents(w.net_income)===-n&&Array.isArray(w.evidence)&&w.evidence.some(v=>typeof v==='string'&&v.trim()));
   if(payrollProof){withheld.push({description,amount:money(-n),date:e.event_date,evidence:payrollProof.evidence});continue;}
   // A lender name alone is not evidence that net income already includes its payment.

   const proof=/coopharma|consignado|financiamento|emprestimo|condominio|seguro|iptu|ipva|licenciamento|mensalidade|parcela/.test(c)||e.confidence==='user_flow_editable'||e.confidence==='documented_scheduled';
   if(String(e.event_date)<asOf||String(e.event_date)===asOf&&!['user_flow_editable','legacy_projection_adjusted','documented_scheduled','documented_expected'].includes(e.confidence))continue;
   const identity=source+':'+e.source_ref+':'+e.event_date;if(seen.has(identity))continue;seen.add(identity);
   // Payment date is not service competence. Keep uncertain cash visible but separate.
   const competence=String(e.competence_month||'').slice(0,7),hasCompetence=proof&&/^\d{4}-(0[1-9]|1[0-2])$/.test(competence)&&Array.isArray(e.competence_evidence)&&e.competence_evidence.length>0&&e.competence_evidence.every(x=>typeof x==='string'&&x.trim());
   if(!hasCompetence){unallocatedCash.push({description,date:e.event_date,category:e.category,amount:money(-n),source:e.source,source_ref:e.source_ref,reason:'Data de pagamento conhecida; competência do serviço ainda não comprovada.'});continue;}
   add(competence,e.category,-n,{description,date:e.event_date,competence_month:competence,competence_evidence:e.competence_evidence,kind:'scheduled',contracted:/financiamento|emprestimo|parcela/.test(c)});
  }
  for(const card of cardRows)for(const cycle of card.cycles||[])for(const item of cycle.items||[]){
   const installment=Number(item.total_installments)>1;
   const received=['PENDING','POSTED','DOCUMENTED'].includes(item.provider_status);
   if((!installment&&!received)||item.is_payment)continue;
   const itemAmount=cents(item.amount);if(itemAmount===null)throw Error('card commitment amount unavailable');if(itemAmount===0)continue;
   const month=String(item.reference_month||cycle.month||'').slice(0,7),identity=[card.family,month,item.source_id,item.installment_number].join(':');
   if(!item.source_id||seen.has(identity))continue;seen.add(identity);
   add(month,cardCategory(item),itemAmount,{description:item.description,date:item.purchase_date||item.posting_date,source_ref:item.source_id,kind:installment?'installment':'card_commitment',installment:item.installment_number,total_installments:item.total_installments,contracted:true});
  }
  // Unknown obligations remain explicit. They are never silently converted to zero.
  const extraCategories=[...new Set(unmapped.map(x=>x.category))].filter(c=>!knownKeys.has(c));
  for(const category of extraCategories){knownKeys.add(category);p.rows.push({category,reference_monthly:null,commitments_only:true,months:p.months.map(m=>({month:m.month,actual:0,card_actual:0,pending:0,target:null,target_basis:'history'}))});}
  for(const x of unmapped){const k=key(x.month,x.category),map=['installment','card_commitment'].includes(x.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+cents(x.amount));evidence.set(k,[...(evidence.get(k)||[]),x]);}
  const plans=[];
  for(let i=0;i<12;i++){
   const m=p.months[i],past=m.month<current,rows=[];
   const incomeApproved=p.income_approvals.year===true||p.income_approvals.months?.[m.month]===true;
   if(!incomeApproved&&salary.has(m.month))m.income_target=money(salary.get(m.month)+(m.month===current?(cents(m.income_regular)||0):0));
   const income=cents(m.income_target);
   for(const r of p.rows){const x=r.months[i],type=kind(r.category),history=cents(r.reference_monthly),owner=x.target_basis==='owner',scheduled=amounts.get(key(m.month,r.category))||0,card=cardAmounts.get(key(m.month,r.category))||0;
    if(m.month===current&&card>0&&x.card_actual===undefined)throw Error('recorded card coverage unavailable');
    const floor=Math.max(0,m.month===current?(cents(x.actual)||0)+scheduled+Math.max(0,card-(cents(x.card_actual)||0)):scheduled+card),details=evidence.get(key(m.month,r.category))||[];
    let proposed=null,reason='',desired=0;
    if(owner){proposed=cents(x.target);reason='Meta aprovada por você; preservada.';}
    else if(past){reason='Sem orçamento aprovado para este mês encerrado.';}
    else {
     // A reference is descriptive, not a recommendation. A reviewed proposal
     // must carry a reason and source evidence, separately from owner approval.
     const plan=p.planning?.months?.[m.month]?.[r.category];
     const reviewed=plan&&plan.status==='reviewed_proposal'&&typeof plan.reason==='string'&&plan.reason.trim()&&Array.isArray(plan.evidence)&&plan.evidence.length>0&&plan.evidence.every(e=>typeof e==='string'&&e.trim());
     if(reviewed&&cents(plan.target)!==null&&cents(plan.target)>=0){
      proposed=Math.max(floor,cents(plan.target));reason=plan.reason+(cents(plan.target)<floor?' Proposta elevada ao já registrado e aos compromissos conhecidos.':'');
     }else if(type==='fixed'&&details.length&&history===null){
      proposed=null;reason='Compromissos identificados são o piso, não prova de cobertura integral da categoria. Falta proposta revisada.';
     }else{
      proposed=null;reason='Referência histórica e compromissos disponíveis para planejamento. Falta proposta fundamentada por categoria; nenhum corte ou meta zero foi presumido para fechar a renda.';
     }
    }
    rows.push({row:r,value:x,type,owner,floor,proposed,desired,reason,details,history});
   }
   for(const r of rows){let value=r.proposed;
    r.value.target=money(value);r.value.target_basis=r.owner?'owner':'proposal';
    r.value.strategy={type:r.type,reason:r.reason,floor:money(r.floor),history:money(r.history),details:r.details,proposed:!r.owner,needsReview:!r.owner&&r.proposed===null};
   }
   m.target=money(sum(rows.map(r=>cents(r.value.target))));
   plans.push({month:m.month,fixed:money(rows.reduce((a,r)=>a+r.floor,0)),income:money(income),target:m.target,
    balance:m.target===null||income===null?null:money(income-cents(m.target)),covered:!past||rows.some(r=>r.owner)});
  }
  p.strategy={version:'strategic-v442',proposals:true,pastWithoutPlan:plans.filter(x=>!x.covered).length,regular_income_basis:'net_received_without_bonus_or_thirteenth',months:plans,
   payroll_withheld_not_added:withheld,cash_without_competence:unallocatedCash,unmapped_obligations:unmapped,flow_provision_included:false,
   proposal_review:p.planning?.status||'missing',reviewed_at:p.planning?.reviewed_at||null,
   alternatives:['Preservar parcelas e compromissos já assumidos.','Comparar alternativas de redução com valores e consequências; não zerar categorias automaticamente.','Rever gastos essenciais pelo detalhe e renegociar contratos quando possível.','Usar bônus e 13º apenas como cobertura extraordinária, sem incorporá-los ao salário mensal.']};
  p.proposed=p.rows.some(r=>r.months.some(m=>m.target_basis==='proposal'&&m.target!==null));return p;
 }
 return Object.freeze({derive,kind});
});


;
/* lts-v441-budget-ui.js */
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
    if(s.data.strategy?.proposal_review==='review_required')html+='<p class="v441-warning">Entraram novos dados após a proposta'+(s.data.strategy.reviewed_at?' de '+esc(s.data.strategy.reviewed_at.split('-').reverse().join('/')):'')+'. Confira os limites; os compromissos atuais continuam preservados.</p>';
    if(v.cashUnallocated.length){
     html+='<section class="v441-cash-reserve"><h3>Reservas de caixa por vencimento</h3><p>Calendário sem faturas de cartão: <strong>'+money(v.cashWithoutCompetence)+'</strong>. Reserva de caixa, não um total de consumo.</p>';
     if(v.cashCoverageGap>0)html+='<p class="v441-warning">Estes pagamentos superam a renda prevista em '+money(v.cashCoverageGap)+', antes de outras despesas e faturas. Confira o calendário no Fluxo.</p>';
     html+='<details><summary>Ver pagamentos previstos ('+v.cashUnallocated.length+')</summary><p>A competência ainda precisa de confirmação. Estas reservas permanecem separadas das metas por categoria; não as some como novas despesas.</p>'+v.cashUnallocated.slice(0,100).map(x=>'<p>'+esc(x.date)+' · '+esc(x.description||x.category||'Pagamento previsto')+' · '+money(api.cents(x.amount))+'</p>').join('')+(v.cashUnallocated.length>100?'<p>Exibidos os primeiros 100 pagamentos. Consulte o restante no Fluxo.</p>':'')+'</details></section>';
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
    if(s.data.unknown)html+='<p class="v441-warning">Há lançamentos sem classificação. Confira seus detalhes antes de decidir.</p>';
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

;
/* lts-v441-flow-summary.js */
/* Presentation only. All balances come from the existing canonical Flow response. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_FLOW||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,previous=render;
  const money=n=>n===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n/100);
  const date=x=>x?.split('-').reverse().join('/')||'—';
  function paint(){
   const old=document.getElementById('v441FlowSummary');
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden')||ACC!=='Consolidado'){old?.remove();return;}
   const body=document.querySelector('.v382-tool-body');if(!body)return;old?.remove();
   let premises=document.getElementById('v441FlowPremises');if(!premises){premises=document.createElement('div');premises.id='v441FlowPremises';premises.dataset.v425Section='liquidity';body.append(premises);}
   premises.innerHTML='<strong>Premissas dos cenários de caixa</strong><p>Os cenários usam as entradas e saídas já previstas no Fluxo, inclusive salários futuros. Não representam dinheiro garantido. O horizonte de curto prazo é de até 90 dias, limitado ao período consultado.</p><p>O cenário com ações depende de venda, câmbio, impostos e transferência. Lotes futuros dependem da liberação. FGTS tem restrições e prazo para saque; a recomposição futura não é caixa disponível hoje.</p><p>Novos gastos: R$ 15 mil por mês somente no Aeternum, desde o terceiro mês à frente. A janela avança a cada mês; antes dela entram apenas faturas e parcelas conhecidas. Essa provisão pertence ao Fluxo e não é somada ao orçamento por categoria.</p>';
  }
  const style=document.createElement('style');style.textContent='#v441FlowSummary{border:1px solid #dce5f0;border-radius:12px;padding:14px;margin:12px 0;background:#fff;color:#173a61}#v441FlowSummary h2{font-size:17px;margin:0 0 12px}#v441FlowSummary h3{font-size:12px;margin:16px 0 6px}.v441-flow-cash{display:grid;grid-template-columns:1fr 1fr;gap:10px}.v441-flow-cash>div{background:#f3f7fc;padding:10px;border-radius:8px}.v441-flow-cash span{display:block;font-size:12px}.v441-flow-cash strong{display:block;margin-top:6px;font-size:21px;overflow-wrap:anywhere}.v441-flow-note{font-size:12px;line-height:1.5;color:#617083;margin:10px 0 0}#v441FlowSummary ul{list-style:none;padding:0;margin:0}#v441FlowSummary li{display:flex;justify-content:space-between;gap:14px;padding:8px 0;border-bottom:1px solid #e6edf4;font-size:13px}#v441FlowSummary li strong{text-align:right;overflow-wrap:anywhere}#v441FlowPremises{font-size:12px;line-height:1.5}@media(max-width:430px){.v441-flow-cash strong{font-size:17px}#v441FlowSummary li{font-size:12px}#v441FlowSummary li>span{max-width:45%}}';document.head.append(style);
  const mobileStyle=document.createElement('style');mobileStyle.textContent='#v441FlowSummary{scroll-margin-top:78px}@media(max-width:359px){.v441-flow-cash{grid-template-columns:1fr}}';document.head.append(mobileStyle);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};window.__LTS_V441_FLOW={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V425_FLOW_OPTIONS||!window.LTSV441Budget)return false;if(!w.__LTS_V441_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V441_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-flow-summary.js',install);
})();

;
/* lts-v442-income-composition.js */
(function(){'use strict';const shell=document.getElementById('shell');function runtime(){
 if(window.__LTS_V442_INCOME_DETAIL||typeof flowEditorInline!=='function')return;const previous=flowEditorInline;
 flowEditorInline=function(day){const html=previous.apply(this,arguments),d=FLOWEDIT?.data;if(!html||FLOWEDIT?.anchor_date!==day||!Array.isArray(d?.composition)||!d.composition.length)return html;
  const rows=d.composition.filter(x=>typeof x.rubric==='string'&&Number.isFinite(Number(x.amount)));if(rows.length!==d.composition.length)return html;
  const detail='<details class="v442-income-composition"><summary>Composição do pagamento previsto</summary><p>Referência: '+esc(d.payroll_reference_date||'—')+'</p>'+rows.map(x=>'<p>'+esc(x.rubric)+' · <strong>'+brl(Number(x.amount))+'</strong></p>').join('')+'<p>Total da previsão: '+brl(Number(d.amount))+'</p>'+(d.composition_document_pending?'<p>Informado por você; demonstrativo a conferir.</p>':'')+'</details>';
  return html.replace('<div class="flowedit-actions">',detail+'<div class="flowedit-actions">');
 };
 const priorBadge=flowClassificationBadge;
 flowClassificationBadge=function(e){
  const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  if(Number(e.signed_amount)>0&&/^\d{4}-\d{2}-\d{2}$/.test(e.event_date||'')&&e.event_date>today){
   const label=/(^|\D)13[º°o]?|d[eé]cimo terceiro/i.test(e.description||'')?'13º previsto':'Entrada prevista';
   return '<span class="tag">'+label+'</span>';
  }
  return priorBadge.apply(this,arguments);
 };window.__LTS_V442_INCOME_DETAIL=true;
}function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V337_MONTH)return false;if(!w.__LTS_V442_INCOME_DETAIL){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return!!w.__LTS_V442_INCOME_DETAIL;}catch{return false;}}let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',start);start();window.LTSV339Boot?.watch('lts-v442-income-composition.js',install);})();

;
/* lts-v463-debt-model.js */
/* Estimate a fixed-payment loan from the preserved original capital and proved payments. */
(function(root){'use strict';
 const num=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!=='')&&Number.isFinite(Number(x))?Number(x):null;
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+'T12:00:00Z'))&&new Date(x+'T12:00:00Z').toISOString().slice(0,10)===x;
 const cents=x=>{const n=num(x);return n!==null&&Number.isSafeInteger(Math.round(n*100))?Math.round(n*100):null;};
 function pv(rate,n,payment){return rate===0?n*payment:payment*-Math.expm1(-n*Math.log1p(rate))/rate;}
 function estimate(asset,loan,asOf){
  if(!date(asOf)||!asset||loan?.id!=='volvo'||loan.confidence!=='documented_contract')return null;
  if(num(loan.current_documentary_debt_balance)!==null&&date(loan.current_debt_as_of))return null;
  const principal=cents(asset.documented_financed_balance),payment=cents(loan.installment),n=loan.total_events;
  const paid=Array.isArray(loan.realized_rows)?[...loan.realized_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  const future=Array.isArray(loan.schedule_rows)?[...loan.schedule_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  if(principal===null||principal<=0||payment===null||payment<=0||!Number.isSafeInteger(n)||n<1||n>600||principal>n*payment||!paid||!future||paid.length<1||paid.length+future.length!==n||loan.confirmed_paid_installments!==paid.length||loan.remaining_events!==future.length||num(loan.unconfirmed_past_events)!==0)return null;
  const refs=new Set();
  for(let i=0;i<paid.length;i++){
   const p=paid[i];if(p.status!=='paid'||p.installment_number!==i+1||!date(p.paid_date)||p.paid_date>asOf||!date(p.due_date)||!p.source_ref||refs.has(p.source_ref)||p.payment_basis!=='validated_existing_bank_identity'||cents(p.paid_amount)!==payment||cents(p.scheduled_amount)!==payment)return null;
   refs.add(p.source_ref);
  }
  for(let i=0;i<future.length;i++){const p=future[i];if(p.installment_number!==paid.length+i+1||!date(p.due_date)||p.due_date<=asOf||cents(p.amount)!==payment)return null;}
  let rate=0;
  if(principal<n*payment){let low=0,high=1;if(pv(high,n,payment)>principal)return null;for(let i=0;i<90;i++){const mid=(low+high)/2;if(pv(mid,n,payment)>principal)low=mid;else high=mid;}rate=(low+high)/2;}
  const balance=Math.round(pv(rate,future.length,payment));if(!Number.isSafeInteger(balance)||balance<0||balance>principal)return null;
  return {status:'estimated_after_confirmed_payments',balance:balance/100,asOf:paid.at(-1).paid_date,initialPrincipal:principal/100,paidCount:paid.length,totalCount:n,paidAmount:paid.length*payment/100,remainingCount:future.length,nextDue:future[0]?.due_date||null,nextAmount:future.length?payment/100:null,method:'fixed_payment_annuity',inferredMonthlyRate:rate};
 }
 const api={estimate,pv};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSV463Debt=api;
})(typeof window==='undefined'?{}:window);

;
/* lts-v463-debt-ui.js */
/* Preserve source positions; show a dated estimate instead of an empty liability. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V463_DEBT)return;
  const previous=render,model=parent.LTSV463Debt;
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),date=x=>x?.split('-').reverse().join('/')||'—';
  function data(){const j=window.__LTS_V168_STATE?.wealth?.data,loan=j?.financing?.summary?.commitments?.find(x=>x.id==='volvo'),asOf=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());return{j,estimate:model.estimate(j?.wealth?.assets?.volvo_xc40,loan,asOf)};}
  function basis(x){const d=document.createElement('details');d.className='v463-debt-basis';const title=document.createElement('summary');title.textContent='Base da estimativa';d.append(title);for(const text of ['Valor financiado informado: '+money(x.initialPrincipal)+'.',x.paidCount+' de '+x.totalCount+' parcelas pagas e identificadas no banco, somando '+money(x.paidAmount)+'.','Estimativa após o pagamento de '+date(x.asOf)+', pelas parcelas fixas do contrato. O extrato atualizado confirma juros, encargos e o valor para quitação.']){const p=document.createElement('p');p.textContent=text;d.append(p);}return d;}
  function paint(){
   const {j,estimate:x}=data();if(!x)return;
   if(V==='Patrimônio'){
    const row=document.querySelector('[data-v386-debt="volvo"]');
    if(row){row.querySelector('b').textContent=money(x.balance);const note=row.querySelector('small');if(note)note.textContent='Estimado após a parcela de '+date(x.asOf);row.querySelector('.v463-debt-basis')?.remove();row.append(basis(x));}
    const assessment=window.__LTS_V407_WEALTH?.assess(j),totals=document.querySelector('.v365-wealth-totals');
    if(totals&&assessment?.available&&assessment.missing?.length===1&&assessment.missing[0]==='volvo'){
     const cards=totals.querySelectorAll(':scope>article'),debt=cards[1],net=cards[2];
     if(debt){debt.querySelector('span').textContent='Dívidas';debt.querySelector('strong').textContent=money(assessment.known+x.balance);debt.querySelector('small').textContent='Inclui a estimativa do financiamento da Volvo';}
     if(net){net.querySelector('span').textContent='Patrimônio líquido estimado';net.querySelector('strong').textContent=money(assessment.gross-assessment.known-x.balance);net.querySelector('small').textContent='Ativos menos dívidas, incluindo a estimativa da Volvo';net.querySelectorAll('details').forEach(e=>e.remove());net.append(basis(x));}
     const warning=document.querySelector('.v365-material');if(warning&&/Volvo/.test(warning.textContent)){const action=warning.querySelector('button');warning.replaceChildren(document.createTextNode('Saldo da Volvo estimado. Você pode atualizar o extrato em Ações. '));if(action)warning.append(action);}
    }
    const vehicle=[...document.querySelectorAll('.v168-asset')].find(a=>a.querySelector('h3')?.textContent==='Volvo XC40');
    if(vehicle){const market=Number(j.wealth.assets.volvo_xc40.market_central);if(Number.isFinite(market))vehicle.querySelector('strong').textContent=money(market-x.balance);const fact=[...vehicle.querySelectorAll('.v168-fact')].find(a=>/Financiamento na contratação|Saldo para quitação/.test(a.querySelector('span')?.textContent||''));if(fact){fact.querySelector('span').textContent='Saldo devedor estimado';fact.querySelector('b').textContent=money(x.balance);}vehicle.querySelectorAll('.v463-debt-basis').forEach(a=>a.remove());vehicle.append(basis(x));}
   }
   if(V==='Atualizações'){
    const task=document.getElementById('v365WealthTasks');if(task){const h=task.querySelector('h2'),p=task.querySelector('p'),button=task.querySelector('button');h.textContent='Atualizar extrato do financiamento da Volvo';p.textContent='Usamos a base anterior e '+x.paidCount+' parcelas pagas para estimar o saldo. Envie uma posição recente quando estiver disponível.';if(button){button.textContent='Enviar extrato atualizado';button.onclick=()=>window.__LTS_V168_COMPLETE_REVIEW.openVolvoStatement();}}
   }
  }
  render=function(){const result=previous.apply(this,arguments);paint();return result;};window.__LTS_V463_DEBT={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V407_WEALTH||!window.LTSV463Debt)return false;if(!w.__LTS_V463_DEBT){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V463_DEBT;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v463-debt-ui.js',install);
})();

