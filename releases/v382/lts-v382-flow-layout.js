/* Presentation only: retain the existing Flow inputs, handlers and financial readers. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V382_FLOW_LAYOUT)return;
  const previous=render;
  let expanded=false,toolsExpanded=false;
  const day=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''))?value.split('-').reverse().join('/'):'Selecione as datas';
  function label(text,node){
   const wrapper=document.createElement('label');wrapper.className='v382-field';
   const caption=document.createElement('span');caption.textContent=text;wrapper.append(caption,node);return wrapper;
  }
  function decorate(){
   if(V!=='Fluxo Diário')return;
   const root=document.querySelector('.flow-sticky-controls');if(!root)return;
   const existing=root.querySelector('.v382-period');
   if(existing){
    existing.querySelector('.v382-period-range').textContent=day(FLOWFROM)+' – '+day(FLOWTO);return;
   }
   const from=document.getElementById('flowFrom'),to=document.getElementById('flowTo'),year=document.getElementById('flowYear');
   const bank=root.querySelector('[data-a]')?.closest('.chips'),host=from?.closest('.chips');
   if(!from||!to||!year||!bank||!host||bank===host)return;
   root.classList.add('v382-flow-controls');bank.classList.add('v382-banks');
   // Finish a native picker before an existing action triggers a render. The
   // editing guard otherwise defers that render while the picker keeps focus.
   root.addEventListener('click',event=>{
    if(!event.target.closest('button,summary'))return;
    const active=document.activeElement;
    if(root.contains(active)&&active.matches('input,select,textarea'))active.blur();
   },true);
   const heading=root.querySelector(':scope>.flowbar'),toolbar=heading?.querySelector('.chips');
   if(toolbar){
    heading.classList.add('v382-flow-heading');
    const tools=document.createElement('details');tools.className='v382-tools';tools.open=toolsExpanded;
    const menu=document.createElement('summary');menu.textContent='Opções';
    const panel=document.createElement('div');panel.className='v382-tool-body';panel.appendChild(toolbar);tools.append(menu,panel);heading.appendChild(tools);
    tools.addEventListener('toggle',()=>{if(tools.isConnected)toolsExpanded=tools.open;});
   }
   bank.setAttribute('role','group');bank.setAttribute('aria-label','Contas do Fluxo');
   bank.querySelectorAll('[data-a]').forEach(button=>button.setAttribute('aria-pressed',String(button.classList.contains('active'))));
   const details=document.createElement('details');details.className='v382-period';details.open=expanded;
   const summary=document.createElement('summary'),title=document.createElement('span'),range=document.createElement('span');
   title.className='v382-period-title';title.textContent='Período';range.className='v382-period-range';range.textContent=day(FLOWFROM)+' – '+day(FLOWTO);
   summary.append(title,range);details.appendChild(summary);
   const body=document.createElement('div');body.className='v382-period-body';
   const presets=document.createElement('div');presets.className='v382-presets';presets.setAttribute('role','group');presets.setAttribute('aria-label','Períodos rápidos');
   host.querySelectorAll('[data-p],#flowDefaultRange').forEach(button=>presets.appendChild(button));body.appendChild(presets);
   year.setAttribute('aria-label','Ano do período do Fluxo');body.appendChild(label('Histórico por ano',year));
   const dates=document.createElement('div');dates.className='v382-dates';
   from.setAttribute('aria-label','Data inicial do Fluxo');to.setAttribute('aria-label','Data final do Fluxo');
   dates.append(label('De',from),label('Até',to));body.appendChild(dates);
   const actions=document.createElement('div');actions.className='v382-period-actions';
   for(const id of ['flowApply','flowZero']){const node=document.getElementById(id);if(node)actions.appendChild(node);}
   body.appendChild(actions);
   // Preserve any future controls or meaningful notices added to the legacy host.
   for(const node of [...host.childNodes]){
    if(node.nodeType===3&&!node.textContent.trim())continue;
    if(node.nodeType===1&&node.matches('span.pill')&&node.textContent.includes('Histórico completo:'))continue;
    body.appendChild(node);
   }
   details.appendChild(body);bank.after(details);host.remove();
   details.addEventListener('toggle',()=>{if(details.isConnected)expanded=details.open;});
  }
  render=function(){
   const details=document.querySelector('.v382-period');
   const tools=document.querySelector('.v382-tools');if(tools)toolsExpanded=tools.open;
   if(details)expanded=details.open;
   else if(V!=='Fluxo Diário')expanded=false;
   const result=previous.apply(this,arguments);decorate();return result;
  };
  window.__LTS_V382_FLOW_LAYOUT={installed:true,presentation_only:true};decorate();
 }
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V365?.installed||!w?.__LTS_V183_FLOW_PERIOD_STATE?.installed||!w?.__LTS_V290_USABILITY?.installed)return false;
   if(w.__LTS_V382_FLOW_LAYOUT)return true;
   const link=d.createElement('link');link.rel='stylesheet';link.href=new URL('lts-v382-flow-layout.css',location.href).href;d.head.appendChild(link);
   const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
   return !!w.__LTS_V382_FLOW_LAYOUT;
  }catch{return false;}
 }
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}
 shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v382-flow-layout.js',install);
})();
