(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,ids=['cipo_396','volvo','coopharma','pai_mae'];
  const money=value=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);
  function cents(value){
   if(value===null||value===undefined||!['string','number'].includes(typeof value)||!/^[-]?\d+(?:\.\d{1,2}0*)?$/.test(String(value)))return null;
   const n=Number(value),c=Math.round(n*100);return Number.isFinite(n)&&Number.isSafeInteger(c)?c:null;
  }
  function validDate(value){return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;}
  function assess(j){
   const gross=cents(j?.wealth_v167?.assets_central_including_pensions),known=cents(j?.wealth?.summary?.known_debt_total),commitments=j?.financing?.summary?.commitments,sourceDate=j?.financing?.summary?.as_of,asOf=validDate(sourceDate)?sourceDate:j?.as_of;
   if(gross===null||known===null||known<0||!validDate(asOf)||!Array.isArray(commitments))return {available:false};
   let documented=0,total=0;const missing=[];
   for(const id of ids){
    const rows=commitments.filter(c=>c?.id===id);if(rows.length>1)return {available:false};
    const c=rows[0],value=cents(c?.current_documentary_debt_balance);
    if(value!==null&&value>=0&&validDate(c?.current_debt_as_of)&&c.current_debt_as_of<=asOf){documented++;total+=value;}else missing.push(id);
   }
   const net=gross-known;
   if(!documented||!Number.isSafeInteger(total)||total!==known||!Number.isSafeInteger(net))return {available:false};
   return {available:true,gross:gross/100,known:known/100,net:net/100,documented,missing};
  }
  function pair(root,label,value){const row=document.createElement('div'),name=document.createElement('span'),amount=document.createElement('b');row.className='v407-wealth-pair';name.textContent=label;amount.textContent=money(value);row.append(name,amount);root.append(row);}
  function after(){
   if(V!=='Patrimônio'||window.__LTS_V168_STATE?.wealth?.tab!=='overview')return;
   const card=document.querySelector('.v365-wealth-totals .v386-incomplete-value')?.closest('article');if(!card||card.dataset.v407Partial==='true')return;
   const result=assess(window.__LTS_V168_STATE.wealth.data);if(!result.available)return;
   card.dataset.v407Partial='true';card.querySelector('span').textContent='Patrimônio líquido parcial';
   const value=card.querySelector('strong');value.classList.remove('v386-incomplete-value');value.textContent=money(result.net);
   card.querySelector('small').textContent='Bruto conhecido menos passivos documentados. Saldos pendentes podem alterar o total.';
   const detail=document.createElement('details'),summary=document.createElement('summary');detail.className='v407-wealth-basis';summary.textContent='Composição do subtotal';detail.append(summary);
   pair(detail,'Patrimônio bruto conhecido',result.gross);pair(detail,'Passivos documentados',result.known);pair(detail,'Patrimônio líquido parcial',result.net);card.append(detail);
  }
  const style=document.createElement('style');style.textContent='[data-v407-partial] strong{white-space:nowrap}.v407-wealth-basis{margin-top:10px;font-size:12px;font-weight:400}.v407-wealth-basis>summary{cursor:pointer;min-height:24px;line-height:1.5;color:#536174}.v407-wealth-pair{display:flex;flex-wrap:wrap;justify-content:space-between;gap:3px 8px;margin-top:7px}.v407-wealth-pair>span{font-size:12px!important;color:#536174}.v407-wealth-pair>b{white-space:nowrap;font-size:12px}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};window.__LTS_V407_WEALTH={installed:true,assess,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_WEALTH?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_WEALTH?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-wealth-summary.js',install);
})();
