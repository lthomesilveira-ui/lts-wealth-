(function(){
  const MARK='stable-nav-no-recreate-v1';
  const w=window,d=document;
  const ITEMS=[['Dashboard','Dashboard'],['Atualizações','Atualizações'],['Fluxo Diário','Fluxo Diário'],['Despesas','Despesas'],['Cartões','Cartões'],['Patrimônio','Patrimônio'],['Planejamento','Liquidez detalhada']];
  let stable=null,tries=0,done=false;

  function buildStableNav(){
    function v146StableNav(){
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
        b.classList.toggle('active',w.V===dest);
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

  function bindCapture(){
    if(d.__LTS_V146_NAV_CAPTURE_BOUND)return;
    d.__LTS_V146_NAV_CAPTURE_BOUND=true;
    d.addEventListener('click',e=>{
      const b=e.target?.closest?.('.nav [data-v143-dest]');if(!b)return;
      const dest=b.dataset.v143Dest;if(!dest)return;
      e.preventDefault();e.stopImmediatePropagation();
      w.V=dest;
      try{stable?.();w.render()}catch(err){}
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

  function install(){
    if(!('V' in w)||typeof w.render!=='function'||typeof w.__v143Nav!=='function')return false;
    if(!stable)stable=buildStableNav();
    const pointerLocked=lockPointer('__v143Nav',stable);
    if(!pointerLocked)return false;
    w.__lts_v142_dashboard_nav=stable;
    try{w.renderNav=stable}catch(e){}
    bindCapture();
    stable();
    const domLocked=lockNavDom();
    if(!domLocked)return false;
    stable();
    w.LTS_V146_NAV_STABILITY=MARK;
    w.__LTS_V146_NAV_STATUS={
      installed:true,
      stable_pointer:w.__v143Nav===stable,
      render_nav_stable:w.renderNav===stable,
      dom_locked:!!d.querySelector('.nav')?.__LTS_V146_NAV_DOM_LOCKED,
      blocked_writes:w.__LTS_V146_NAV_BLOCKED_WRITES||0,
      permanent_polling:false,
      nav_nodes:Array.from(d.querySelectorAll('.nav button[data-v143-dest]')).length
    };
    if(w.__LTS_V146_UPDATES_STATUS)w.__LTS_V146_UPDATES_STATUS.navigation_owner='v146-stable-nav';
    return w.__v143Nav===stable&&w.renderNav===stable&&domLocked;
  }

  function boot(){
    if(done)return;
    if(install()){done=true;return}
    tries++;
    if(tries<160)setTimeout(boot,50);
  }
  setTimeout(boot,40);
})();
