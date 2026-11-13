/* Read-only financial presentation. Raw classifications and amounts stay intact. */
(function(root){'use strict';
 const number=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!=='')&&Number.isFinite(Number(x))?Number(x):null;
 const validDate=x=>{if(typeof x!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(x))return false;const t=Date.parse(x+'T12:00:00Z');return Number.isFinite(t)&&new Date(t).toISOString().slice(0,10)===x;};
 const text=x=>typeof x==='string'?x.trim():'';
 function label(x){return x==='Patrimônio e financiamentos'?'Financiamentos e empréstimos':x;}
 function identity(r){const group=text(r.category)||'Sem grupo informado',subgroup=text(r.subgroup)||text(r.current_category)||text(r.original_category)||'Sem subgrupo informado';return {key:JSON.stringify([group,subgroup]),group,subgroup};}
 function groups(rows,expected){
  if(!Array.isArray(rows)||number(expected)===null)throw Error('Incomplete group');
  const seen=new Set(),map=new Map();let total=0;
  for(const r of rows){if(!r?.key||seen.has(r.key)||number(r.amount)===null)throw Error('Invalid detail');seen.add(r.key);const a=number(r.amount),id=identity(r);total+=a;const g=map.get(id.key)||{...id,total:0,count:0};g.total+=a;g.count++;map.set(id.key,g);}
  if(Math.abs(total-number(expected))>0.02)throw Error('Group total differs');
  return [...map.values()].sort((a,b)=>b.total-a.total||a.subgroup.localeCompare(b.subgroup,'pt-BR'));
 }
 function cardLabel(e){
  if(e?.source!=='planning_projection_v412')return null;
  const key=String(e.source_ref||'').split(':')[2],names={card_itau:'Mastercard Itaú',card_aeternum:'Aeternum',card_c6:'C6'};
  return names[key]?{title:names[key]+' · complemento do orçamento',note:'Previsão adicional; não é outra fatura.'}:null;
 }
 function bridge(day,evidence,bank){
  const row=day?.[bank],g=row?.cash_position_guard;
  if(evidence?.version!=='pending-bank-evidence-v423'||evidence.as_of!==day?.date||!g)return null;
  const candidates=(evidence.accounts||[]).filter(x=>x.bank===bank);if(candidates.length!==1)return null;
  const a=candidates[0],observed=number(row.observed_balance),net=number(row.unposted_projection_net),reconstructed=number(g.ledger_reconstruction?.balance);
  if(a.complete!==true||!validDate(a.source_date)||number(a.pending_total_brl)===null||observed===null||net===null||reconstructed===null||number(a.balance_brl)!==observed||!Array.isArray(a.movements)||!a.movements.length||a.movements.length!==a.pending_count||a.source_date>day.date)return null;
  const ids=new Set();let sum=0;
  for(const m of a.movements){if(!m.key||ids.has(m.key)||m.status!=='PENDING'||number(m.amount)===null||!validDate(m.date)||m.date>a.source_date)return null;ids.add(m.key);sum+=number(m.amount);}
  const opening=reconstructed-net;
  if(Math.abs(sum-number(a.pending_total_brl))>0.005||Math.abs(opening+sum-observed)>0.005)return null;
  return {bank,opening,observed,net:sum,sourceDate:a.source_date,movements:a.movements,settled:false};
 }
 const api={label,identity,groups,cardLabel,bridge};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSV423Clarity=api;
})(typeof window==='undefined'?globalThis:window);
