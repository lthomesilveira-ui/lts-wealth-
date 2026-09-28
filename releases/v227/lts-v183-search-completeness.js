/* Candidate-only complete history search. No changes to source rows or writers. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_SEARCH_COMPLETE)return;
  const previous=S.rpc.bind(S),search=window.__LTS_V168_STATE.search;
  function matches(name,args){return name==='lts_browser_transactions_v2'&&args?.p_from==='2013-10-10'&&args.p_to===null&&typeof args.p_query==='string'&&args.p_query.trim()!==''&&args.p_direction===null&&args.p_account===null&&args.p_limit===200&&args.p_offset===0}
  S.rpc=async function(name,args){
   if(!matches(name,args))return previous(name,args);
   const seq=search.seq,query=args.p_query,rows=[],keys=new Set();let expected=null,first=null;
   const current=()=>search.seq===seq&&String(search.query||'').trim()===query.trim();
   try{
    for(let offset=0;offset<10000;offset+=200){
     if(!current())throw Error('Busca substituída.');
     const result=await previous(name,{...args,p_offset:offset});
     if(!current())throw Error('Busca substituída.');
     if(result.error||!result.data)throw Error(result.error?.message||'Busca indisponível.');
     const page=result.data,total=Number(page.total);
     if(page.total==null||!Number.isSafeInteger(total)||total<0||!Array.isArray(page.rows))throw Error('Resposta incompleta. Tente buscar novamente.');
     if(total>10000)throw Error('Há mais de 10.000 resultados. Refine a busca; nenhum resultado parcial foi exibido.');
     if(expected===null){expected=total;first=page}else if(expected!==total)throw Error('Os resultados mudaram durante a busca. Busque novamente.');
     if(page.rows.length!==Math.min(200,expected-offset))throw Error('Página incompleta. Busque novamente; nenhum resultado parcial foi exibido.');
     for(const row of page.rows){
      const key=JSON.stringify([row.source,row.source_ref,row.date,row.amount]);
      if(keys.has(key))throw Error('Resultados repetidos durante a busca. Busque novamente.');
      keys.add(key);rows.push(row);
     }
     if(rows.length===expected)return {data:{...first,rows,total:expected,offset:0,limit:rows.length,complete:true},error:null};
    }
    throw Error('Busca incompleta. Refine os termos.');
   }catch(error){return {data:null,error:{message:String(error?.message||error)}}}
  };
  window.__LTS_V183_SEARCH_COMPLETE={installed:true,read_only:true};
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V183_INCOME_REVIEW?.installed)return false;if(w.__LTS_V183_SEARCH_COMPLETE)return true;const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V183_SEARCH_COMPLETE}catch{return false}}
 function burst(){let count=0;const timer=setInterval(()=>{if(install()||++count>160)clearInterval(timer)},150)}
 shell?.addEventListener('load',burst);burst();
})();
