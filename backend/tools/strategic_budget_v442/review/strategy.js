(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV442Strategy=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
 const cents=x=>x===null||x===undefined||!Number.isFinite(Number(x))?null:Math.round(Number(x)*100),money=x=>x===null?null:x/100;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0),round=x=>Math.ceil(x/1000)*1000;
 function kind(category){const c=norm(category);
  if(/financiamento|emprestimo|compromissos financeiros|condominio|seguro|assinatura|anuidade|armazenamento|spotify|google/.test(c))return'fixed';
  if(/ipva|iptu|impostos|tributos|licenciamento|viagen|passagem|hotel|duty free|batizado|casamento|eventos|documentos/.test(c))return'seasonal';
  if(/brinquedo|presente|vestuario|restaurante|ifood|rappi|bebida|cabele|cabeler|passeio|lazer|mercado livre|amazon|apple|moveis|decoracao|doacao/.test(c))return'discretionary';
  if(/saude|farmacia|educacao|aulas|mercado$|alimentacao|energia|enel|combustivel|rafiki|moradia|familia|benjamin/.test(c))return'essential';
  return'unreviewed';
 }
 function derive(input,flow,cards){
  if(!input||input.ok!==true||!Array.isArray(input.rows)||!Array.isArray(input.months)||input.months.length!==12)throw Error('budget unavailable');
  const p=structuredClone(input),asOf=p.as_of,current=asOf.slice(0,7),year=p.year,events=flow?.flow?.current_future?.events??flow?.current_future?.events;
  const cf=flow?.flow?.current_future??flow?.current_future,cardRows=cards?.cards;if(!Array.isArray(events)||!Array.isArray(cardRows)||cards.complete===false||!p.income_approvals||!p.category_aliases||Array.isArray(p.category_aliases)||typeof p.category_aliases!=='object')throw Error('commitments or approval metadata unavailable');
  if(year>=Number(asOf.slice(0,4))&&(flow.complete===false||cf.complete===false||!cf.from||cf.from>asOf||!cf.to||cf.to<year+'-12-31'))throw Error('commitment horizon incomplete');
  const amounts=new Map(),cardAmounts=new Map(),evidence=new Map(),withheld=[],unallocatedCash=[],unmapped=[],knownKeys=new Set(p.rows.map(r=>r.category)),seen=new Set(),salary=new Map();
  const key=(m,c)=>m+'\u0000'+c,categoryFor=c=>{if(knownKeys.has(c))return c;if(knownKeys.has(p.category_aliases[c]))return p.category_aliases[c];
   // Two established Portuguese labels for the same mortgage category. This
   // changes only planning assignment, never the original event or its amount.
   if(norm(c)==='financiamento imovel'){const same=[...knownKeys].filter(x=>norm(x)==='financiamento imobiliario');if(same.length===1)return same[0];}return c;};
  const add=(month,category,amount,detail)=>{if(!new RegExp('^'+year+'-(0[1-9]|1[0-2])$').test(month)||amount<=0)return;
   category=categoryFor(category);
   if(!category||!knownKeys.has(category)){unmapped.push({month,category:category||'Compromisso sem categoria',amount:money(amount),...detail});return;}
   const k=key(month,category),map=['installment','card_commitment'].includes(detail.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+amount);const a=evidence.get(k)||[];a.push({...detail,amount:money(amount)});evidence.set(k,a);
  };
  for(const e of events){const n=cents(e.signed_amount),description=e.description||'',c=norm(description+' '+e.category),source=String(e.source||'');
   if(n!==null&&n>0&&String(e.event_date)>asOf&&/^(salario( liquido)?|adiantamento quinzenal)$/.test(norm(description))&&!/bonus|13[º°o]?|decimo|ferias/.test(c)){const mk=String(e.event_date).slice(0,7);salary.set(mk,(salary.get(mk)||0)+n);}
   if(n===null||n>=0||e.internal_transfer||e.is_asset_movement||e.excluded_from_spend||/card|invoice|budget|historical_spending|projection_policy|planning_projection/.test(source)||/fatura|aeternum|mastercard|personnalite|c6 carbon/.test(c))continue;
   const payrollProof=(p.planning?.payroll_withholding||[]).find(w=>typeof e.source==='string'&&e.source.length>0&&typeof e.source_ref==='string'&&e.source_ref.length>0&&w.source===e.source&&w.source_ref===e.source_ref&&w.date===e.event_date&&cents(w.amount)===-n&&cents(w.base_income)-cents(w.net_income)===-n&&Array.isArray(w.evidence)&&w.evidence.some(v=>typeof v==='string'&&v.trim()));
   if(payrollProof){withheld.push({description,amount:money(-n),date:e.event_date,evidence:payrollProof.evidence});continue;}
   // A lender name alone is not evidence that net income already includes its payment.

   const proof=/coopharma|consignado|financiamento|emprestimo|condominio|seguro|iptu|ipva|licenciamento|mensalidade|parcela/.test(c)||e.confidence==='user_flow_editable'||e.confidence==='documented_scheduled';
   if(String(e.event_date)<asOf||String(e.event_date)===asOf&&!['user_flow_editable','legacy_projection_adjusted','documented_scheduled','documented_expected'].includes(e.confidence))continue;
   const identity=source+':'+e.source_ref+':'+e.event_date;if(seen.has(identity))continue;seen.add(identity);
   // Payment date is not service competence. Keep uncertain cash visible but separate.
   const competence=String(e.competence_month||'').slice(0,7),hasCompetence=proof&&/^\d{4}-(0[1-9]|1[0-2])$/.test(competence)&&Array.isArray(e.competence_evidence)&&e.competence_evidence.length>0&&e.competence_evidence.every(x=>typeof x==='string'&&x.trim());
   if(!hasCompetence){unallocatedCash.push({description,date:e.event_date,category:e.category,amount:money(-n),source:e.source,source_ref:e.source_ref,reason:'Data de pagamento conhecida; competência do serviço ainda não comprovada.'});continue;}
   add(competence,e.category,-n,{description,date:e.event_date,competence_month:competence,competence_evidence:e.competence_evidence,kind:'scheduled',contracted:/financiamento|emprestimo|parcela/.test(c)});
  }
  for(const card of cardRows)for(const cycle of card.cycles||[])for(const item of cycle.items||[]){
   const installment=Number(item.total_installments)>1;
   const received=['PENDING','POSTED','DOCUMENTED'].includes(item.provider_status);
   if((!installment&&!received)||item.is_payment||Number(item.amount)<=0)continue;
   const month=String(item.reference_month||cycle.month||'').slice(0,7),identity=[card.family,month,item.source_id,item.installment_number].join(':');
   if(!item.source_id||seen.has(identity))continue;seen.add(identity);
   add(month,item.category,cents(item.amount),{description:item.description,date:item.purchase_date||item.posting_date,kind:installment?'installment':'card_commitment',installment:item.installment_number,total_installments:item.total_installments,contracted:true});
  }
  // Unknown obligations remain explicit. They are never silently converted to zero.
  const extraCategories=[...new Set(unmapped.map(x=>x.category))].filter(c=>!knownKeys.has(c));
  for(const category of extraCategories){knownKeys.add(category);p.rows.push({category,reference_monthly:null,commitments_only:true,months:p.months.map(m=>({month:m.month,actual:0,card_actual:0,pending:0,target:null,target_basis:'history'}))});}
  for(const x of unmapped){const k=key(x.month,x.category),map=['installment','card_commitment'].includes(x.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+cents(x.amount));evidence.set(k,[...(evidence.get(k)||[]),x]);}
  const plans=[];
  for(let i=0;i<12;i++){
   const m=p.months[i],past=m.month<current,rows=[];
   const incomeApproved=p.income_approvals.year===true||p.income_approvals.months?.[m.month]===true;
   if(!incomeApproved&&salary.has(m.month))m.income_target=money(salary.get(m.month)+(m.month===current?(cents(m.income_regular)||0):0));
   const income=cents(m.income_target);
   for(const r of p.rows){const x=r.months[i],type=kind(r.category),history=cents(r.reference_monthly),owner=x.target_basis==='owner',scheduled=amounts.get(key(m.month,r.category))||0,card=cardAmounts.get(key(m.month,r.category))||0;
    if(m.month===current&&card>0&&x.card_actual===undefined)throw Error('recorded card coverage unavailable');
    const floor=m.month===current?Math.max(cents(x.actual)||0,0)+scheduled+Math.max(0,card-Math.max(cents(x.card_actual)||0,0)):scheduled+card,details=evidence.get(key(m.month,r.category))||[];
    let proposed=null,reason='',desired=0;
    if(owner){proposed=cents(x.target);reason='Meta aprovada por você; preservada.';}
    else if(past){reason='Sem orçamento aprovado para este mês encerrado.';}
    else {
     // A reference is descriptive, not a recommendation. A reviewed proposal
     // must carry a reason and source evidence, separately from owner approval.
     const plan=p.planning?.months?.[m.month]?.[r.category];
     const reviewed=plan&&plan.status==='reviewed_proposal'&&typeof plan.reason==='string'&&plan.reason.trim()&&Array.isArray(plan.evidence)&&plan.evidence.length>0&&plan.evidence.every(e=>typeof e==='string'&&e.trim());
     if(reviewed&&cents(plan.target)!==null&&cents(plan.target)>=0){
      proposed=Math.max(floor,cents(plan.target));reason=plan.reason+(cents(plan.target)<floor?' Proposta elevada ao já registrado e aos compromissos conhecidos.':'');
     }else if(type==='fixed'&&details.length&&history===null){
      proposed=null;reason='Compromissos identificados são o piso, não prova de cobertura integral da categoria. Falta proposta revisada.';
     }else{
      proposed=null;reason='Referência histórica e compromissos disponíveis para planejamento. Falta proposta fundamentada por categoria; nenhum corte ou meta zero foi presumido para fechar a renda.';
     }
    }
    rows.push({row:r,value:x,type,owner,floor,proposed,desired,reason,details,history});
   }
   for(const r of rows){let value=r.proposed;
    r.value.target=money(value);r.value.target_basis=r.owner?'owner':'proposal';
    r.value.strategy={type:r.type,reason:r.reason,floor:money(r.floor),history:money(r.history),details:r.details,proposed:!r.owner,needsReview:!r.owner&&r.proposed===null};
   }
   m.target=money(sum(rows.map(r=>cents(r.value.target))));
   plans.push({month:m.month,fixed:money(rows.reduce((a,r)=>a+r.floor,0)),income:money(income),target:m.target,
    balance:m.target===null||income===null?null:money(income-cents(m.target)),covered:!past||rows.some(r=>r.owner)});
  }
  p.strategy={version:'strategic-v442',proposals:true,pastWithoutPlan:plans.filter(x=>!x.covered).length,regular_income_basis:'net_received_without_bonus_or_thirteenth',months:plans,
   payroll_withheld_not_added:withheld,cash_without_competence:unallocatedCash,unmapped_obligations:unmapped,flow_provision_included:false,
   alternatives:['Preservar parcelas e compromissos já assumidos.','Comparar alternativas de redução com valores e consequências; não zerar categorias automaticamente.','Rever gastos essenciais pelo detalhe e renegociar contratos quando possível.','Usar bônus e 13º apenas como cobertura extraordinária, sem incorporá-los ao salário mensal.']};
  p.proposed=p.rows.some(r=>r.months.some(m=>m.target_basis==='proposal'&&m.target!==null));return p;
 }
 return Object.freeze({derive,kind});
});
