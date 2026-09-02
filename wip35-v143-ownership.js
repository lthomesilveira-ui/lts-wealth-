(function(){
  const outer=document.getElementById('shell');
  function deep(){
    try{
      let d=document,w=window,f=outer;
      for(let i=0;i<11;i++){
        if(!f)return null;
        d=f.contentDocument;w=f.contentWindow;
        if(!d||!w)return null;
        const app=d.getElementById('app');
        if(app&&app.contentWindow&&app.contentDocument)return {w:app.contentWindow,d:app.contentDocument};
        f=d.getElementById('shell');
      }
    }catch(e){}
    return null;
  }
  function own(w,name,value){
    if(typeof value!=='function')return false;
    const desc=Object.getOwnPropertyDescriptor(w,name);
    if(desc&&!desc.configurable)return w[name]===value;
    const getter=function(){return value};getter.__ltsV143Owner=true;
    try{
      Object.defineProperty(w,name,{configurable:true,enumerable:true,get:getter,set(){}});
      return w[name]===value;
    }catch(e){return w[name]===value}
  }
  function redirectInheritedOwners(w){
    /*
      v142 layers intentionally run health/ownership loops. Rather than racing them,
      point their own desired renderers at v143. This keeps the inherited fallback
      machinery alive while making the newest candidate the deterministic owner.
    */
    w.__lts_v142_dashboard_fn=w.__v143Dashboard;
    w.__lts_v142_dashboard_nav=w.__v143Nav;
    w.__lts_v142_planning_fn=w.__v143Planning;
    w.__LTS_V142_PLANNING_RENDERER=w.__v143Planning;
    w.__lts_v142_wealth_fn=w.__v143Wealth;
  }
  function install(){
    const z=deep();if(!z||!z.w)return;
    const w=z.w;
    if(!w.__v143Dashboard||!w.__v143Planning||!w.__v143Expenses||!w.__v143Cards||!w.__v143Wealth||!w.__v143Nav)return;
    redirectInheritedOwners(w);
    try{w.dashboard=w.__v143Dashboard}catch(e){}
    try{w.planejamento=w.__v143Planning}catch(e){}
    try{w.despesas=w.__v143Expenses}catch(e){}
    try{w.cartoes=w.__v143Cards}catch(e){}
    try{w.patrimonio=w.__v143Wealth}catch(e){}
    try{w.renderNav=w.__v143Nav}catch(e){}
    const status={
      dashboard:own(w,'dashboard',w.__v143Dashboard),
      planning:own(w,'planejamento',w.__v143Planning),
      expenses:own(w,'despesas',w.__v143Expenses),
      cards:own(w,'cartoes',w.__v143Cards),
      wealth:own(w,'patrimonio',w.__v143Wealth),
      nav:own(w,'renderNav',w.__v143Nav),
      inherited_dashboard_redirect:w.__lts_v142_dashboard_fn===w.__v143Dashboard,
      inherited_nav_redirect:w.__lts_v142_dashboard_nav===w.__v143Nav,
      inherited_planning_redirect:w.__lts_v142_planning_fn===w.__v143Planning&&w.__LTS_V142_PLANNING_RENDERER===w.__v143Planning,
      inherited_wealth_redirect:w.__lts_v142_wealth_fn===w.__v143Wealth
    };
    w.LTS_V143_OWNERSHIP='redirect-inherited-owners-v2';
    w.__LTS_V143_OWNERSHIP_STATUS=status;
    try{if(w.renderNav===w.__v143Nav)w.renderNav()}catch(e){}
  }
  outer?.addEventListener('load',()=>{setTimeout(install,450);setTimeout(install,900);setTimeout(install,1600)});
  setInterval(install,45);
  setTimeout(install,650);
})();
