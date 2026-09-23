/* Shared, read-only coverage policy. Contains no private balances or transactions. */
(function(root,factory){
  const policy=factory();
  if(typeof module==='object'&&module.exports)module.exports=policy;
  else root.LTSHistoryCoverage=policy;
})(typeof window==='undefined'?this:window,function(){
  'use strict';
  const expenseFrom='2013-10-10',operationalFrom='2026-07-08';
  function iso(value){
    if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
    const date=new Date(value+'T12:00:00Z');
    return Number.isFinite(date.getTime())&&date.toISOString().slice(0,10)===value?value:null;
  }
  const br=value=>value.split('-').reverse().join('/');
  // A documentary opening or a successful arithmetic check is not reconciliation.
  // Only a source-compared, contiguous interval can certify historical balances.
  function verifiedRange(contract,account){
    const item=contract?.reconciled_intervals?.[account];
    if(!item||item.status!=='source_reconciled'||item.contiguous!==true||
      item.movements_compared!==true||item.balances_compared!==true||
      typeof item.evidence_ref!=='string'||!item.evidence_ref.trim())return null;
    const from=iso(item.from),through=iso(item.through);
    if(!from||!through||from>through||through>=operationalFrom)return null;
    return {from,through};
  }
  function dayStatus(day,account,contract){
    const date=iso(day);
    if(!date)return 'unavailable';
    if(date>=operationalFrom)return 'operational';
    const range=verifiedRange(contract,account);
    return range&&date>=range.from&&date<=range.through?'reconciled':'uncertified';
  }
  function flowMessage(account,contract){
    const range=verifiedRange(contract,account);
    const history=range?'Fluxo conciliado de '+br(range.from)+' a '+br(range.through)+'.':
      'Fluxo histórico: início conciliado ainda não estabelecido.';
    return history+' Despesas preservadas desde 2013, independentemente da conciliação dos saldos. Operação LTS preservada a partir de 08/07/2026.';
  }
  function canReplaceWithHistoricalSource(day){
    const date=iso(day);
    return Boolean(date&&date<operationalFrom);
  }
  return Object.freeze({expenseFrom,operationalFrom,verifiedRange,dayStatus,flowMessage,
    canReplaceWithHistoricalSource,
    expenseMessage:'Despesas desde 2013. A cobertura das despesas é independente dos saldos conciliados no Fluxo; resultado do período não é saldo bancário.',
    uncertifiedMessage:'Saldo histórico não conciliado. Entradas e saídas permanecem disponíveis; este saldo não entra nos totais.'});
});
