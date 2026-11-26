'use strict';
(function(){
 const panel=document.getElementById('install'),frame=document.getElementById('wealth');
 const viewport=document.getElementById('appViewport');
 const button=document.getElementById('open'),error=document.getElementById('error'),offline=document.getElementById('offline');
 const version=document.getElementById('installVersion');
 let started=false,busy=false;
 let lookup=null, lastRelease=null, checkedAt=0;
 async function currentRelease(){
  if(lastRelease && performance.now()-checkedAt<15000)return lastRelease;
  if(lookup)return lookup;
  lookup=(async()=>{
   const initial=window.ltsEntryRequest;
   delete window.ltsEntryRequest;
   const current=await (initial || window.ltsReadRelease());
   if(!current)throw Error('Unavailable');
   const target=new URL(current.entry,location.href);
   const root=new URL('../',location.href).pathname;
   if(target.origin!==location.origin||!/^v[0-9]+$/.test(current.release)||
      target.pathname!==root+'releases/'+current.release+'/app.html'||target.search||target.hash)throw Error('Invalid release');
   const label=current.release.toUpperCase();
   if(version)version.textContent=label;
   lastRelease={target,label};checkedAt=performance.now();return lastRelease;
  })();
  try{return await lookup;}finally{lookup=null;}
 }
 const status=document.getElementById('openingStatus'),label=document.getElementById('openingLabel');
 const elapsed=document.getElementById('elapsed'),retry=document.getElementById('retryOpening');
 let clock=null;
 function stopClock(){
  clearInterval(clock);clock=null;status.hidden=true;
  document.documentElement.classList.add('opening-finished');
 }
 function markOlderBalances(doc){
  if(!doc?.head||doc.getElementById('mobileBalanceDates'))return;
  const style=doc.createElement('style');style.id='mobileBalanceDates';
  style.textContent=['341','237','336'].map(code=>{
   const row='.v337-bank:has(.bank-'+code+') > strong::after';
   return ['previous-day','aged'].map(level=>
    'body:has(.v225-freshness-bank[data-bank="'+code+'"][data-freshness="'+level+'"]) '+row+
    '{content:"'+(level==='aged'?'Saldo com 24 h ou mais':'Saldo de dia anterior')+'";display:block;font:600 12px/1.4 system-ui;color:#784711}'
   ).join('\n');
  }).join('\n')+' [data-v225-refresh][data-wait]::after{content:" · " attr(data-wait)}';
  doc.head.append(style);
  let collectionStart=null;
  doc.defaultView.setInterval(()=>{
   const control=doc.querySelector('[data-v225-refresh]');
   if(!control?.disabled){collectionStart=null;control?.removeAttribute('data-wait');return;}
   if(collectionStart===null)collectionStart=performance.now();
   control.dataset.wait=Math.floor((performance.now()-collectionStart)/1000)+' s';
  },1000);
 }
 function startClock(){
  if(clock!==null)return;
  const start=performance.now();status.hidden=false;
  function tick(){
   const seconds=Math.floor((performance.now()-start)/1000);
   const shell=frame.contentDocument?.getElementById('shell');
   const doc=shell?.contentDocument;
   if(shell&&!shell.dataset.mobileBalanceListener){
    shell.dataset.mobileBalanceListener='1';shell.addEventListener('load',()=>markOlderBalances(shell.contentDocument));
   }
   markOlderBalances(doc);
   const phase=doc?.body?.dataset.ltsBootState;
   if(phase && !['checking','loading','preparing'].includes(phase)){stopClock();return;}
   const message=navigator.onLine===false?'Sem conexão':phase==='checking'?'Verificando acesso…':phase==='loading'||phase==='preparing'?'Carregando dados…':'Abrindo Wealth…';
   if(label.textContent!==message)label.textContent=message;
   elapsed.textContent=seconds+' s';retry.hidden=seconds<20;
  }
  tick();clock=setInterval(tick,500);
 }
 retry.addEventListener('click',()=>location.reload());
 function connection(){offline.hidden=navigator.onLine!==false;if(started&&navigator.onLine!==false)open();}
 async function open(){
  if(busy||navigator.onLine===false){connectionOnly();return;}
  if(started){viewport.hidden=false;frame.hidden=false;return;}
  startClock();busy=true;button.disabled=true;error.hidden=true;
  try{
   const {target,label}=await currentRelease();
   frame.title='LTS Wealth · '+label;document.title=frame.title;
   frame.src=target.href;viewport.hidden=false;frame.hidden=false;panel.hidden=true;
   document.documentElement.classList.add('wealth-open');document.body.classList.add('wealth-open');started=true;
  }catch(_){stopClock();panel.hidden=false;viewport.hidden=true;frame.hidden=true;error.hidden=false;}
  finally{busy=false;button.disabled=false;}
 }
 function connectionOnly(){offline.hidden=navigator.onLine!==false;}
 button.addEventListener('click',open);
 window.addEventListener('offline',connectionOnly);window.addEventListener('online',connection);
 connectionOnly();
 if(window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true)open();
 else if(navigator.onLine!==false)currentRelease().catch(()=>{});
})();
