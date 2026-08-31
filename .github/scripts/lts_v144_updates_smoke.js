const { chromium } = require('playwright');
const fs = require('fs');

async function run(browser, viewport, label){
  const page=await browser.newPage({viewport});
  const errors=[];
  page.on('pageerror',e=>errors.push('pageerror:'+e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  await page.goto('http://127.0.0.1:8767/wip35-v144-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(8000);
  const chain=[];let f=page.mainFrame();
  for(let i=0;i<10;i++){chain.push(f.url());const kids=f.childFrames();if(!kids.length)break;f=kids[0]}
  const expected=['wip35-v144-candidate.html','wip35-v142-candidate.html','wip35-v141-candidate.html','wip35-v140-candidate.html','wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
  const helpers=await f.evaluate(()=>({card:typeof window.cardClassificationUpdates==='function',expense:typeof window.expenseClassificationUpdates==='function',render:typeof window.render==='function',updates:typeof window.atualizacoes==='function'}));

  await f.evaluate(()=>{
    window.D={
      updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-08-31'},guardrail:'Itens resolvidos não reaparecem.'},
      semantic_review:{pending_groups:0,items:[]},
      card_classification_review:{
        pending_groups:2,pending_lines:2,pending_value:725.46,safe_suggestion_groups:0,
        category_options:['Restaurantes','Supermercado','Outros'],
        taxonomy_guard:{active_pairs:[{category_a:'Restaurantes',category_b:'Outros'}]},
        items:[
          {description_key:'gula-gula-morumbi',merchant_name:'GULA GULA MORUMBI',example_description:'GULA GULA MORUMBI',card_name:'Aeternum',due_date:'2026-09-10',occurrences:2,total_value:725.46,suggested_category:'Restaurantes',suggestion_confidence:.83,suggestion_confidence_level:'medium',suggestion_basis:'estabelecimento_identificado_pesquisa_publica',enrichment_attempted:true,merchant_identified:true,enrichment_confidence:.99,enrichment_evidence:'Gula Gula identificado por fonte oficial como restaurante.',taxonomy_ambiguous:true,enrichment_status:'taxonomy_review'},
          {description_key:'ambiguous-marketplace',merchant_name:'MARKETPLACE EXEMPLO',example_description:'MARKETPLACE EXEMPLO',card_name:'C6',due_date:'2026-09-12',occurrences:1,total_value:119.9,suggested_category:'',suggestion_confidence:0,enrichment_attempted:true,merchant_identified:true,enrichment_confidence:.91,enrichment_evidence:'Marketplace identificado; item comprado não está comprovado.',taxonomy_ambiguous:true,enrichment_status:'marketplace_needs_item_context'}
        ]
      }
    };
    window.V='Atualizações';window.renderNav?.();window.render();
  });
  await page.waitForTimeout(1800);

  const state=await f.evaluate(()=>{
    const root=document.getElementById('v144UpdatesRoot'),text=root?root.innerText:'',classSec=document.getElementById('v144ClassificationZone'),other=document.getElementById('v144OtherActions');
    const classRect=classSec?.getBoundingClientRect(),otherRect=other?.getBoundingClientRect();
    const saveButtons=Array.from(document.querySelectorAll('#v144ClassificationZone .cardclass-save')).map(x=>x.textContent.trim());
    const conf=Array.from(document.querySelectorAll('#v144ClassificationZone .v144-proofline span')).map(x=>x.textContent.trim());
    const cards=Array.from(document.querySelectorAll('#v144ClassificationZone #cardClassReview .cardclass-row'));
    const duplicate=document.getElementById('v143EvidenceSuggestions');
    return {
      marker:window.LTS_V144_UPDATES_LAYOUT||null,root:!!root,css:!!document.getElementById('wip35-v144-updates-layout-css'),baseClassificationPreserved:!!document.getElementById('cardClassReview'),
      title:text.includes('Resolva o que precisa de você.'),methodology:text.includes('Histórico do LTS')&&text.includes('Pesquisa pública')&&text.includes('% de confiança'),suggestion:text.includes('Restaurantes'),evidence:text.includes('Gula Gula identificado por fonte oficial como restaurante.'),
      confidence83:conf.some(x=>x.includes('83% sugestão')),confidence99:conf.some(x=>x.includes('99% identificação')),ambiguousResearch:conf.some(x=>x.includes('91% identificação'))&&text.includes('Marketplace identificado; item comprado não está comprovado.'),
      cards:cards.length,saveButtons,classificationBeforeSecondary:!!classRect&&!!otherRect&&classRect.top<otherRect.top,secondaryCollapsed:!!other&&!other.open,duplicateHidden:!duplicate||getComputedStyle(duplicate).display==='none',width:document.documentElement.clientWidth,scroll:Math.max(document.documentElement.scrollWidth,document.body?document.body.scrollWidth:0)
    };
  });
  const pass=chainOk&&helpers.card&&helpers.expense&&helpers.render&&helpers.updates&&state.marker==='classification-action-center-v2'&&state.root&&state.css&&state.baseClassificationPreserved&&state.title&&state.methodology&&state.suggestion&&state.evidence&&state.confidence83&&state.confidence99&&state.ambiguousResearch&&state.cards===2&&state.saveButtons.length===2&&state.classificationBeforeSecondary&&state.secondaryCollapsed&&state.duplicateHidden&&state.scroll-state.width<=2&&errors.length===0;
  await page.close();return {label,viewport,pass,chain,chainOk,helpers,state,errors};
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  const desktop=await run(browser,{width:1440,height:1000},'desktop');
  const mobile=await run(browser,{width:390,height:844},'mobile-390x844');
  await browser.close();
  const result={pass:desktop.pass&&mobile.pass,desktop,mobile,importantLimit:'Synthetic classification data validates preserved v138 classification helpers, post-render layout, confidence/evidence visibility and responsive composition only. No backend financial write is executed. This is not authenticated visual E2E.'};
  fs.writeFileSync('v144-updates-smoke-result.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
