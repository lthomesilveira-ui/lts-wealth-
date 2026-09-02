(function(){
  const MARK='v144-lexical-state-bridge-v1';
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
  function install(){
    const z=deep();if(!z)return;
    if(z.w.LTS_V144_LEXICAL_BRIDGE===MARK)return;
    const s=z.d.createElement('script');
    s.textContent=`(function(){try{
      const d0=Object.getOwnPropertyDescriptor(window,'D');
      if(!d0||d0.configurable)Object.defineProperty(window,'D',{configurable:true,enumerable:false,get(){return D},set(v){D=v}});
      const v0=Object.getOwnPropertyDescriptor(window,'V');
      if(!v0||v0.configurable)Object.defineProperty(window,'V',{configurable:true,enumerable:false,get(){return V},set(v){V=v}});
      window.LTS_V144_LEXICAL_BRIDGE='${MARK}';
    }catch(e){console.error('v144 lexical bridge failed',e)}})();`;
    (z.d.head||z.d.documentElement).appendChild(s);s.remove();
  }
  setInterval(install,80);setTimeout(install,40);
})();
