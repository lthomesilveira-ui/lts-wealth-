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
    if(desc&&!desc.configurable&&desc.get?.__ltsV143Owner)return true;
    if(desc&&!desc.configurable)return false;
    const getter=function(){return value};getter.__ltsV143Owner=true;
    try{
      Object.defineProperty(w,name,{configurable:true,enumerable:true,get:getter,set(){}});
      return w[name]===value;
    }catch(e){return false}
  }
  function install(){
    const z=deep();if(!z||!z.w)return;
    const w=z.w;
    if(!w.__v143Dashboard||!w.__v143Planning||!w.__v143Expenses||!w.__v143Cards||!w.__v143Wealth||!w.__v143Nav)return;
    const status={
      dashboard:own(w,'dashboard',w.__v143Dashboard),
      planning:own(w,'planejamento',w.__v143Planning),
      expenses:own(w,'despesas',w.__v143Expenses),
      cards:own(w,'cartoes',w.__v143Cards),
      wealth:own(w,'patrimonio',w.__v143Wealth),
      nav:own(w,'renderNav',w.__v143Nav)
    };
    w.LTS_V143_OWNERSHIP='stable-configurable-accessors-v1';
    w.__LTS_V143_OWNERSHIP_STATUS=status;
    try{if(w.renderNav===w.__v143Nav)w.renderNav()}catch(e){}
  }
  outer?.addEventListener('load',()=>{setTimeout(install,650);setTimeout(install,1600)});
  setInterval(install,180);
  setTimeout(install,950);
})();
