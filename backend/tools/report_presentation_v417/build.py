"""Build or verify an immutable UI release without changing its predecessor."""
from pathlib import Path
import hashlib, json, shutil, tempfile
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'releases/v415'; TARGET=ROOT/'releases/v417'; DST=TARGET
work=None
if TARGET.exists():
    work=tempfile.TemporaryDirectory(); DST=Path(work.name)/'v417'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(text, old, new, count=1):
    assert text.count(old)==count, ('unexpected predecessor',old[:100],text.count(old))
    return text.replace(old,new)
manifest=json.loads((SRC/'manifest.json').read_text())
for name, expected in manifest['files'].items():
    assert digest(SRC/name)==expected, ('changed published source',name)
assert not DST.exists(), 'Never overwrite a release'
shutil.copytree(SRC,DST)
p=DST/'lts-v412-projection-policy.js'; s=p.read_text()
s=replace(s,"      const series = payload.series.map(row => {", """      const series = payload.series.map(row => {
        const expected = row?.expected_months;
        const cardBudget = row?.method === 'history_total_budget' && /^card_/.test(row?.series_key || '');""")
s=replace(s,"row.expected_months !== 12", "!(expected === 12 || expected === 3 && cardBudget)")
s=replace(s,"row.coverage_months > 12", "row.coverage_months > expected")
s=replace(s,"row.observed_months > 12", "row.observed_months > expected")
s=replace(s,"row.coverage_months < 12", "row.coverage_months < expected")
s=replace(s,"        const referenceWindow = windowDates(row.reference_window), amount = cents(row.reference_amount_brl, true);", """        const referenceWindow = windowDates(row.reference_window), amount = cents(row.reference_amount_brl, true);
        if (expected === 3) {
          const start = new Date(referenceWindow.from + 'T12:00:00Z');
          const end = new Date(start); end.setUTCMonth(end.getUTCMonth() + expected); end.setUTCDate(end.getUTCDate() - 1);
          if (!referenceWindow.from.endsWith('-01') || end.toISOString().slice(0, 10) !== referenceWindow.to
            || referenceWindow.to >= asOf.slice(0, 7) + '-01') return invalid();
        }""")
s=replace(s,"covered: row.coverage_months, observed:","expected, covered: row.coverage_months, observed:")
s=replace(s,"': mantida a última média completa enquanto chegam os dados da revisão anual.'", "': usando a última média completa.'")
s=replace(s,"': histórico incompleto; a estimativa ainda precisa de conferência.'", "': histórico incompleto.'")
s=replace(s,"': há períodos sem valor ou data conferidos.'", "': há previsões a conferir.'")
s=replace(s,"return 'Média nominal de 12 meses completos. A revisão anual usa novas observações; meses sem gasto entram como zero somente quando o acervo do mês está coberto.';", "return 'Média de ' + row.expected + ' meses completos' + (row.expected === 3 ? ', atualizada com as novas faturas.' : '.');")
s=replace(s,"'Calendário histórico com premissa de '","'Reajuste estimado de '")
s=replace(s,"' ao ano, aplicada uma vez desde a data-base. Valores futuros documentados têm prioridade.'", "' ao ano. Cobranças confirmadas têm prioridade.'")
s=replace(s,"'Base nominal confirmada menos a parcela documentada do empréstimo em folha, uma única vez. O líquido efetivamente recebido permanece separado.'", "'Salário previsto após o desconto do empréstimo em folha.'")
s=replace(s,"'Repetição do calendário e dos valores de referência confirmados, sem aumento automático.'", "'Calendário e valores mantidos, sem aumento automático.'")
s=replace(s,"'Valor nominal confirmado, mantido durante a vigência da regra, sem aumento automático.'", "'Valor mantido, sem aumento automático.'")
s=replace(s,"el('summary', 'Origem das projeções')", "el('summary', 'Premissas das projeções')")
s=replace(s,"details.append(el('p', 'Horizonte até ' + date(model.horizon) + '. Na virada do ano, o horizonte acrescenta mais um ano completo. Próxima revisão das médias: ' + date(model.nextReview) + '.'));", "details.append(el('p', 'Planejamento até ' + date(model.horizon) + ', com extensão anual.'));\n      warningTexts(model).forEach(text => details.append(message(text)));")
s=replace(s,"row.covered + ' de 12 meses cobertos.","row.covered + ' de ' + row.expected + ' meses cobertos.")
s=replace(s,"row.covered + ' de 12 meses cobertos; '","row.covered + ' de ' + row.expected + ' meses cobertos; '")
s=replace(s,"'Nos cartões, o orçamento total é o maior entre a média e os valores já conhecidos. Somente a diferença entra como complemento. Uma fatura fechada ou pagamento confirmado substitui a estimativa do ciclo. Compras adicionais podem superar o orçamento quando as parcelas conhecidas já são maiores que a média.'", "'Faturas fechadas prevalecem. Parcelas antigas de gastos não recorrentes continuam até terminar; as reservas de novas compras não são somadas duas vezes.'")
s=replace(s,"else { warningTexts(state.model).forEach(text => card.append(message(text))); card.append(origin(state.model)); }", "else { const warnings = warningTexts(state.model); if (warnings.length) card.append(message('Há estimativas a conferir nas premissas.')); card.append(origin(state.model)); }")
p.write_text(s)
shutil.copyfile(Path(__file__).with_name('clean_reports.js'),DST/'lts-v417-clean-reports.js')
p=DST/'app.html'; s=p.read_text().replace('V415','V417').replace('v415-durable-refresh-20261105','v417-report-presentation')
s=replace(s,'</body>','<script src="lts-v417-clean-reports.js"></script>\n</body>')
p.write_text(s)
provenance={'release':'v417','base_release':'v415',
 'protected_base_files':{x.name:digest(x) for x in sorted(SRC.iterdir()) if x.is_file()},
 'financial_event_writers_added':False,'received_financial_payloads_modified':False,
 'client_recalculates_financial_totals':False,'auth_storage_changed':False,
 'private_http_validated':False,'physical_mobile_validated':False,
 'scope':'three-month card display compatibility and concise report notices'}
(DST/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
manifest['protected_manifest']={'path':'releases/v415/manifest.json','sha256':digest(SRC/'manifest.json')}
manifest.update(release='v417',version='v417',base_release='v415')
manifest['files']={name:digest(DST/name) for name in sorted(set(manifest['files'])|{'lts-v417-clean-reports.js'})}
(DST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'release':'v417','changed':[n for n,v in manifest['files'].items() if v!=json.loads((SRC/'manifest.json').read_text())['files'].get(n)],'source_release_unchanged':True}))
if work:
    assert {x.name:digest(x) for x in DST.iterdir()}=={x.name:digest(x) for x in TARGET.iterdir()}, 'Published candidate differs from deterministic source'
    work.cleanup()
