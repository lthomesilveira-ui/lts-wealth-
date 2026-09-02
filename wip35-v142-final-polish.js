(function(){
  const outer=document.getElementById('shell');
  let wired=null;

  function chain(){
    try{
      const d141=outer&&outer.contentDocument,f140=d141&&d141.getElementById('shell');
      const d140=f140&&f140.contentDocument,f139=d140&&d140.getElementById('shell');
      const d139=f139&&f139.contentDocument,f138=d139&&d139.getElementById('shell');
      const d138=f138&&f138.contentDocument,f137=d138&&d138.getElementById('shell');
      const d137=f137&&f137.contentDocument,app=d137&&d137.getElementById('app');
      if(!app||!app.contentDocument||!app.contentDocument.head)return null;
      return {w:app.contentWindow,d:app.contentDocument};
    }catch(e){return null}
  }

  function ensureCss(d){
    if(!d||!d.head||d.getElementById('wip35-v142-final-polish-css'))return;
    const s=d.createElement('style');s.id='wip35-v142-final-polish-css';s.textContent=`
      .p142-now{display:grid;grid-template-columns:minmax(220px,.95fr) repeat(3,minmax(150px,1fr));gap:7px;margin:-3px 0 11px}.p142-nowintro,.p142-nowitem{border:1px solid var(--bd);border-radius:13px;background:#fff;padding:10px 11px;min-height:72px;box-sizing:border-box}.p142-nowintro{background:#f8fafc}.p142-nowintro span,.p142-nowitem span{display:block;font-size:7px;font-weight:900;text-transform:uppercase;letter-spacing:.06em;color:var(--mut)}.p142-nowintro b{display:block;font-size:12px;margin:4px 0}.p142-nowintro small,.p142-nowitem small{display:block;font-size:8px;line-height:1.35;color:var(--mut)}.p142-nowitem{appearance:none;text-align:left;color:var(--ink);cursor:pointer}.p142-nowitem strong{display:block;font-size:18px;margin:4px 0}.p142-nowitem.attn{border-color:#ead7b4;background:#fffaf0}.p142-nowitem.good{border-color:#d7e5dc;background:#f8fbf9}.p142-nowitem:focus-visible{outline:2px solid #b8935a;outline-offset:2px}
      .u141-mainthead{margin:8px 0 6px!important}.u141-mainthead h2{font-size:17px!important}.u141-mainthead p{max-width:760px!important}.u141-collapsed{margin-top:6px!important;padding:7px 9px!important}.u141-docout{padding:8px 9px!important}.u141-docchips{margin-top:6px!important}.u141-note{margin-top:5px!important;line-height:1.35!important}.u132-classrow{margin-top:5px!important;padding:8px!important}.u132-actions .chip{min-height:32px!important}.u132-actions select.cardcat{height:34px!important}.u131-batch{margin:5px 0!important}.fx89-review{padding:8px!important}
      .d114-panel{min-width:0}.d114-action{padding-top:8px!important;padding-bottom:8px!important}.d114-horizon{min-width:0}.d142-audit{margin-top:8px!important;padding:9px!important}.d114-note{line-height:1.35!important}.d142-warning{line-height:1.35!important}
      .u142-asset{min-width:0}.u142-footnote{line-height:1.32!important}.u142-fold summary{padding:8px 0!important}
      @media(max-width:1050px){.p142-now{grid-template-columns:1fr 1fr}.p142-nowintro{grid-column:1/-1}}
      @media(max-width:650px){.p142-now{grid-template-columns:1fr}.p142-nowintro{grid-column:auto}.p142-nowintro,.p142-nowitem{min-height:0;padding:9px 10px}.p142-nowitem{display:grid;grid-template-columns:minmax(0,1fr) auto;column-gap:8px;align-items:center}.p142-nowitem span,.p142-nowitem small{grid-column:1}.p142-nowitem strong{grid-column:2;grid-row:1/3;margin:0;font-size:16px}.u142-main strong{font-size:24px!important}.u142-kpi b{font-size:15px!important}}
    `;d.head.appendChild(s)
  }

  function isBridgeRenderer(fn){return typeof fn==='function'&&String(fn).includes('u142PlanningBridgeRenderer')}
  function stabilizePlanningOwner(w){
    const live=w.__LTS_V142_PLANNING_RENDERER;
    if(!w.__LTS_V142_FINAL_PLAN_RENDERER&&isBridgeRenderer(live))w.__LTS_V142_FINAL_PLAN_RENDERER=live;
    const renderer=w.__LTS_V142_FINAL_PLAN_RENDERER;
    if(!isBridgeRenderer(renderer))return false;
    /* Stop the older v142 UX loop from reasserting its audit renderer between bridge ticks. */
    w.__lts_v142_planning_fn=renderer;
    try{
      if(!w.__LTS_V142_FINAL_PLAN_GETTER){
        w.__LTS_V142_FINAL_PLAN_GETTER=function v142FinalPlanningOwner(){return w.__LTS_V142_FINAL_PLAN_RENDERER};
        w.__LTS_V142_FINAL_PLAN_SETTER=function v142FinalPlanningSetter(fn){
          if(isBridgeRenderer(fn)){
            w.__LTS_V142_FINAL_PLAN_RENDERER=fn;
            w.__LTS_V142_PLANNING_RENDERER=fn;
            w.__lts_v142_planning_fn=fn;
          }
          return fn;
        };
      }
      const desc=Object.getOwnPropertyDescriptor(w,'planejamento');
      if(desc&&desc.configurable===false){
        if(!isBridgeRenderer(w.planejamento)&&isBridgeRenderer(renderer)){
          w.LTS_V142_FINAL_PLANNING_OWNER='blocked-nonconfigurable';
          return false;
        }
        w.LTS_V142_FINAL_PLANNING_OWNER='stable-nonconfigurable-v2';
        return true;
      }
      Object.defineProperty(w,'planejamento',{
        configurable:false,
        enumerable:true,
        get:w.__LTS_V142_FINAL_PLAN_GETTER,
        set:w.__LTS_V142_FINAL_PLAN_SETTER
      });
      w.LTS_V142_FINAL_PLANNING_OWNER=isBridgeRenderer(w.planejamento)?'stable-nonconfigurable-v2':'stabilize-error';
      return w.LTS_V142_FINAL_PLANNING_OWNER==='stable-nonconfigurable-v2';
    }catch(e){
      try{w.planejamento=renderer}catch(_){}
      w.LTS_V142_FINAL_PLANNING_OWNER=isBridgeRenderer(w.planejamento)?'stable-assignment-fallback':'stabilize-error';
      return isBridgeRenderer(w.planejamento);
    }
  }

  function farFuture(w,x){try{return typeof w.u141FarFuture==='function'&&w.u141FarFuture(x)}catch(e){return false}}
  function counts(w){
    const maintenance=(w.D?.updates?.maintenance_checks||[]).filter(x=>x&&x.actionable&&!farFuture(w,x)).length;
    const classification=(w.D?.card_classification_review?.items||[]).length;
    const ds=w.__lts_v141_document_outcomes?.summary||{};
    const documents=Number(ds.decision_required||0);
    return {maintenance,classification,documents};
  }

  function target(d,kind){
    if(kind==='maintenance')return d.querySelector('.u141-mainthead');
    if(kind==='classification')return d.querySelector('.u132-classrow')||d.querySelector('.u131-batch');
    if(kind==='documents')return d.getElementById('u141DocumentOutcomes');
    return null;
  }

  function bindBar(d,bar){
    bar.querySelectorAll('[data-p142-target]').forEach(b=>{
      b.onclick=()=>{
        const x=target(d,b.dataset.p142Target);
        if(x&&typeof x.scrollIntoView==='function')x.scrollIntoView({behavior:'smooth',block:'start'});
      };
    });
  }

  function ensureNowBar(w,d){
    if(w.V!=='Atualizações')return;
    const quick=d.querySelector('.u142-quick');if(!quick)return;
    const c=counts(w),key=[c.maintenance,c.classification,c.documents].join('|');
    let bar=d.getElementById('p142Now');
    if(!bar){bar=d.createElement('div');bar.id='p142Now';bar.className='p142-now';quick.insertAdjacentElement('afterend',bar)}
    if(bar.dataset.key===key)return;
    bar.dataset.key=key;
    const tone=n=>n>0?'attn':'good';
    bar.innerHTML=`<div class="p142-nowintro"><span>Resolver agora</span><b>Checklist curto, antes dos detalhes.</b><small>Abra só o bloco que precisa da sua decisão. Histórico, evidência e checks saudáveis continuam abaixo para auditoria.</small></div>
      <button type="button" class="p142-nowitem ${tone(c.maintenance)}" data-p142-target="maintenance"><span>Atualizações necessárias</span><strong>${c.maintenance}</strong><small>${c.maintenance?'dados/coberturas próximas pedem ação':'nenhuma manutenção imediata'}</small></button>
      <button type="button" class="p142-nowitem ${tone(c.classification)}" data-p142-target="classification"><span>Classificações para revisar</span><strong>${c.classification}</strong><small>${c.classification?'sem sugestão insegura automática':'fila de classificação vazia'}</small></button>
      <button type="button" class="p142-nowitem ${tone(c.documents)}" data-p142-target="documents"><span>Documentos com decisão</span><strong>${c.documents}</strong><small>${c.documents?'aguardam revisão explícita':'nenhum documento pede decisão'}</small></button>`;
    bindBar(d,bar);
  }

  function ensureProductCopy(w,d){
    try{
      if(w.V==='Atualizações'){
        const h=d.querySelector('.u141-mainthead p');
        if(h)h.textContent='Ações atuais primeiro. Cobertura distante e checks OK ficam recolhidos e continuam disponíveis para auditoria.';
      }
    }catch(e){}
  }

  function install(){
    const z=chain();if(!z)return;const w=z.w,d=z.d;ensureCss(d);
    w.LTS_V142_FINAL_POLISH='action-first-round3-v1';
    stabilizePlanningOwner(w);
    ensureNowBar(w,d);ensureProductCopy(w,d);
    if(wired!==w){wired=w;try{w.renderNav()}catch(e){}}
  }

  outer?.addEventListener('load',()=>setTimeout(install,180));
  setInterval(install,40);
})();
