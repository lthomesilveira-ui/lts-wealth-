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
  const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
  const date=v=>{const s=String(v||'').slice(0,10);return /^\d{4}-\d\d-\d\d$/.test(s)?s.split('-').reverse().join('/'):'Data a confirmar';};
  const money=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?'Valor a confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const phase={received:'Recebido',interpreted:'Leitura disponível',reconciled:'Conciliado',needs_decision:'Revisão pendente',resolved:'Concluído'};
  function confirmed(attempt,id){attempt.confirmed=true;attempt.inboxId=id;attempt.input.disabled=false;attempt.input.value='';attempt.button.disabled=false;attempt.button.textContent='Enviar para revisão';attempt.message.textContent='Arquivo recebido para revisão. Consulte Documentos enviados.';}
  function pair(root,label,value){if(value===undefined||value===null||value==='')return;const row=el('p',undefined,'v407-doc-pair');row.append(el('span',label),el('strong',String(value)));root.append(row);}
  function releaseURLs(){for(const u of objectURLs)URL.revokeObjectURL(u);objectURLs.clear();}
  function reset(){state.generation++;state.open=false;state.status='idle';state.data=null;state.error='';state.promise=null;attempts.clear();releaseURLs();const panel=document.getElementById('v407Documents');if(panel)panel.open=false;paint();}
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
   const generation=state.generation;button.disabled=true;box.replaceChildren(el('p','Abrindo arquivo…'));
   try{
    const {data:meta,error}=await S.rpc('lts_browser_document_meta_v1',{p_inbox_id:item.inbox_id});
    if(generation!==state.generation)return;
    if(error||meta?.ok!==true||typeof meta.storage_path!=='string')throw Error('unavailable');
    for(const attempt of attempts.values())if(attempt.path===meta.storage_path)confirmed(attempt,item.inbox_id);
    const {data:blob,error:downloadError}=await S.storage.from('lts-documents').download(meta.storage_path);
    if(generation!==state.generation)return;
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
  function mount(){
   if(!D){if(state.data||state.promise||attempts.size)reset();return;}
   if(V!=='Atualizações')return;
   const root=document.querySelector('.v168-updates');if(!root||document.getElementById('v407Documents'))return;
   const box=el('details',undefined,'v168-card v407-documents');box.id='v407Documents';box.open=state.open;box.append(el('summary','Documentos enviados'));
   const body=el('div');body.id='v407DocumentsBody';box.append(body);root.append(box);
   box.addEventListener('toggle',()=>{state.open=box.open;if(box.open&&state.status==='idle')refresh();});paint();
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
  for(const name of ['signOut','signInWithPassword'])if(typeof S.auth[name]==='function'){const previous=S.auth[name].bind(S.auth);S.auth[name]=function(){reset();return previous(...arguments);};}
  window.addEventListener('pagehide',releaseURLs);
  window.__LTS_V407_DOCUMENTS={installed:true,refresh,mount};mount();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_DOCUMENTS?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_DOCUMENTS?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-document-review.js',install);
})();
