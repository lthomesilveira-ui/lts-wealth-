(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render;let selected='';
  const money=v=>v===null||v===undefined?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function time(v){if(!v||Number.isNaN(new Date(v).getTime()))return '';return new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short',timeZone:'America/Sao_Paulo'}).format(new Date(v));}
  function pair(root,label,amount){const row=document.createElement('div'),span=document.createElement('span'),b=document.createElement('b');row.className='v402-d01-pair';span.textContent=label;b.textContent=money(amount);row.append(span,b);root.append(row);}
  function after(){
   if(V!=='Fluxo Diário'||ACC!=='Consolidado'||typeof FLOWQ==='undefined')return;
   const controls=document.querySelector('.flow-sticky-controls');if(!controls||document.getElementById('v402-d01-origin'))return;
   const days=[...(FLOWQ?.historical?.days||[]),...(FLOWQ?.current_future?.days||[])].filter(d=>d.fix86_columns?.d0_composition?.has_anchor);
   if(!days.length)return;
   if(!days.some(d=>d.date===selected))selected=days[0].date;
   const box=document.createElement('details'),summary=document.createElement('summary'),select=document.createElement('select'),body=document.createElement('div');
   box.id='v402-d01-origin';summary.textContent='D0/D1 · composição';box.append(summary);
   const label=document.createElement('label');label.textContent='Data ';select.setAttribute('aria-label','Data da composição D0/D1');
   for(const d of days){const o=document.createElement('option');o.value=d.date;o.textContent=date(d.date);select.append(o);}select.value=selected;label.append(select);box.append(label,body);
   function show(){selected=select.value;body.replaceChildren();const d=days.find(x=>x.date===selected),p=d.fix86_columns.d0_composition;
    for(const c of p.components||[])pair(body,'Saldo líquido · '+c.code,c.net_brl);
    pair(body,'Posição do Itaú · '+date(p.snapshot_date),p.snapshot_brl);
    for(const m of p.recorded_movements||[])pair(body,(m.asset_delta_brl<0?'Resgate':'Aplicação')+' · '+date(m.event_date),m.asset_delta_brl);
    for(const x of p.bank_redemptions||[])if(!x.represented_by_recorded_movement&&!x.representation_conflict)pair(body,'Resgate · '+date(x.event_date),-Number(x.bank_amount_brl));
    pair(body,'Cofrinho disponível',p.available_brl);pair(body,'Saldo em conta',d.fix86_columns.saldo_final);pair(body,'Saldo com D0/D1',d.fix86_columns.saldo_apos_d0_1);
    const consulted=time(p.source_observed_at);if(consulted){const line=document.createElement('p');line.textContent='Consultado em '+consulted+'.';body.append(line);}
    const note=document.createElement('p');note.textContent=p.complete?'Ações e FGTS são apresentados separadamente.':'Saldo do Cofrinho a conferir no banco.';body.append(note);
   }
   select.addEventListener('change',show);show();controls.after(box);
   const today=days.find(d=>d.date===new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo'}).format(new Date()));
   const current=today?.fix86_columns?.d0_composition;
   if(current&&(current.complete===false||current.provider_comparison_equal===false||current.daily_provider_position_available===false)){
    const warning=document.createElement('p');warning.id='v402-d01-warning';warning.setAttribute('role','status');warning.textContent=current.complete!==false&&current.daily_provider_position_available===false?'Atualização do saldo do Cofrinho pendente.':'Saldo do Cofrinho a conferir no banco.';box.before(warning);
   }
  }
  const style=document.createElement('style');style.textContent='#v402-d01-origin{margin:8px 0 12px;padding:8px 12px;border:1px solid #dce4ed;border-radius:10px;font-size:13px}#v402-d01-origin summary{cursor:pointer;font-weight:600}#v402-d01-origin label{display:block;margin:10px 0}#v402-d01-origin select{font-size:16px;min-height:44px;max-width:100%}.v402-d01-pair{display:flex;justify-content:space-between;gap:10px;padding:5px 0}.v402-d01-pair span{min-width:0;overflow-wrap:anywhere}.v402-d01-pair b{white-space:nowrap}#v402-d01-origin p{color:#64748b;line-height:1.45;margin:8px 0 2px}#v402-d01-warning{color:#8b4b08;font-size:13px;line-height:1.4;margin:8px 0}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V402_D01={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V402_D01?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V402_D01?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v402-d01-composition.js',install);
})();
