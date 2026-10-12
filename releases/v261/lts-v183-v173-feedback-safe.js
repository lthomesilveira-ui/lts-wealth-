(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V173_V172_FEEDBACK?.installed||!window.__LTS_V172_V171_REVIEW?.installed)return;
    const baseRender=render,baseNav=renderNav,v168=window.__LTS_V168_STATE;
    const norm=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
    const esc=value=>String(value??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const canonicalAliases=new Map([
      ['imagem e cuidados pessoais','Vestuário'],
      ['assinatura','Assinaturas'],['benjamin - educacao','Educação'],['pet','Rafiki'],
      ['benjamin - saude','Saúde'],['larissa - saude','Saúde'],['benjamin - vestuario','Vestuário'],
      ['viagem','Viagens'],['financiamento veiculo','Financiamento veículo']
    ]);
    const seed=[
      'Alimentação e Bebidas','Aluguel Carro','Amazon','Anuidade','Apple','Armazenamento','Assinaturas',
      'Bebidas','Benjamin - Aulas complementares','Benjamin - Brinquedos e presentes',
      'Benjamin - Estrutura e manutenção','Benjamin - Presentes','Benjamin - Batizado',
      'Cabelereiro','Carro','Casa - Utensílios e equipamentos','Casamento','Combustível','Cursos',
      'Desenvolvimento','Duty free','Educação','Empréstimos','Energia','Estacionamento E Pedágio',
      'Eventos','Família','Farmácia','Financiamento Imobiliário','Financiamento veículo','Hotel',
      'Ifood','Impostos','Impostos do Imóvel','Investimento Imobiliário','Investimentos','Lavanderia',
      'Lazer','Mercado','Mercado Livre','Moradia','Móveis e Decoração','Obra e Reforma',
      'Organon Despesas','Outros','Passeios','Presentes','Rafiki','Reembolso Organon',
      'Reembolso plano de saúde','Reembolsos','Rendimentos financeiros','Restaurantes',
      'Restaurantes e Lazer','Salário','Saque / Dinheiro','Saúde','Seguros','Seguros - Vida',
      'Serviços Administrativos','Sócio Rei','Spotify','Supermercado','Tarifas Bancárias',
      'Tarifas e Juros','Táxi/Uber','Telefone','Transferência própria','Veículos - Aquisição',
      'Veículos - Estacionamento','Veículos - Manutenção','Veículos - Multas','Veículos - Tributos',
      'Vestuário','Viagens','Volvo XC40'
    ];

    function canonical(value){
      const raw=String(value||'').trim();if(!raw||norm(raw)==='a classificar')return'';
      return canonicalAliases.get(norm(raw))||raw;
    }
    function categoryOptions(){
      const map=new Map(),add=value=>{const label=canonical(value),key=norm(label);if(key&&!map.has(key))map.set(key,label)};
      seed.forEach(add);
      for(const data of [v168?.dashboard?.data?.expense,v168?.expense?.data]){
        for(const group of Array.isArray(data?.management_groups)?data.management_groups:[]){
          for(const source of Array.isArray(group.source_categories)?group.source_categories:[])add(source?.name);
        }
      }
      for(const row of Array.isArray(v168?.transactions?.rows)?v168.transactions.rows:[])add(row?.category);
      return [...map.values()].sort((a,b)=>a.localeCompare(b,'pt-BR',{sensitivity:'base'}));
    }
    function mentionedCategory(phrase,options){
      const n=norm(phrase).replace(/\bimagem e cuidados pessoais\b/g,'vestuario'),ordered=options.map(x=>({label:x,key:norm(x)})).filter(x=>x.key.length>=4).sort((a,b)=>b.key.length-a.key.length);
      const marker=n.match(/(?:classificad[oa]\s+como|categoria)\s+(.+?)(?:\s+em\s+\d{1,2}[\/-]|\s+no\s+dia\s+\d{1,2}|$)/);
      if(marker){
        const target=norm(marker[1]);
        const exact=ordered.find(x=>target===x.key||target.startsWith(x.key+' '));if(exact)return exact.label;
      }
      const direct=ordered.find(x=>n===x.key||n.includes(' '+x.key+' ')||n.endsWith(' '+x.key)||n.startsWith(x.key+' '));
      if(direct)return direct.label;
      if(/\bfamilia\b/.test(n))return options.find(x=>norm(x)==='familia')||'Família';
      return'';
    }
    function decorateNatural(){
      const field=document.getElementById('v168NlCategory');if(!field)return;
      const options=categoryOptions(),phrase=document.getElementById('v168NlPhrase')?.value||v168?.nl?.draft||'',existing=canonical(field.value),inferred=mentionedCategory(phrase,options),selected=inferred||existing;
      if(field.tagName!=='SELECT'){
        const select=document.createElement('select');select.id='v168NlCategory';select.className=(field.className?field.className+' ':'')+'v173-category-select';select.setAttribute('aria-label','Categoria');
        select.innerHTML='<option value="">Selecione uma categoria</option>'+options.map(label=>'<option value="'+esc(label)+'">'+esc(label)+'</option>').join('');
        field.replaceWith(select);
        if(selected&&options.some(label=>norm(label)===norm(selected)))select.value=options.find(label=>norm(label)===norm(selected));
        select.addEventListener('change',()=>{if(v168?.nl?.preview)v168.nl.preview.category=select.value||'A classificar'});
        if(inferred&&v168?.nl?.preview){v168.nl.preview.category=inferred;v168.nl.preview.missing=(Array.isArray(v168.nl.preview.missing)?v168.nl.preview.missing:[]).filter(x=>norm(x)!=='categoria')}
        const label=select.closest('label');if(label&&!label.querySelector('.v173-category-hint')){const hint=document.createElement('small');hint.className='v173-category-hint';hint.textContent=inferred?'Interpretado da descrição; você pode alterar.':'Escolha uma categoria existente.';label.appendChild(hint)}
      }else if(inferred&&options.some(label=>norm(label)===norm(inferred))){
        field.value=options.find(label=>norm(label)===norm(inferred));if(v168?.nl?.preview)v168.nl.preview.category=field.value;
      }
    }
    function childName(node){return node.querySelector('span')?.textContent?.trim()||''}
    function setChildName(node,value){const span=node.querySelector('span');if(span)span.textContent=value}
    function decorateCompositions(){
      const root=document.querySelector('.v172-categories');if(!root)return;
      for(const row of root.querySelectorAll('.v172-rankrow')){
        const parent=row.querySelector(':scope > div > b')?.textContent?.trim()||'',p=norm(parent),details=row.querySelector('details');if(!details)continue;
        const children=[...details.querySelectorAll('em')];
        for(const child of children){
          const name=norm(childName(child));
          if(p==='financiamento de veiculo'&&(name==='nao identificado'||name==='veiculo nao atribuido'))setChildName(child,'Volvo XC40');
        }
        const names=[...details.querySelectorAll('em')].map(child=>norm(childName(child))).filter(Boolean),unique=[...new Set(names.filter(name=>name!==p))];
        const realEstateNames=['financiamento imobiliario — casa','financiamento imobiliario - casa','casa','financiamento imobiliario — cipo 396','financiamento imobiliario - cipo 396','cipo 396'];
        const sameRealEstateChain=p==='financiamento imobiliario'&&unique.length>0&&unique.every(name=>realEstateNames.includes(name));
        if(unique.length<=1||sameRealEstateChain)details.remove();
      }
    }
    function stamp(){const badge=window.parent?.document?.getElementById('scope');if(badge)badge.dataset.v173Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();decorateNatural();decorateCompositions()}
    render=function(){const out=baseRender();after();return out};
    renderNav=function(){const out=baseNav();stamp();return out};
    const observer=new MutationObserver(()=>queueMicrotask(after));observer.observe(document.body,{childList:true,subtree:true});
    window.__LTS_V173_V172_FEEDBACK={installed:true,version:'v173',base_version:'v172',public_index_changed:false,category_select:true,canonical_category_inference:true,redundant_composition_suppressed:true,vehicle_financing_identity:'Volvo XC40',real_estate_financing_single_chain:true};
    if(typeof D!=='undefined'&&D&&typeof N!=='undefined'&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){
    const f=frame();if(!f||!f.w.__LTS_V172_V171_REVIEW?.installed)return false;
    if(!f.d.getElementById('lts-v173-style')){const link=f.d.createElement('link');link.id='lts-v173-style';link.rel='stylesheet';link.href='lts-v173-v172-feedback.css?v=20260918-v173a';f.d.head.appendChild(link)}
    if(!f.w.__LTS_V173_V172_FEEDBACK?.installed&&!f.d.getElementById('lts-v173-runtime')){const script=f.d.createElement('script');script.id='lts-v173-runtime';script.textContent='('+runtime.toString()+')();';f.d.head.appendChild(script)}
    const ready=f.w.__LTS_V173_V172_FEEDBACK?.installed===true;if(ready&&gate)gate.remove();return ready;
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt++;if(!ready&&attempt<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v173-v172-feedback';
})();
