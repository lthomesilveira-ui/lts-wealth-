/* V183 candidate: suppress derived totals when the bank basis is unavailable. */
(function(){
  'use strict';
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V182_FEEDBACK?.installed)return false;
      if(d.getElementById('v183-historical-balance-guard-runtime'))return true;
      const runtime=function(){
        const policy=window.parent.LTSHistoryCoverage;
        if(!policy)return;
        const explanation='Saldo histórico não confirmado neste período. As entradas e saídas continuam disponíveis.';
        const bankExplanation='Saldo histórico desta conta não confirmado. As entradas e saídas continuam disponíveis.';
        let pending=false;
        const dayFormatter=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'});
        const today=()=>dayFormatter.format(new Date());
        function guard(){
          pending=false;
          const rows=document.querySelectorAll('.fx87-row[id^="d-"]');
          // Wait for the authenticated product state; rendering and historical data
          // may arrive independently. Never derive a position from missing data.
          if(typeof D==='undefined'||!D)return;
          // One fresh local date per render; never retain it across midnight.
          const currentDay=today();
          const days=typeof mergedFlowDays==='function'?mergedFlowDays():[],dayMap=new Map(days.map(x=>[x.date,x]));
          const relative=new Set(days.filter(x=>x?.historical&&x.relative_balance_display===true).map(x=>x.date));
          // The v12 historical upgrade can replace v11 days without carrying its
          // per-day truth flags. Keep the documentary opening from the v11 contract.
          const contract=typeof FLOWQ!=='undefined'?FLOWQ?.historical_balance_truth_contract:null;
          const opening=String(contract?.consolidated_first_complete_opening||'');
          const account=typeof ACC==='undefined'?'Consolidado':ACC;
          const bankOpening=String(({Itaú:contract?.itau_first_documentary_opening,Bradesco:contract?.bradesco_first_documentary_opening,C6:contract?.c6_first_documentary_opening})[account]||'');
          const controls=document.querySelector('.flow-sticky-controls');
          controls?.querySelector('.v183-history-coverage')?.remove();
          let masked=0;
          for(const row of rows){
            const cells=row.children;
            const day=row.id.slice(2);
            const status=policy.dayStatus(day,account,contract);
            const record=dayMap.get(day),position=record?.[account];
            const documentary=record?.historical===true&&(position?.workbook_cash_reconciled===true||position?.documentary_reconstruction===true)
              &&(account==='Consolidado'||!!position.workbook_evidence_ref||!!position.documentary_anchor_ref)
              &&(account==='Consolidado'?position.bank_balance:position.balance)!=null
              &&Number.isFinite(Number(account==='Consolidado'?position.bank_balance:position.balance))
              &&(account==='Consolidado'?record.v170_cash_arithmetic?.balanced===true:Math.abs(Number(position.source_arithmetic_gap))<.005);
            if(documentary){row.dataset.historyCoverage='documented_workbook';row.title='Posição histórica reconstruída a partir das fontes identificadas. Não é certificação integral por extrato.';continue}
            row.dataset.historyCoverage=status;
            const uncertified=status==='uncertified'||status==='unavailable';
            if(row.classList.contains('fx87-bank')){
              if(cells.length<5||(!uncertified&&(day>=currentDay||(bankOpening&&day>=bankOpening))))continue;
              for(const index of [1,4]){
                const cell=cells[index];
                if(cell.textContent.trim()==='—')continue;
                cell.textContent='—';cell.title=uncertified?policy.uncertifiedMessage:bankExplanation;cell.classList.remove('neg','pos');
              }
              row.classList.add('v183-relative-history');masked++;continue;
            }
            if(!row.classList.contains('fx87-cons')||cells.length<11)continue;
            const beforeDocumentaryOpening=day<currentDay&&(!opening||day<opening);
            const missingBankBasis=cells[1].textContent.trim()==='—'||cells[4].textContent.trim()==='—';
            if(!uncertified&&!relative.has(day)&&!missingBankBasis&&!beforeDocumentaryOpening)continue;
            for(const index of [1,4,6,8,10]){
              const cell=cells[index];
              if(cell.textContent.trim()==='—')continue;
              cell.textContent='—';cell.title=uncertified?policy.uncertifiedMessage:explanation;cell.classList.remove('neg','pos');
            }
            row.classList.add('v183-relative-history');masked++;
          }
          if(masked){
            let note=controls?.querySelector('.v183-balance-basis-note');
            if(controls&&!note){note=document.createElement('p');note.className='v183-balance-basis-note';note.setAttribute('role','status');note.style.cssText='margin:8px 12px;padding:9px 12px;border-radius:9px;background:#fff5df;color:#60451e;font-size:12px;line-height:1.45';controls.appendChild(note)}
            const reason=account==='Consolidado'?explanation:bankExplanation;
            if(note&&note.textContent!==reason)note.textContent=reason;
            const old=document.querySelector('.v168-history-note');
            if(old&&!old.hidden)old.hidden=true;
          }else{
            document.querySelector('.v183-balance-basis-note')?.remove();
            const old=document.querySelector('.v168-history-note');
            if(old&&old.hidden)old.hidden=false;
          }
        }
        const observer=new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(guard)}});
        observer.observe(document.body,{childList:true,subtree:true,characterData:true});
        const originalRender=render;
        render=function(){const result=originalRender();guard();return result};
        window.__LTS_V183_HISTORICAL_BALANCE_GUARD={installed:true,policy:'independent-expense-and-reconciled-balance-coverage',operational_from:policy.operationalFrom,finance_rows_changed:false};
        guard();
      };
      const script=d.createElement('script');script.id='v183-historical-balance-guard-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return true;
    }catch{return false}
  }
  let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{attempts=0;if(!install())setTimeout(install,300)});
})();
