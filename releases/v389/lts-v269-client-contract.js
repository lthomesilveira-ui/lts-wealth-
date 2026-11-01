/* Presentation negotiation only. Existing authentication and ownership checks are unchanged. */
(function(root){
 'use strict';
 const previous=root.fetch.bind(root),origin='https://tadhkamnwtsbdozwkyut.supabase.co',capability='lts-wealth-v269-c6-completeness';
 const prepared=new Set(['lts_browser_flow_v242','lts_browser_card_cycles_v226','lts_browser_card_cycles_v229','lts_browser_card_detail_v226','lts_browser_product_v1']);
 let stateKnown=false,incomplete=false,sequence=0,accepted=0,acceptedEpoch=-1,acceptedRevision=null;
 root.__LTS_V269_COMPLETENESS=()=>({known:stateKnown,incomplete});
 root.fetch=async function(input,init){
  let url;try{url=new URL(typeof input==='string'?input:input?.url||String(input),root.location?.href);}catch{return previous(input,init);}
  if(url.origin!==origin||!url.pathname.startsWith('/rest/v1/rpc/'))return previous(input,init);
  let reader=url.pathname.split('/').pop();
  if(['lts_browser_flow_v3','lts_browser_flow_v4','lts_browser_flow_v241'].includes(reader)){reader='lts_browser_flow_v242';url.pathname='/rest/v1/rpc/'+reader;}
  if(!prepared.has(reader))return previous(input,init);
  const headers=new Headers(input instanceof Request?input.headers:undefined);
  new Headers(init?.headers).forEach((v,k)=>headers.set(k,v));headers.set('x-client-info',capability);
  const target=input instanceof Request?new Request(url.href,input):url.href;
  const issued=++sequence,response=await previous(target,{...init,headers});
  if(response.ok){
   try{const data=await response.clone().json();const uncertain=data.complete===false||data.mvp?.complete===false;const globalRead=['lts_browser_product_v1','lts_browser_flow_v242'].includes(reader);const epoch=Number.isFinite(data.source_epoch)?data.source_epoch:null;const canRecover=!incomplete||(data.source_complete===true&&typeof data.source_revision==='string'&&epoch!==null&&epoch>=acceptedEpoch);if(uncertain||(globalRead&&issued>=accepted&&canRecover)){accepted=Math.max(accepted,issued);if(epoch!==null)acceptedEpoch=Math.max(acceptedEpoch,epoch);const changed=uncertain&&(!incomplete||(data.source_revision&&data.source_revision!==acceptedRevision));if(data.source_revision)acceptedRevision=data.source_revision;stateKnown=true;incomplete=uncertain;if(changed)root.document?.querySelectorAll('dialog[open],#v178Drawer').forEach(x=>{if(x.close)x.close();else x.remove()});root.__LTS_V269_RECHECK?.();}}catch{}
  }
  return response;
 };
 root.__LTS_V269_PRESENTATION={installed:true,capability,prepared:[...prepared],authentication_changed:false};
})(window);
