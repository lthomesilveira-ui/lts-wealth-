(function(){
  const w=window,d=document,MARK='ledger-search-export-v1';
  if(w.LTS_V151_LEDGER_SEARCH===MARK)return;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const brl=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v||0)||0);
  const state=w.__LTS_V151_LEDGER_SEARCH_STATE||(w.__LTS_V151_LEDGER_SEARCH_STATE={term:'',loading:false,total:0,rows:[],error:null,timer:null,seq:0});

  function css(){
    if(d.getElementById('v151LedgerSearchCss'))return;
    const s=d.createElement('style');s.id='v151LedgerSearchCss';s.textContent=`
      .v151-ledger{min-width:0}.v151-ledger-head{display:flex;align-items:flex-start;justify-content:space-between;gap:8px}.v151-ledger-head b{font-size:10px}.v151-ledger-head small{display:block;font-size:8px;color:var(--mut);margin-top:3px;line-height:1.35}.v151-ledger-input{width:100%;box-sizing:border-box;border:1px solid var(--bd);border-radius:9px;padding:9px;background:#fff;color:var(--ink);font-size:10px;margin-top:7px}.v151-ledger-meta{display:flex;justify-content:space-between;gap:8px;align-items:center;margin-top:6px;min-height:22px}.v151-ledger-meta span{font-size:8px;color:var(--mut)}.v151-ledger-results{margin-top:6px;max-height:290px;overflow:auto;border-top:1px solid #e7ebef}.v151-ledger-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:9px;padding:8px 1px;border-bottom:1px solid #edf1f4;align-items:center}.v151-ledger-row b{display:block;font-size:9px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.v151-ledger-row small{display:block;font-size:7px;color:var(--mut);margin-top:2px;line-height:1.35}.v151-ledger-row strong{font-size:9px;white-space:nowrap}.v151-ledger-empty{font-size:8px;color:var(--mut);padding:10px 0}.v151-ledger-export{border:1px solid #d7dde5;background:#fff;color:#17304d;border-radius:999px;padding:6px 9px;font-size:8px;font-weight:850;cursor:pointer;white-space:nowrap}.v151-ledger-export:disabled{opacity:.5;cursor:default}
    `;(d.head||d.documentElement).appendChild(s);
  }
  function rpcArgs(term,limit,offset){return {p_from:'2013-10-10',p_to:null,p_query:term,p_direction:null,p_account:null,p_limit:limit,p_offset:offset}}
  function rowsHtml(rows){return rows.map(x=>`<div class="v151-ledger-row"><div><b>${esc(x.description||x.counterparty||x.category||'Lançamento')}</b><small>${esc(x.date||'')} · ${esc(x.account||'sem conta identificada')} · ${esc(x.category||'A classificar')}${x.center_cost?' · '+esc(x.center_cost):''}</small></div><strong>${brl(x.amount)}</strong></div>`).join('')}
  function paint(){
    const out=d.getElementById('v151LedgerResults'),meta=d.getElementById('v151LedgerMeta'),btn=d.getElementById('v151LedgerExport');if(!out||!meta)return;
    if(state.loading){meta.textContent='Buscando…';out.innerHTML='<div class="v151-ledger-empty">Consultando lançamentos…</div>'}
    else if(state.error){meta.textContent='Consulta indisponível';out.innerHTML=`<div class="v151-ledger-empty">${esc(state.error)}</div>`}
    else if(!state.term){meta.textContent='Histórico desde 2013 + lançamentos futuros';out.innerHTML='<div class="v151-ledger-empty">Comece a digitar. Ex.: Mastercard, Visa, condomínio, escola…</div>'}
    else{meta.textContent=`${state.total.toLocaleString('pt-BR')} lançamento(s) encontrado(s)`;out.innerHTML=state.rows.length?rowsHtml(state.rows):'<div class="v151-ledger-empty">Nenhum lançamento encontrado.</div>'}
    if(btn)btn.disabled=state.loading||!state.term||!state.total;
  }
  async function search(term){
    term=String(term||'').trim();state.term=term;state.error=null;state.rows=[];state.total=0;const seq=++state.seq;
    if(!term){state.loading=false;paint();return}
    state.loading=true;paint();
    try{
      const {data,error}=await w.S.rpc('lts_browser_transactions_v1',rpcArgs(term,200,0));
      if(seq!==state.seq)return;
      if(error||!data)throw Error(error?.message||'Consulta indisponível');
      state.total=Number(data.total||0)||0;state.rows=Array.isArray(data.rows)?data.rows:[];state.loading=false;paint();
      w.__LTS_V151_LEDGER_SEARCH_STATUS={version:MARK,query:term,total:state.total,server_side:true,from:'2013-10-10',to:null,preview_limit:200,writer_added:false,pass:true};
    }catch(e){if(seq!==state.seq)return;state.loading=false;state.error='Não foi possível consultar agora: '+String(e?.message||e);paint();w.__LTS_V151_LEDGER_SEARCH_STATUS={version:MARK,query:term,server_side:true,writer_added:false,pass:false,error:String(e?.message||e)}}
  }
  function schedule(term){clearTimeout(state.timer);state.timer=setTimeout(()=>search(term),300)}
  function cell(v){const s=String(v??'').replace(/"/g,'""');return `"${s}"`}
  async function exportCsv(){
    const term=String(state.term||'').trim();if(!term)return;
    const btn=d.getElementById('v151LedgerExport'),old=btn?.textContent;if(btn){btn.disabled=true;btn.textContent='Preparando…'}
    try{
      const all=[];let offset=0,total=Infinity;
      while(offset<total){const {data,error}=await w.S.rpc('lts_browser_transactions_v1',rpcArgs(term,10000,offset));if(error||!data)throw Error(error?.message||'Exportação indisponível');const rows=Array.isArray(data.rows)?data.rows:[];total=Number(data.total||0)||0;all.push(...rows);offset+=rows.length;if(!rows.length||rows.length<10000)break}
      const headers=['data','descricao','conta','direcao','valor','categoria','contraparte','centro_de_custo','fonte','referencia'];
      const lines=[headers.map(cell).join(';')].concat(all.map(x=>[x.date,x.description,x.account,x.direction,Number(x.amount||0).toFixed(2).replace('.',','),x.category,x.counterparty,x.center_cost,x.source,x.source_ref].map(cell).join(';')));
      const blob=new Blob(['\ufeff'+lines.join('\r\n')],{type:'text/csv;charset=utf-8;'}),url=URL.createObjectURL(blob),a=d.createElement('a');a.href=url;a.download=`lts-wealth-lancamentos-${term.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'').toLowerCase()||'busca'}.csv`;d.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),0);
      w.__LTS_V151_LEDGER_EXPORT_STATUS={version:MARK,query:term,rows:all.length,format:'excel-compatible-csv',writer_added:false,pass:true};
    }catch(e){w.__LTS_V151_LEDGER_EXPORT_STATUS={version:MARK,query:term,writer_added:false,pass:false,error:String(e?.message||e)};state.error='Não foi possível exportar agora: '+String(e?.message||e);paint()}
    finally{if(btn){btn.disabled=false;btn.textContent=old||'Exportar para Excel (CSV)'}}
  }
  function installUi(){
    if(String(w.V)!=='Atualizações')return false;
    css();const box=d.getElementById('v150Toolbox');if(!box)return false;
    const grid=box.querySelector('.v150-toolgrid');if(!grid)return false;
    let host=d.getElementById('v151LedgerSearch');
    if(!host){const old=grid.children[1];host=d.createElement('div');host.id='v151LedgerSearch';host.className='v151-ledger';host.innerHTML=`<div class="v151-ledger-head"><div><b>Encontrar lançamentos</b><small>Busca instantânea no histórico desde 2013 e também nos lançamentos futuros já existentes no LTS.</small></div><button id="v151LedgerExport" class="v151-ledger-export" type="button" disabled>Exportar para Excel (CSV)</button></div><input id="v151LedgerTerm" class="v151-ledger-input" type="search" autocomplete="off" placeholder="Digite Mastercard, Visa, condomínio…"><div class="v151-ledger-meta"><span id="v151LedgerMeta"></span></div><div id="v151LedgerResults" class="v151-ledger-results"></div>`;if(old)grid.replaceChild(host,old);else grid.appendChild(host);
      const inp=d.getElementById('v151LedgerTerm');inp?.addEventListener('input',e=>schedule(e.target.value));d.getElementById('v151LedgerExport')?.addEventListener('click',exportCsv);
    }
    const inp=d.getElementById('v151LedgerTerm');if(inp&&inp.value!==state.term)inp.value=state.term;paint();return true;
  }
  function after(){if(String(w.V)==='Atualizações')installUi()}
  w.__LTS_V151_LEDGER_SEARCH_AFTER_RENDER=after;w.__LTS_V151_LEDGER_SEARCH_RUN=search;w.__LTS_V151_LEDGER_EXPORT_RUN=exportCsv;w.LTS_V151_LEDGER_SEARCH=MARK;
  after();[100,300,700,1400,2600,5000,9000].forEach(ms=>setTimeout(after,ms));
})();