(function(){
  const outer=document.getElementById('shell');
  let wired=null;

  function chain(){
    try{
      const d141=outer&&outer.contentDocument,f140=d141&&d141.getElementById('shell');
      const d140=f140&&f140.contentDocument,f139=d140&&d140.getElementById('shell');
      const d139=f139&&f139.contentDocument,f138=d139&&d139.getElementById('shell');
      const d138=f138&&f138.contentDocument,f137=d138&&d138.getElementById('shell');
      const d137=f137&&f137.contentDocument,app=d137&&d137.getElementById('app');
      if(!app)return null;
      return {w:app.contentWindow,d:app.contentDocument};
    }catch(e){return null}
  }

  function ensureCss(d){
    if(d.getElementById('wip35-v142-liquidity-ui-css'))return;
    const s=d.createElement('style');s.id='wip35-v142-liquidity-ui-css';s.textContent=`
      .l142-review{margin:-3px 0 12px;border:1px solid #d9e0e8;border-left:4px solid #b8935a;border-radius:14px;background:#fff;padding:12px}.l142-reviewhead{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.l142-reviewhead h3{font-size:14px;margin:3px 0}.l142-reviewhead p{font-size:9px;color:var(--mut);line-height:1.4;margin:0}.l142-pill{font-size:8px;font-weight:900;border-radius:999px;padding:5px 8px;background:#edf4f8;color:#365c79;white-space:nowrap}.l142-grid{display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:7px;margin-top:10px}.l142-field label{display:block;font-size:7px;text-transform:uppercase;letter-spacing:.04em;color:var(--mut);font-weight:850;margin-bottom:4px}.l142-field input,.l142-field select{width:100%;box-sizing:border-box;border:1px solid var(--bd);border-radius:9px;padding:8px 9px;background:#fff;font-size:10px;color:var(--ink);min-height:34px}.l142-actions{display:flex;gap:7px;align-items:center;flex-wrap:wrap;margin-top:9px}.l142-actions button{border:1px solid var(--bd);background:#fff;border-radius:999px;padding:7px 10px;font-size:9px;font-weight:850;color:var(--ink)}.l142-actions button.primary{background:#17304d;border-color:#17304d;color:#fff}.l142-actions button.gold{background:#b8935a;border-color:#b8935a;color:#fff}.l142-actions button:disabled{opacity:.5}.l142-msg{font-size:8px;color:var(--mut);line-height:1.4}.l142-preview{display:grid;grid-template-columns:repeat(4,1fr);gap:7px;margin-top:10px}.l142-preview>div{background:#fafbfd;border:1px solid #e7ebef;border-radius:9px;padding:8px}.l142-preview span{display:block;font-size:7px;text-transform:uppercase;font-weight:850;color:var(--mut)}.l142-preview b{display:block;font-size:12px;margin-top:4px}.l142-safety{margin-top:8px;background:#f5f8fb;border-radius:9px;padding:8px;font-size:8px;color:#536170;line-height:1.4}.l142-success{border-color:#cfe3d7;background:#f7fbf8}.l142-success .l142-pill{background:#eaf6ee;color:#3f7756}
      @media(max-width:980px){.l142-grid,.l142-preview{grid-template-columns:1fr 1fr}}
      @media(max-width:600px){.l142-reviewhead{flex-direction:column}.l142-grid,.l142-preview{grid-template-columns:1fr}}
    `;d.head.appendChild(s)
  }

  function norm(s){return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase()}
  function brNumber(raw){
    let s=String(raw||'').trim().toLowerCase();let mult=1;
    if(/\bmil\b/.test(s)||/k$/.test(s)){mult=1000;s=s.replace(/\bmil\b|k$/g,'').trim()}
    s=s.replace(/r\$/g,'').replace(/\s/g,'');
    if(/^\d{1,3}(\.\d{3})+(,\d{1,2})?$/.test(s))s=s.replace(/\./g,'').replace(',','.');
    else if(/^\d+(,\d{1,2})$/.test(s))s=s.replace(',','.');
    else if(/^\d+\.\d{3}$/.test(s))s=s.replace('.','');
    const n=Number(s);return Number.isFinite(n)&&n>0?Math.round(n*mult*100)/100:null
  }
  function parseAmount(text){
    const pats=[/(?:r\$\s*)?(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(mil|k)\b/i,/r\$\s*(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i,/\b(\d{4,}(?:,\d{1,2})?)\b/i];
    for(const p of pats){const m=String(text||'').match(p);if(m){const n=brNumber((m[1]||'')+(m[2]||''));if(n)return n}}
    return null
  }
  function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}

  function movementType(text){const n=norm(text);if(/\bresgat/.test(n))return 'redemption';if(/\baplic/.test(n))return 'application';return null}
  function resolveAccount(text,accounts){const n=norm(text);const explicit=(accounts||[]).filter(a=>n.includes(norm(a.institution))||n.includes(norm(a.account_name)));return explicit.length===1?explicit[0]:null}
  function resolveAsset(text,assets){const n=norm(text);let explicit=(assets||[]).filter(a=>n.includes(norm(a.asset_name)));if(explicit.length===1)return explicit[0];if(n.includes('cofrinho')){explicit=(assets||[]).filter(a=>norm(a.asset_name).includes('cofrinho'));if(explicit.length===1)return explicit[0]}return null}

  function panelHost(d){
    const q=d.querySelector('.u142-quick');if(!q)return null;
    let p=d.getElementById('l142Review');if(!p){p=d.createElement('div');p.id='l142Review';q.insertAdjacentElement('afterend',p)}return p
  }

  function optionHtml(items,valueKey,labelFn,selected,placeholder){
    return `<option value="">${esc(placeholder)}</option>`+(items||[]).map(x=>{const v=String(x[valueKey]||''),sel=selected&&String(selected[valueKey]||'')===v?' selected':'';return `<option value="${esc(v)}"${sel}>${esc(labelFn(x))}</option>`}).join('')
  }

  async function startLiquidity(w,d,text,type){
    const host=panelHost(d);if(!host)return;
    host.className='l142-review';host.innerHTML=`<div class="l142-reviewhead"><div><span class="u142-eye">Movimentação de liquidez</span><h3>Revisar antes de gravar</h3><p>Resgate e aplicação movem valor entre banco e ativo. Não são renda nem gasto.</p></div><span class="l142-pill">sem gravação ainda</span></div><div class="l142-msg" style="margin-top:9px">Carregando contas e ativos elegíveis…</div>`;
    const {data,error}=await w.S.rpc('lts_browser_liquidity_movement_options_v1');
    if(error||!data){host.innerHTML=`<div class="l142-reviewhead"><div><h3>Não foi possível preparar a movimentação</h3><p>${esc(error?.message||'Opções indisponíveis.')}</p></div></div>`;return}
    const accounts=data.accounts||[],assets=data.assets||[],account=resolveAccount(text,accounts),asset=resolveAsset(text,assets),amount=parseAmount(text),today=w.today();
    host.innerHTML=`<div class="l142-reviewhead"><div><span class="u142-eye">Movimentação de liquidez</span><h3>${type==='redemption'?'Resgate':'Aplicação'} · revisar antes de gravar</h3><p>Confirme banco, ativo, data e valor. Nada é gravado enquanto você estiver nesta etapa.</p></div><span class="l142-pill">prévia obrigatória</span></div>
      <div class="l142-grid">
        <div class="l142-field"><label>Banco</label><select id="l142Account">${optionHtml(accounts,'institution',x=>x.institution+' · '+x.account_name,account,'Escolha a conta')}</select></div>
        <div class="l142-field"><label>Ativo</label><select id="l142Asset">${optionHtml(assets,'asset_position_id',x=>x.asset_name+' · '+x.liquidity_class,asset,'Escolha o ativo')}</select></div>
        <div class="l142-field"><label>Data</label><input id="l142Date" type="date" min="${esc(today)}" value="${esc(today)}"></div>
        <div class="l142-field"><label>Valor</label><input id="l142Amount" inputmode="decimal" placeholder="0,00" value="${amount?String(amount).replace('.',','):''}"></div>
      </div>
      <div class="l142-actions"><button class="primary" id="l142PreviewBtn">Preparar prévia</button><button id="l142CancelBtn">Cancelar</button><span class="l142-msg" id="l142State">${(!account||!asset||!amount)?'Complete os campos que não estavam explícitos na frase.':'Dados reconhecidos; confira antes de preparar a prévia.'}</span></div>
      <div id="l142Preview"></div>`;
    host.dataset.type=type;host.dataset.text=text;
    const accountSel=d.getElementById('l142Account'),assetSel=d.getElementById('l142Asset');
    if(account)accountSel.value=account.institution;if(asset)assetSel.value=asset.asset_position_id;
    d.getElementById('l142CancelBtn').onclick=()=>host.remove();
    d.getElementById('l142PreviewBtn').onclick=()=>previewLiquidity(w,d,host,data);
  }

  async function previewLiquidity(w,d,host,options){
    const state=d.getElementById('l142State'),btn=d.getElementById('l142PreviewBtn'),pv=d.getElementById('l142Preview');
    const account=d.getElementById('l142Account')?.value||'',assetId=d.getElementById('l142Asset')?.value||'',date=d.getElementById('l142Date')?.value||'',amount=brNumber(d.getElementById('l142Amount')?.value),type=host.dataset.type||'';
    const asset=(options.assets||[]).find(x=>String(x.asset_position_id)===String(assetId));
    if(!account||!assetId||!date||!amount){state.textContent='Banco, ativo, data e valor são obrigatórios.';return}
    btn.disabled=true;state.textContent='Montando prévia segura…';pv.innerHTML='';
    const input={movement_type:type,event_date:date,amount_brl:amount,account,asset_position_id:assetId,description:(type==='redemption'?'Resgate ':'Aplicação ')+(asset?.asset_name||'ativo')};
    const {data,error}=await w.S.rpc('lts_browser_preview_liquidity_movement_v1',{p_input:input});
    btn.disabled=false;
    if(error||!data){state.textContent=error?.message||'Não foi possível preparar a prévia.';return}
    host.__preview=data;state.textContent='Prévia pronta. Revise o efeito antes de confirmar.';
    const bankDelta=w.num(data.bank_delta_brl),assetDelta=w.num(data.asset_delta_brl);
    pv.innerHTML=`<div class="l142-preview"><div><span>Banco</span><b>${bankDelta>=0?'+':''}${w.brl(bankDelta)}</b></div><div><span>${esc(data.asset_name||'Ativo')}</span><b>${assetDelta>=0?'+':''}${w.brl(assetDelta)}</b></div><div><span>Saldo do ativo</span><b>${w.brl(data.asset_effective_before_brl)} → ${w.brl(data.asset_effective_after_brl)}</b></div><div><span>Efeito econômico</span><b>${w.brl(data.economic_effect_brl)}</b></div></div><div class="l142-safety">Banco e ativo são pernas iguais e opostas. Esta movimentação fica fora de receita, despesa e consumo. Nenhuma classificação financeira é inferida.</div><div class="l142-actions"><button class="gold" id="l142ApplyBtn">Confirmar ${type==='redemption'?'resgate':'aplicação'}</button><span class="l142-msg">Este clique é a aprovação explícita que autoriza a gravação.</span></div>`;
    d.getElementById('l142ApplyBtn').onclick=()=>applyLiquidity(w,d,host);
  }

  async function applyLiquidity(w,d,host){
    const pv=host.__preview;if(!pv)return;const btn=d.getElementById('l142ApplyBtn');
    const label=host.dataset.type==='redemption'?'resgate':'aplicação';
    if(!w.confirm(`Confirmar ${label} de ${w.brl(pv.amount_brl)} entre ${pv.asset_name} e ${pv.account}?\n\nIsso não será tratado como receita ou despesa.`))return;
    btn.disabled=true;btn.textContent='Confirmando…';
    const approved={...pv,approved:true};const key='liq-ui-'+(w.crypto?.randomUUID?w.crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2));
    const {data,error}=await w.S.rpc('lts_browser_apply_liquidity_movement_v1',{p_preview:approved,p_idempotency_key:key});
    if(error||!data?.ok){btn.disabled=false;btn.textContent='Tentar novamente';const state=d.getElementById('l142State');if(state)state.textContent=error?.message||'Não foi possível confirmar a movimentação.';return}
    try{const {data:p}=await w.S.rpc('lts_browser_product_v1');if(p?.mvp)w.D=p.mvp}catch(e){}
    host.className='l142-review l142-success';host.innerHTML=`<div class="l142-reviewhead"><div><span class="u142-eye">Movimentação registrada</span><h3>${label==='resgate'?'Resgate':'Aplicação'} confirmado</h3><p>${esc(pv.asset_name)} ↔ ${esc(pv.account)} · ${w.brl(pv.amount_brl)}. O efeito econômico permanece ${w.brl(0)}.</p></div><span class="l142-pill">concluído</span></div><div class="l142-safety">Fluxo, Planejamento, Dashboard, Patrimônio e cache futuro foram atualizados pelo mesmo motor efetivo de liquidez.</div>`;
    const inp=d.getElementById('u142Phrase');if(inp)inp.value='';
    setTimeout(()=>{if(w.V==='Atualizações')w.render()},1300)
  }

  function install(){
    const z=chain();if(!z)return;const w=z.w,d=z.d;ensureCss(d);
    if(!w.__lts_v142_quick_base||w.__lts_v142_quick_base===w.__lts_v142_liquidity_quick){
      if(typeof w.u142QuickInterpret==='function'&&w.u142QuickInterpret!==w.__lts_v142_liquidity_quick)w.__lts_v142_quick_base=w.u142QuickInterpret;
    }
    if(!w.__lts_v142_liquidity_quick){
      w.__lts_v142_liquidity_quick=function u142LiquidityReviewedInterpret(){
        const inp=d.getElementById('u142Phrase'),msg=d.getElementById('u142QuickMsg'),text=String(inp?.value||'').trim();if(!text)return;
        const type=movementType(text);
        if(type){if(msg)msg.textContent='Movimentação de liquidez reconhecida. Revise banco, ativo, data e valor abaixo antes de gravar.';startLiquidity(w,d,text,type);return}
        if(typeof w.__lts_v142_quick_base==='function')return w.__lts_v142_quick_base();
      }
    }
    if(w.u142QuickInterpret!==w.__lts_v142_liquidity_quick)w.u142QuickInterpret=w.__lts_v142_liquidity_quick;
    w.LTS_V142_LIQUIDITY_UI='reviewed-preview-confirm-v1';
    wired=w;
  }

  outer?.addEventListener('load',()=>setTimeout(install,160));
  setInterval(install,180);
})();
