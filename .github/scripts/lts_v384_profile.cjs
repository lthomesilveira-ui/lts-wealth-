'use strict';
// Synthetic diagnostics only: preserve the same reads, admission budget and responses.
const {setup,open}=require('./lts_v382_browser.cjs');
const {webkit}=require('playwright'),fs=require('node:fs');
const out='qa/v384-performance';fs.mkdirSync(out,{recursive:true});
const rpcDelay=name=>/review_queue/.test(name)?500:/wealth_detail/.test(name)?380:/recurring_future/.test(name)?324:/monthly/.test(name)?251:/product_/.test(name)?208:/flow_v/.test(name)?218:/expenses_/.test(name)?159:/dashboard_cockpit/.test(name)?141:/card_cycles/.test(name)?103:10;
(async()=>{
 const browser=await webkit.launch({headless:true});
 try{for(const release of ['v383','v384']){
  const h=await setup(browser,393,852,'2026-10-31T15:00:00Z'),start=performance.now(),events=[],states=[];
  for(const event of ['request','response'])h.page.on(event,item=>{
   const req=event==='response'?item.request():item,url=new URL(req.url());
   events.push({at:Math.round(performance.now()-start),event,path:url.pathname,type:req.resourceType()});
  });
  await h.ctx.route('**/*',async route=>{
   const req=route.request(),url=new URL(req.url()),delay=url.pathname.startsWith('/rest/v1/rpc/')?rpcDelay(url.pathname.split('/').pop()):['script','stylesheet'].includes(req.resourceType())?120:0;
   if(delay)await new Promise(resolve=>setTimeout(resolve,delay));return route.fallback();
  });
  let sampling=false,last='';
  const timer=setInterval(async()=>{
   if(sampling)return;sampling=true;
   try{
    const frame=h.page.frames().find(f=>f.url().includes('/releases/'+release+'/index.html'));
    if(frame){const value=await frame.evaluate(()=>({boot:document.body?.dataset.ltsBootState,view:typeof V==='undefined'?null:V,executive:window.__LTS_DASHBOARD_EXECUTIVE_STATUS,dashboard:window.__LTS_V168_STATE?.dashboard,month:window.__LTS_V337_MONTH?.state?.status,reads:document.documentElement.getAttribute('data-lts-v227-reads')}));
     // Exclude fixture payloads; retain state transitions and transport metadata.
     if(value.dashboard)value.dashboard={loading:value.dashboard.loading,started:value.dashboard.started,pending:value.dashboard.pending,detailErrors:value.dashboard.detailErrors};
     const key=JSON.stringify(value);if(key!==last){states.push({at:Math.round(performance.now()-start),...value});last=key;}
    }
   }catch{}finally{sampling=false;}
  },100);
  try{await open(h,release,false);const result={release,elapsed:Math.round(performance.now()-start),events,states,errors:h.errors,read_count:h.reads.length};fs.writeFileSync(out+'/'+release+'-profile.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}
  finally{clearInterval(timer);await h.ctx.close();}
 }}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
