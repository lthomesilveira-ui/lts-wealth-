"""Build an immutable customer-facing expense and Flow correction."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'releases/v458'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def once(p,a,b):
 s=p.read_text();assert s.count(a)==1,(p.name,a[:90],s.count(a));p.write_text(s.replace(a,b))
def copies(target,a,b,minimum=1):
 count=0
 for p in sorted(target.iterdir()):
  if p.suffix not in ('.js','.html'):continue
  s=p.read_text();n=s.count(a)
  if n:p.write_text(s.replace(a,b));count+=n
 assert count>=minimum,(a[:100],count)
 return count
def build(target):
 shutil.copytree(BASE,target)
 app=target/'app.html';assert app.read_text().count('V458')==5;app.write_text(app.read_text().replace('V458','V463'))
 # Keep bank dates and the actual dated cash flow; remove reconciliation tables.
 copies(target,"if(html&&!detail.querySelector('.v365-bridge'))detail.insertAdjacentHTML('beforeend',html);","detail.querySelectorAll('.v365-bridge').forEach(node=>node.remove());")
 clarity=target/'lts-v423-clarity.js';s=clarity.read_text();a=s.index('  function update(){');b=s.index('  const previous=render;',a)
 s=s[:a]+"  function update(){\n   if(product!==D||identity!==BOOT?.generation){product=D;identity=BOOT?.generation;clear();}\n   document.querySelectorAll('.v365-bridge,.v423-bank-evidence').forEach(node=>node.remove());\n  }\n"+s[b:];clarity.write_text(s)
 # Risk scenarios remain in Dashboard. Flow premises retain their original menu.
 flow=target/'lts-v441-flow-summary.js';s=flow.read_text();a=s.index('   const controls=');b=s.index('   let premises=',a)
 s=s[:a]+"   const body=document.querySelector('.v382-tool-body');if(!body)return;old?.remove();\n"+s[b:]
 s=s.replace('As datas acima usam','Os cenários usam');flow.write_text(s)
 # Canonical presentation cells keep original categories and their payment channel.
 model=target/'lts-expense-presentation-model.js'
 once(model,"for(const k of dims)if(requested[k])scope[k]=String(requested[k]);", "for(const k of dims)if(requested[k])scope[k]=String(requested[k]);\n  const paymentAvailable=p.cells.every(c=>['card','account'].includes(c.payment));\n  if(requested.payment){if(!['card','account'].includes(requested.payment)||!paymentAvailable)throw Error('A separação por forma de pagamento ainda não está disponível.');scope.payment=requested.payment;}")
 once(model,"const cells=p.cells.filter(c=>dims.every", "const cells=p.cells.filter(c=>(!scope.payment||c.payment===scope.payment)&&dims.every")
 once(model,"steps.push(['macrogroup',c.macrogroup,c.macrogroup],['group',c.group_name,c.group_name],['category',c.category,c.category]);", "steps.push(['macrogroup',c.macrogroup,c.macrogroup]);\n   if(c.category!==c.macrogroup)steps.push(['category',c.category,c.category]);")
 once(model,"scope,summary,nodes:array(tree),dimensions:p.dimensions", "scope,summary,nodes:array(tree),dimensions:p.dimensions,paymentAvailable")
 for bundle in ['lts-v384-startup-1.js','lts-v384-startup-2.js']:
  p=target/bundle;before=(BASE/'lts-expense-presentation-model.js').read_text();bundled=p.read_text()
  if before in bundled:
   assert bundled.count(before)==1;p.write_text(bundled.replace(before,model.read_text()))
 old="'<div class=\"v353-presentation\"><div class=\"v353-metrics\">'"
 new="'<div class=\"v353-presentation\"><label class=\"v463-payment\">Mostrar gastos de<select data-v353-filter=\"payment\" aria-label=\"Forma de pagamento\"'+(model.paymentAvailable?'':' disabled')+'>'+[['','Todos os gastos'],['card','Todos os cartões'],['account','Contas correntes']].map(([key,label])=>'<option value=\"'+key+'\"'+((scope.payment||'')===key?' selected':'')+'>'+label+'</option>').join('')+'</select></label><div class=\"v353-metrics\">'"
 copies(target,old,new,2)
 copies(target,'Macrogrupo → Grupo → Categoria. Clique em um valor para consultar os lançamentos.','Abra uma categoria ou toque no valor para ver os lançamentos.',2)
 copies(target,'Maiores grupos gerenciais','Despesas por categoria',2)
 copies(target,'/maiores grupos/i.test','/maiores grupos|despesas por categoria/i.test',2)
 copies(target,"metric('Gasto bruto',s.gross,'gross')","metric('Gastos',s.gross,'gross')",2)
 copies(target,"metric('Compensações',s.compensations,'compensations',-s.compensations)","metric('Créditos e estornos',s.compensations,'compensations',-s.compensations)",2)
 copies(target,"metric('Líquido',s.net,'net')","metric('Total',s.net,'net')",2)
 copies(target,"(d.loading?'Carregando…':'Nenhum lançamento neste filtro.')", "(d.loading?'Carregando…':d.error?'Não foi possível carregar os lançamentos.':'Nenhum lançamento neste filtro.')",2)
 copies(target,"Não foi possível conferir esta lista. Atualize o relatório antes de usar este total.","Não foi possível carregar os lançamentos. Tente novamente.",2)
 for name in ['lts-v179-cash-recovery.js','lts-v384-startup-1.js']:
  p=target/name;s=p.read_text();a=s.index('  async function openDetail(group,subgroup,range,expected,restore=null){');b=s.index('  function compositionOrigin',a);part=s[a:b]
  part=part.replace('count:null,total:null};shellDetail();','count:null,total:null,deferredRetries:restore?.deferredRetries||0};shellDetail();')
  old="}catch(e){if(token===sequence)d.error=d.scope?'Não foi possível carregar os lançamentos. Tente novamente.':String(e.message||e)}"
  assert part.count(old)==1
  part=part.replace(old,"}catch(e){if(token===sequence){d.deferred=String(e?.code)==='55000';d.error='Não foi possível carregar os lançamentos. Tente novamente.';}}")
  listener="  window.addEventListener('lts:product-refresh-ready',()=>{\n   const d=state.detail;if(!d?.deferred||d.loading||d.deferredRetries>=1||d.route!==V||!D||N.classList.contains('hidden'))return;\n   openDetail(d.group,d.subgroup,d.range,d.expected,{query:d.query,scope:d.scope,visibleRows:d.visibleRows,deferredRetries:d.deferredRetries+1});\n  });\n"
  p.write_text(s[:a]+part+listener+s[b:])
 copies(target,"r.source_audit?.file||r.source_identity?.sheet||r.source_table||'Fonte registrada'", "r.source_audit?.file||r.source_identity?.sheet||'Extrato ou registro anterior'",2)
 copies(target,"+'<br>Referência: '+escape(r.source_ref||'—')", "",2)
 # Plain language for received history and genuinely unconfirmed payments.
 labels={
 'Faturas com documento, ainda sem conciliação operacional':'Faturas com pagamento a conferir',
 'Estas evidências não criam nova saída, despesa ou dívida. Um débito de mesmo banco, data e valor é apenas candidato; pagamento deste cartão não foi confirmado.':'O documento foi recebido. O pagamento ainda precisa ser identificado no extrato.',
 'Faturas históricas importadas':'Faturas anteriores',
 'Os itens destas faturas fecham com o total importado. Elas ainda não integram o cadastro atual; sua exibição não adiciona saída ao Fluxo nem confirma pagamento no banco.':'Consulte as compras das faturas anteriores. O pagamento ainda não foi identificado no extrato.',
 'Composição conferida na importação. Pagamento bancário deste cartão ainda não confirmado.':'Pagamento ainda não identificado no extrato.',
 'Composição documental ainda não conciliada com o total.':'As compras recebidas ainda não fecham com o total da fatura.',
 'Sem fatura aberta informada':'Fatura ainda não disponível',
 'Inventário histórico indisponível. Os cartões ainda não podem ser conferidos integralmente.':'Não foi possível carregar o histórico dos cartões.',
 'Presença no histórico não comprova fatura individual para todos os meses. Produtos sem identificação documental continuam pendentes.':'',
 'Não há fatura individual cadastrada neste recorte. Os agregados históricos ainda precisam de composição e conferência por cartão.':'Não há fatura detalhada disponível neste período.',
 'Posição a conciliar':'Saldo a conferir',
  'Projeções não verificadas.':'Não foi possível atualizar a previsão.',
 'Sem quitação comprovada.':'Pagamento ainda não identificado.',
 'Saldo documental em ':'Posição em ',
 'Passivos documentados':'Dívidas com saldo informado',
 'Passivos</h2>':'Dívidas</h2>',
 'Bruto conhecido menos passivos documentados. Saldos pendentes podem alterar o total.':'Estimativa com os saldos disponíveis. Há dívida a atualizar.',
 'Subtotal parcial · ':'Parcial · ',
 ' saldos documentados':' saldos informados',
 }
 for a,b in labels.items():copies(target,a,b)
 for name in ['lts-v463-debt-model.js','lts-v463-debt-ui.js']:shutil.copyfile(Path(__file__).parent/name,target/name)
 once(app,'</body>','<script src="lts-v463-debt-model.js"></script>\n<script src="lts-v463-debt-ui.js"></script>\n</body>')
 style=target/'lts-v463-customer.css';style.write_text('.v463-payment{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:0 0 16px;font-weight:600}.v463-payment select{flex:1;min-width:180px;max-width:100%;min-height:44px;border:1px solid #cad5e1;border-radius:9px;padding:10px;background:#fff;color:#17334e}#release-badge-v183{display:none!important}.v463-debt-basis{margin-top:10px;font-size:13px;font-weight:400}.v463-debt-basis summary{cursor:pointer;min-height:32px}.v463-debt-basis p{font-size:13px;line-height:1.5}\n')
 once(app,'</head>','<link rel="stylesheet" href="lts-v463-customer.css">\n</head>')
 # The iframe needs the same expense-control style, without changing source facts.
 once(target/'index.html','</head>','<link rel="stylesheet" href="lts-v463-customer.css">\n</head>')
 (target/'provenance.json').write_text(json.dumps({'release':'v463','base_release':'v458','scope':'Customer Flow, meaningful categories, card/account scopes and accurate detail failure states','backend_reader_dependency':'expense_payment_scope_v464','financial_source_writes':False,'authentication_changed':False,'timeouts_changed':False,'published_base_immutable':True,'physical_mobile_validated':False},indent=2)+'\n')
 (target/'manifest.json').write_text(json.dumps({'release':'v463','version':'v463','base_release':'v458','entry':'app.html','protected_manifest':{'path':'releases/v458/manifest.json','sha256':digest(BASE/'manifest.json')},'files':{p.name:digest(p)for p in sorted(target.iterdir())if p.name!='manifest.json'}},indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
 with tempfile.TemporaryDirectory()as tmp:
  generated=Path(tmp)/'v463';build(generated);actual=ROOT/'releases/v463'
  if args.check:assert{p.name:p.read_bytes()for p in actual.iterdir()}=={p.name:p.read_bytes()for p in generated.iterdir()}
  else:assert not actual.exists(),'Never overwrite a published release';shutil.copytree(generated,actual)
 print(json.dumps({'pass':True,'release':'v463','protected_base':'v458'}))
