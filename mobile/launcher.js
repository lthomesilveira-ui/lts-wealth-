'use strict';
(function(){
 const panel=document.getElementById('install'),frame=document.getElementById('wealth');
 const button=document.getElementById('open'),error=document.getElementById('error'),offline=document.getElementById('offline');
 let started=false,busy=false;
 function connection(){offline.hidden=navigator.onLine!==false;if(started&&navigator.onLine!==false)open();}
 async function open(){
  if(busy||navigator.onLine===false){connectionOnly();return;}
  if(started){frame.hidden=false;return;}
  busy=true;button.disabled=true;error.hidden=true;
  try{
   const response=await fetch('current.json',{cache:'no-store',credentials:'same-origin'});
   if(!response.ok)throw Error('Unavailable');
   const current=await response.json(),target=new URL(current.entry,location.href);
   const root=new URL('../',location.href).pathname;
   if(target.origin!==location.origin||!/^v[0-9]+$/.test(current.release)||
      target.pathname!==root+'releases/'+current.release+'/app.html'||target.search||target.hash)throw Error('Invalid release');
   frame.src=target.href;frame.hidden=false;panel.hidden=true;started=true;
  }catch(_){panel.hidden=false;frame.hidden=true;error.hidden=false;}
  finally{busy=false;button.disabled=false;}
 }
 function connectionOnly(){offline.hidden=navigator.onLine!==false;}
 button.addEventListener('click',open);
 window.addEventListener('offline',connectionOnly);window.addEventListener('online',connection);
 connectionOnly();
 if(window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true)open();
})();
