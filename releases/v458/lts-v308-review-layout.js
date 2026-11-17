/* Compact projection review. Uses the existing rendered periods; no data reader or writer. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V308_REVIEW_LAYOUT)return;
  const previousRender=render,expanded=new Set(),filters=new Map();
  let generation;
  function scope(){
   const current=typeof BOOT==='object'?BOOT.generation:D;
   if(current!==generation){generation=current;expanded.clear();filters.clear();}
   return document.getElementById('v237CoverageYear')?.value||'';
  }
  function compact(){
   const year=scope(),card=document.getElementById('v237CoverageAudit');
   if(!card||card.dataset.compactReview==='true')return;
   card.dataset.compactReview='true';
   const rows=[...card.querySelectorAll('[data-coverage-key]')];
   if(!rows.length)return;
   const toolbar=document.createElement('div');toolbar.className='lts-coverage-toolbar';
   const label=document.createElement('label');label.textContent='Mostrar ';
   const select=document.createElement('select');select.className='v168-btn';select.setAttribute('aria-label','Filtrar séries de projeção');
   for(const [value,text] of [['issues','Pendências do ano'],['all','Todas as séries'],['gap','Com meses sem previsão'],['awaiting','Com pagamento a confirmar']]){
    const option=document.createElement('option');option.value=value;option.textContent=text;select.appendChild(option);
   }
   select.value=filters.get(year)||'issues';label.appendChild(select);toolbar.appendChild(label);
   const count=document.createElement('span');count.className='lts-coverage-count';count.setAttribute('role','status');count.setAttribute('aria-live','polite');toolbar.appendChild(count);
   const list=card.querySelector('.v168-actions');list.before(toolbar);
   const empty=document.createElement('p');empty.className='v168-empty lts-coverage-empty';empty.textContent='Nenhuma série corresponde ao filtro neste ano.';empty.hidden=true;list.after(empty);
   for(const row of rows){
    const periods=row.querySelector('.v268-periods');if(!periods)continue;
    const key=year+'|'+row.dataset.coverageKey,details=document.createElement('details');details.className='lts-coverage-months';
    const summary=document.createElement('summary');summary.textContent='Ver períodos de '+year;details.appendChild(summary);
    const reference=periods.nextElementSibling;
    periods.before(details);details.appendChild(periods);
    if(reference?.tagName==='SMALL')details.appendChild(reference);
    details.dataset.coverageScope=key;details.open=expanded.has(key);
    const rowGeneration=generation;
    details.ontoggle=()=>{if(rowGeneration!==generation)return;if(details.open)expanded.add(key);else expanded.delete(key);};
   }
   function applyFilter(){
    const filter=select.value;filters.set(year,filter);let visible=0;
    for(const row of rows){
     const matches=filter==='all'||(filter==='issues'?!!row.querySelector('[data-period-state="gap"],[data-period-state="awaiting"],[data-period-state="unknown"]'):!!row.querySelector('[data-period-state="'+filter+'"]'));
     row.hidden=!matches;if(matches)visible++;
    }
    count.textContent=visible+' de '+rows.length+' séries · '+year;empty.hidden=visible!==0;
   }
   select.onchange=applyFilter;applyFilter();
  }
  const style=document.createElement('style');style.id='lts-v308-review-style';
  style.textContent=`
   #v237CoverageAudit .lts-coverage-toolbar{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:16px 0 8px}
   #v237CoverageAudit .lts-coverage-toolbar label{display:flex;align-items:center;flex-wrap:wrap;gap:8px;min-width:0;font-size:12px;color:#526174}
   #v237CoverageAudit .lts-coverage-toolbar select{max-width:100%;min-height:44px;background:#fff}
   #v237CoverageAudit .lts-coverage-count{font-size:12px;color:#526174;font-variant-numeric:tabular-nums}
   #v237CoverageAudit [data-coverage-key]{padding:14px 16px;gap:12px;border-bottom:1px solid #e6ebf1}
   #v237CoverageAudit [data-coverage-key][hidden]{display:none!important}
   #v237CoverageAudit [data-coverage-key]>div>small{margin-top:5px;line-height:1.5;overflow-wrap:anywhere}
   #v237CoverageAudit .lts-coverage-months{margin-top:8px;border:0;background:transparent;padding:0}
   #v237CoverageAudit .lts-coverage-months>summary{cursor:pointer;display:list-item;min-height:44px;box-sizing:border-box;padding:12px 0;color:#1b527e;font-size:12px;font-weight:700}
   #v237CoverageAudit .lts-coverage-months>summary:focus-visible{outline:2px solid #1b527e;outline-offset:3px;border-radius:4px}
   #v237CoverageAudit .lts-coverage-months .v268-periods{margin-top:0!important;margin-bottom:8px}
   #v237CoverageAudit .lts-coverage-empty[hidden]{display:none}
   @media(max-width:400px){#ltsFutureBank{padding-block:10px}}
   @media(max-width:640px){#v237CoverageAudit .lts-coverage-toolbar{align-items:flex-start;flex-direction:column}#v237CoverageAudit .lts-coverage-toolbar label{width:100%}#v237CoverageAudit .lts-coverage-toolbar select{flex:1;min-width:0}#v237CoverageAudit [data-coverage-key]{gap:6px;padding:14px 12px}}
  `;document.head.appendChild(style);
  render=function(){
   const current=typeof BOOT==='object'?BOOT.generation:D,sameGeneration=current===generation;scope();
   if(sameGeneration)document.querySelectorAll('.lts-coverage-months[data-coverage-scope]').forEach(details=>{
    const key=details.dataset.coverageScope;if(details.open)expanded.add(key);else expanded.delete(key);
   });
   const result=previousRender.apply(this,arguments);compact();return result;
  };
  window.__LTS_V308_REVIEW_LAYOUT={installed:true,read_only:true,compact};compact();
 }
 function install(){try{
  const w=shell?.contentWindow,d=shell?.contentDocument;
  if(!w?.__LTS_V296_CLASSIFICATIONS?.installed)return false;
  if(!w.__LTS_V308_REVIEW_LAYOUT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}
  return !!w.__LTS_V308_REVIEW_LAYOUT?.installed;
 }catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}
 shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v308-review-layout.js',install);
})();
