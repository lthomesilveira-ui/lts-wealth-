'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const path=require('node:path');
const {webkit,chromium}=require('playwright');
(async()=>{
 const file=path.resolve('qa/v387/v387-email-preview.html');
 const html=fs.readFileSync(file,'utf8');
 const evidence=[];
 assert(html.includes('R$ 190,00'));
 assert(html.includes('Referência do aviso: TR-'));
 assert(!html.includes('@gmail.com'));
 for(const[name,engine]of Object.entries({webkit,chromium})){
  const browser=await engine.launch({headless:true});
  for(const variant of['native-plan','long-amounts']){
   for(const width of[320,360,393,430,852,1366]){
    const page=await browser.newPage({viewport:{width,height:900}});
    await page.goto('file://'+file);
    await page.evaluate(()=>document.fonts.ready);
    if(variant==='long-amounts')await page.evaluate(()=>{
     for(const cell of document.querySelectorAll('tbody tr td:last-child'))cell.textContent='R$ 1.234.567,89';
    });
    const result=await page.evaluate(()=>{
     const numbers=[...document.querySelectorAll('tbody tr td:last-child')].filter(x=>x.textContent.includes('R$'));
     return{
      scroll:document.documentElement.scrollWidth,viewport:innerWidth,
      numbers:numbers.map(x=>{
       const box=x.getBoundingClientRect(),range=document.createRange();range.selectNodeContents(x);
       const text=range.getBoundingClientRect(),style=getComputedStyle(x);
       return{text:x.textContent,nowrap:style.whiteSpace,lines:range.getClientRects().length,
        inside:text.left>=box.left-1&&text.right<=box.right+1&&text.top>=box.top-1&&text.bottom<=box.bottom+1};
      }),
      rows:document.querySelectorAll('tbody tr').length,text:document.body.innerText
     };
    });
    const label=`${name}-${width}-${variant}`;
    await page.screenshot({path:`qa/v387/email-${label}.png`,fullPage:true});
    fs.writeFileSync(`qa/v387/metrics-${label}.json`,JSON.stringify(result,null,2));
    assert(result.scroll<=width+1,`${label}: horizontal overflow ${result.scroll}`);
    assert.equal(result.rows,4);
    assert(result.text.includes('não repetir a transferência'));
    assert(result.text.includes('Confirme o valor liberado'));
    for(const n of result.numbers){
     assert.equal(n.nowrap,'nowrap',`${label}: amount can wrap ${n.text}`);
     assert.equal(n.lines,1,`${label}: amount split ${n.text}`);
     assert(n.inside,`${label}: amount clipped ${n.text}`);
    }
    evidence.push({engine:name,width,variant,pass:true,rows:result.rows});
    await page.close();
   }
  }
  await browser.close();
 }
 const result={pass:true,cold_openings:evidence.length,evidence,synthetic:true,actual_inbox_mobile_certified:false};
 fs.writeFileSync('qa/v387/email-layout-results.json',JSON.stringify(result,null,2));
 console.log(JSON.stringify({pass:true,cold_openings:evidence.length}));
})().catch(e=>{console.error(e);process.exit(1)});
