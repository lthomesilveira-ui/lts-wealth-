(function(){
  const outer=document.getElementById('shell');
  const MARK='single-refresh-title-stable-v1';
  const FINAL_TITLE='Sua vida financeira, em uma tela.';
  const FINAL_SUBTITLE='Tenho dinheiro hoje? O que exige ação? Para onde estou indo?';
  let tries=0,done=false;

  function deep(){
    try{
      let d=document,w=window;
      for(let i=0;i<12;i++){
        const frames=Array.from(d.querySelectorAll('iframe'));
        if(!frames.length)break;
        const next=frames.find(x=>x.id==='shell'||x.id==='app')||frames[0];
        if(!next||!next.contentDocument||!next.contentWindow)break;
        d=next.contentDocument;w=next.contentWindow;
      }
      if(d&&w&&typeof w.render==='function'&&typeof w.atualizacoes==='function')return {w,d};
    }catch(e){}
    return null;
  }

  function stableRenderer(base){
    function v145StableDashboard(){
      const html=base();
      if(typeof html!=='string')return html;
      return html
        .replace('O que você tem hoje e o que precisa fazer depois.',FINAL_TITLE)
        .replace('Caixa, riscos próximos e decisões em linguagem de uso real.',FINAL_SUBTITLE);
    }
    v145StableDashboard.__ltsV145Stable=true;
    v145StableDashboard.__ltsV145Base=base;
    return v145StableDashboard;
  }

  function own(w,name,value){
    if(typeof value!=='function')return false;
    const desc=Object.getOwnPropertyDescriptor(w,name);
    if(desc&&!desc.configurable)return w[name]===value;
    try{
      Object.defineProperty(w,name,{configurable:true,enumerable:true,get(){return value},set(){}});
      return w[name]===value;
    }catch(e){return false}
  }

  function lockLegacyDashboardPoll(w){
    const desc=Object.getOwnPropertyDescriptor(w,'__LTS_V142_DASHBOARD_LOADING');
    if(desc&&!desc.configurable)return desc.get?desc.get.call(w)===true:w.__LTS_V142_DASHBOARD_LOADING===true;
    try{
      Object.defineProperty(w,'__LTS_V142_DASHBOARD_LOADING',{
        configurable:true,enumerable:false,get(){return true},set(){}
      });
      return w.__LTS_V142_DASHBOARD_LOADING===true;
    }catch(e){return false}
  }

  async function refreshOnce(w){
    if(w.__LTS_V145_DASHBOARD_REFRESHING||!w.D||!w.S||typeof w.S.rpc!=='function')return false;
    w.__LTS_V145_DASHBOARD_REFRESHING=true;
    try{
      const {data,error}=await w.S.rpc('lts_browser_dashboard_cockpit_v1');
      if(error||!data)throw Error(error?.message||'Dashboard indisponível');
      w.D.dashboard_cockpit=data;
      w.LTS_DASHBOARD_COCKPIT='v145-single-refresh';
      if(w.V==='Dashboard')w.render();
      return true;
    }catch(e){
      w.__LTS_V145_DASHBOARD_REFRESH_ERROR=String(e?.message||e);
      return false;
    }finally{
      w.__LTS_V145_DASHBOARD_REFRESHING=false;
    }
  }

  function normalizeCurrentHead(w,d){
    if(w.V!=='Dashboard')return;
    const h=d.querySelector('.v143-head h1'),p=d.querySelector('.v143-head p');
    if(h&&h.textContent!==FINAL_TITLE)h.textContent=FINAL_TITLE;
    if(p&&p.textContent!==FINAL_SUBTITLE)p.textContent=FINAL_SUBTITLE;
  }

  function install(){
    const z=deep();if(!z||!z.w||!z.d)return false;
    const {w,d}=z;
    if(w.LTS_V144_LEXICAL_BRIDGE!=='v144-lexical-state-bridge-v1')return false;
    if(!w.D?.dashboard_cockpit?.version||typeof w.__v143Dashboard!=='function')return false;

    if(!w.__v143Dashboard.__ltsV145Stable)w.__v143Dashboard=stableRenderer(w.__v143Dashboard);
    const stable=w.__v143Dashboard;
    w.__lts_v142_dashboard_fn=stable;
    own(w,'dashboard',stable);
    const legacyPollLocked=lockLegacyDashboardPoll(w);

    w.LTS_V145_REFRESH_DASHBOARD=()=>refreshOnce(w);
    w.LTS_V145_DASHBOARD_STABILITY=MARK;
    w.__LTS_V145_DASHBOARD_STABILITY_STATUS={
      legacy_poll_locked:legacyPollLocked,
      stable_renderer:!!stable.__ltsV145Stable,
      final_title:FINAL_TITLE
    };
    normalizeCurrentHead(w,d);
    return legacyPollLocked&&w.dashboard===stable;
  }

  function boot(){
    if(done)return;
    if(install()){done=true;return}
    tries++;
    if(tries<120)setTimeout(boot,100);
  }

  outer?.addEventListener('load',()=>setTimeout(boot,120));
  setTimeout(boot,80);
})();
