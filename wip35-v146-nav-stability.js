(function(){
  const MARK='stable-nav-no-recreate-v1';
  const CLICK_RENDER_YIELD_MS=80;
  const w=window,d=document;
  const ITEMS=[['Dashboard','Dashboard'],['Atualizações','Atualizações'],['Fluxo Diário','Fluxo Diário'],['Despesas','Despesas'],['Cartões','Cartões'],['Patrimônio','Patrimônio'],['Planejamento','Liquidez detalhada']];
  let stable=null,tries=0,done=false,renderToken=0;

  function buildStableNav(){
    function v146StableNav(activeDest=w.V){
      const N=d.querySelector('.nav');if(!N)return;
      let buttons=Array.from(N.querySelectorAll('button[data-v143-dest]'));
      const shapeOk=buttons.length===ITEMS.length&&ITEMS.every(([dest,label],i)=>buttons[i]&&buttons[i].dataset.v143Dest===dest&&String(buttons[i].textContent||'').trim()===label);
      if(!shapeOk&&!N.__LTS_V146_NAV_DOM_LOCKED){
        const frag=d.createDocumentFragment();
        ITEMS.forEach(([dest,label])=>{const b=d.createElement('button');b.type='button';b.dataset.v143Dest=dest;b.textContent=label;frag.appendChild(b)});
        N.replaceChildren(frag);
        buttons=Array.from(N.querySelectorAll('button[data-v143-dest]'));
      }
      buttons.forEach((b,i)=>{
        const item=ITEMS[i];if(!item)return;
        const [dest,label]=item;
        if(String(b.textContent||'').trim()!==label)b.textContent=label;
        b.classList.toggle('active',activeDest===dest);
        b.classList.remove('minor');
      });
    }
    v146StableNav.__ltsV146StableNav=true;
    v146StableNav.__ltsV146NoRecreate=true;
    return v146StableNav;
  }

  function lockNavDom(){
    const N=d.querySelector('.nav');if(!N)return false;
    if(N.__LTS_V146_NAV_DOM_LOCKED)return true;
    const htmlDesc=Object.getOwnPropertyDescriptor(Element.prototype,'innerHTML');
    const nativeReplace=N.replaceChildren.bind(N);
    const block=kind=>{
      w.__LTS_V146_NAV_BLOCKED_WRITES=(w.__LTS_V146_NAV_BLOCKED_WRITES||0)+1;
      w.__LTS_V146_NAV_LAST_BLOCKED_WRITE=kind;
    };
    if(htmlDesc?.get&&htmlDesc?.set){
      try{
        Object.defineProperty(N,'innerHTML',{
          configurable:false,
          enumerable:false,
          get(){return htmlDesc.get.call(N)},
          set(value){
            if(!N.__LTS_V146_NAV_DOM_LOCKED)return htmlDesc.set.call(N,value);
            block('innerHTML');
          }
        });
      }catch(e){return false}
    }
    try{
      Object.defineProperty(N,'replaceChildren',{
        configurable:false,
        enumerable:false,
        writable:false,
        value:function(...args){
          if(!N.__LTS_V146_NAV_DOM_LOCKED)return nativeReplace(...args);
          block('replaceChildren');
        }
      });
    }catch(e){return false}
    N.__LTS_V146_NAV_DOM_LOCKED=true;
    return true;
  }

  function scheduleNavigation(dest){
    const token=++renderToken;
    w.__LTS_V146_NAV_PENDING_DEST=dest;
    w.__LTS_V146_NAV_RENDER_SCHEDULED_AT=performance.now();
    setTimeout(()=>{
      if(token!==renderToken)return;
      w.__LTS_V146_NAV_PENDING_DEST=null;
      w.V=dest;
      try{stable?.(dest)}catch(err){}
      w.__LTS_V146_NAV_RENDER_STARTED_AT=performance.now();
      try{w.render()}catch(err){w.__LTS_V146_NAV_RENDER_ERROR=String(err?.message||err)}
      finally{w.__LTS_V146_NAV_RENDER_FINISHED_AT=performance.now()}
    },CLICK_RENDER_YIELD_MS);
  }

  function bindCapture(){
    if(d.__LTS_V146_NAV_CAPTURE_BOUND)return;
    d.__LTS_V146_NAV_CAPTURE_BOUND=true;
    d.addEventListener('click',e=>{
      const b=e.target?.closest?.('.nav [data-v143-dest]');if(!b)return;
      const dest=b.dataset.v143Dest;if(!dest)return;
      e.preventDefault();e.stopImmediatePropagation();
      w.__LTS_V146_NAV_LAST_CLICK_CAPTURE_AT=performance.now();
      try{stable?.(dest)}catch(err){}
      scheduleNavigation(dest);
      w.__LTS_V146_NAV_LAST_CLICK_RETURN_AT=performance.now();
    },true);
  }

  function lockPointer(name,value){
    const desc=Object.getOwnPropertyDescriptor(w,name);
    if(!desc||desc.configurable){
      try{Object.defineProperty(w,name,{configurable:false,enumerable:true,writable:false,value});return w[name]===value}catch(e){return false}
    }
    if(desc.writable){try{w[name]=value}catch(e){}}
    return w[name]===value;
  }

  function bindWealthRetry(){
    if(d.__LTS_V146_WEALTH_RETRY_BOUND)return;
    d.__LTS_V146_WEALTH_RETRY_BOUND=true;
    d.addEventListener('click',e=>{
      const b=e.target?.closest?.('[data-v146-wealth-retry]');if(!b)return;
      e.preventDefault();e.stopImmediatePropagation();
      const st=w.__V143_WEALTH;
      if(st){st.error=null;st.loading=false;st.data=null}
      try{w.render()}catch(err){w.__LTS_V146_WEALTH_RETRY_ERROR=String(err?.message||err)}
    },true);
  }

  function stabilizeWealthOwner(){
    if(!w.__V146_WEALTH_BASE){
      if(typeof w.__v143Wealth!=='function')return false;
      w.__V146_WEALTH_BASE=w.__v143Wealth;
    }
    if(!w.__V146_WEALTH_GUARD){
      const base=w.__V146_WEALTH_BASE;
      const guard=function v146WealthGuard(){
        const st=w.__V143_WEALTH;
        if(st?.error&&!st?.data&&!st?.loading){
          return '<div class="v143-loading"><b>Não foi possível carregar Patrimônio.</b><div style="margin-top:6px">A tela não entra em repetição automática quando o serviço falha. Tente novamente quando quiser.</div><button type="button" class="v143-btn" data-v146-wealth-retry style="margin-top:10px">Tentar novamente</button></div>';
        }
        return base();
      };
      guard.__ltsV146WealthRetryGuard=true;
      w.__V146_WEALTH_GUARD=guard;
    }
    const current=w.__V146_WEALTH_GUARD;
    try{w.__v143Wealth=current}catch(e){}
    const ownerLocked=lockPointer('__lts_v142_wealth_fn',current);
    if(!ownerLocked)return false;
    try{w.patrimonio=current}catch(e){}
    const st=w.__lts_v142_wealth_state||(w.__lts_v142_wealth_state={loading:false,loaded:false,data:null,error:null});
    st.loading=false;
    st.loaded=true;
    st.retired_by_v146=true;
    bindWealthRetry();
    w.__LTS_V146_WEALTH_OWNER_STATUS={
      v143_guard_installed:w.__v143Wealth===current,
      v142_owner_redirected:w.__lts_v142_wealth_fn===current,
      patrimonio_current:w.patrimonio===current,
      legacy_loader_retired:st.retired_by_v146===true,
      retry_guard:true,
      active_renderer:'v146WealthGuard→v143Wealth'
    };
    return w.__v143Wealth===current&&w.__lts_v142_wealth_fn===current&&w.patrimonio===current&&st.retired_by_v146===true;
  }

  function install(){
    if(!('V' in w)||typeof w.render!=='function'||typeof w.__v143Nav!=='function'||typeof w.__v143Wealth!=='function')return false;
    if(!stable)stable=buildStableNav();
    const pointerLocked=lockPointer('__v143Nav',stable);
    if(!pointerLocked)return false;
    w.__lts_v142_dashboard_nav=stable;
    try{w.renderNav=stable}catch(e){}
    const wealthStable=stabilizeWealthOwner();
    if(!wealthStable)return false;
    bindCapture();
    stable(w.V);
    const domLocked=lockNavDom();
    if(!domLocked)return false;
    stable(w.V);
    w.LTS_V146_NAV_STABILITY=MARK;
    w.__LTS_V146_NAV_STATUS={
      installed:true,
      stable_pointer:w.__v143Nav===stable,
      render_nav_stable:w.renderNav===stable,
      dom_locked:!!d.querySelector('.nav')?.__LTS_V146_NAV_DOM_LOCKED,
      blocked_writes:w.__LTS_V146_NAV_BLOCKED_WRITES||0,
      click_render_mode:'visual-active-immediate-state-and-render-coalesced-80ms',
      click_render_yield_ms:CLICK_RENDER_YIELD_MS,
      state_commit_deferred:true,
      wealth_owner_stable:wealthStable,
      wealth_retry_guard:w.__LTS_V146_WEALTH_OWNER_STATUS?.retry_guard===true,
      legacy_v142_wealth_loader_retired:w.__LTS_V146_WEALTH_OWNER_STATUS?.legacy_loader_retired===true,
      permanent_polling:false,
      nav_nodes:Array.from(d.querySelectorAll('.nav button[data-v143-dest]')).length
    };
    if(w.__LTS_V146_UPDATES_STATUS)w.__LTS_V146_UPDATES_STATUS.navigation_owner='v146-stable-nav';
    return w.__v143Nav===w.__V146_WEALTH_GUARD&&w.__v143Nav===stable?false:w.__v143Nav===stable&&w.renderNav===stable&&domLocked&&wealthStable;
  }

  function boot(){
    if(done)return;
    if(install()){done=true;return}
    tries++;
    if(tries<160)setTimeout(boot,50);
  }
  setTimeout(boot,40);
})();
