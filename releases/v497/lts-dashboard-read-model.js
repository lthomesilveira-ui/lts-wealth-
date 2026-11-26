(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.LTSDashboardReadModel=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const CONTRACT='executive-cash-answer-evidence-v1';
  const finite=value=>value!==null&&value!==undefined&&value!==''&&Number.isFinite(Number(value))?Number(value):null;
  const iso=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||'').slice(0,10))?String(value).slice(0,10):null;
  const dayBefore=value=>{const date=iso(value);if(!date)return null;const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()-1);return d.toISOString().slice(0,10)};
  const maxDate=values=>values.map(iso).filter(Boolean).sort().at(-1)||null;
  const firstNumber=(...values)=>values.map(finite).find(value=>value!==null)??null;
  const firstDate=(...values)=>values.map(iso).find(Boolean)||null;
  function shortTerm(liquidity){
    const bank=finite(liquidity.bank_cash),d0=finite(liquidity.d0),throughD3=finite(liquidity.through_d3),vested=finite(liquidity.d3_vested);
    if(bank!==null&&d0!==null)return {value:bank+d0,method:'bank_cash_plus_d0'};
    if(throughD3!==null&&vested!==null)return {value:throughD3-vested,method:'through_d3_minus_vested'};
    return {value:null,method:'unavailable'};
  }
  function decision(planning,horizons){
    const firstNegative=firstDate(planning.first_negative_date,planning.dashboard_planning_first_negative_alias,planning.first_negative),
      worst=firstNumber(planning.worst_before_brl,planning.worst_balance_brl),
      worstDate=firstDate(planning.worst_before_date,planning.worst_balance_date),
      covers=planning.covers_horizon===true?true:planning.covers_horizon===false?false:null,
      horizonEnd=maxDate(horizons.map(item=>item&&item.date)),
      goesNegative=Boolean(firstNegative)||(worst!==null&&worst<0)||covers===false;
    if(goesNegative)return {state:'negative',answer:'Atenção: o caixa fica negativo',detail:firstNegative?'Primeiro saldo negativo em data projetada.':'A projeção indica insuficiência, mas a data exata não está disponível.',firstNegative,coveredUntil:dayBefore(firstNegative),worst,worstDate,horizonEnd};
    if(covers===true)return {state:'sufficient',answer:'Sim, no horizonte analisado',detail:horizonEnd?'O cenário-base permanece coberto até o fim do horizonte disponível.':'O leitor confirma cobertura, sem informar a data final do horizonte.',firstNegative:null,coveredUntil:horizonEnd,worst,worstDate,horizonEnd};
    return {state:'unknown',answer:'Ainda não é possível responder',detail:'Faltam evidências projetadas para confirmar suficiência ou ruptura do caixa.',firstNegative:null,coveredUntil:null,worst,worstDate,horizonEnd};
  }
  function build(cockpit){
    const source=cockpit&&typeof cockpit==='object'?cockpit:{},liquidity=source.liquidity||{},planning=source.planning_audited||{},expenses=source.expenses||{},cards=source.cards||{},work=source.work||{};
    const horizons=(Array.isArray(source.horizons)?source.horizons:[]).filter(item=>item&&iso(item.date)).map(item=>({
      id:String(item.id||''),label:String(item.label||''),date:iso(item.date),
      base:firstNumber(item.current_liquidity_balance,item.base_balance,item.balance),
      conditional:firstNumber(item.conditional_rsu_balance,item.conditional_balance),
      restricted:firstNumber(item.restricted_total_balance,item.restricted_balance)
    })).sort((a,b)=>a.date.localeCompare(b.date));
    return {
      contract:CONTRACT,asOf:firstDate(source.as_of,liquidity.as_of),decision:decision(planning,horizons),
      kpis:{bankCash:finite(liquidity.bank_cash),shortTerm:shortTerm(liquidity),vested:finite(liquidity.d3_vested),fgts:firstNumber(liquidity.fgts_d30,liquidity.fgts),expenses:finite(expenses.current_month&&expenses.current_month.spend)},
      accounts:Array.isArray(liquidity.accounts)?liquidity.accounts.filter(Boolean):[],horizons,
      planning:{managementDate:firstDate(planning.management_point_date),fgtsRequestBy:firstDate(planning.fgts_request_by),worstAfter:finite(planning.worst_after_brl),fgtsEstimated:planning.fgts_future_accrual_estimated===true},
      expenses:{current:expenses.current_month||{},previous:expenses.previous_month||{},top:Array.isArray(expenses.current_month&&expenses.current_month.top_categories)?expenses.current_month.top_categories:Array.isArray(expenses.top_categories)?expenses.top_categories:[]},
      cards:{nextDue:cards.next_due||{},open:finite(cards.open_cycles_total),closed:finite(cards.closed_or_due_total)},
      work:{count:firstNumber(work.actionable_count,source.actionable_count),actions:Array.isArray(work.top_actions)?work.top_actions:[]},
      wealth:{status:'validation_pending',source:source.wealth||{}}
    };
  }
  return {CONTRACT,finite,iso,dayBefore,shortTerm,decision,build};
});
