# LTS Wealth — Homologação V135 → V137 — incidentes 2026-08-29

Este arquivo complementa `PROJECT_MASTER_BACKLOG.md` e preserva fora do chat os incidentes observados na homologação real. Não substitui a lista-mestra.

## Status geral
- V137 reprovada para promoção.
- Baseline pública/fallback continua WIP35-v136.
- A referência visual efetiva do usuário era V135; portanto mudanças V136/V137 não são consideradas aprovadas só porque passaram QA técnico.
- Real authenticated visual E2E continua não realizado/não alegado.

## Incidentes críticos observados
1. Despesas: `canceling statement due to statement timeout` em homologação real. Parser/QA estático não capturou o problema de carga.
2. Fluxo Diário: `canceling statement due to statement timeout` em homologação real, apesar de a aba ter funcionado anteriormente. Tratar como regressão sistêmica de performance.
3. Classificação de extrato: voltou a falhar. O ciclo selecionar → salvar → refletir no cache/UI → remover/atualizar fila deve ser testado de ponta a ponta.
4. Planejamento: rejeitado visualmente como relatório textual; não corresponde ao cockpit executivo pretendido.
5. Cartões: rejeitado visualmente como relatório genérico; não explora adequadamente exposição, vencimentos, parcelas, composição, histórico e drilldown.
6. Atualizações: direção percebida como melhor, porém ainda com texto excessivo, confiança/histórico pouco diretos e sugestões/opções aparecendo de forma inconsistente ao longo da fila.

## Diagnóstico e correções já aplicadas
### Classificação de extrato
- Encontrado mismatch concreto: `lts_refresh_product_read_cache_classification_fast_v1` procurava hardcoded `payload_version='lts-product-fix86-v35'`, enquanto o cache atual é `lts-product-fix86-v36`.
- Função corrigida em migration `fix_classification_fast_refresh_current_payload` para atualizar o payload atual mais recente do usuário.
- Validação pós-correção: refresh retornou `ok=true`, `mode=classification_fast_patch`, `payload_version=lts-product-fix86-v36`; cache v36 ficou sincronizado com `semantic_pending_groups=0` e `semantic_review.items=[]`.
- Latência observada do refresh rápido ainda alta: ~8.5s. Performance permanece pendente.

### Fluxo Diário
- RPC ativo da UI: `lts_browser_flow_v3`.
- `lts_browser_flow_v1`, usado por v3, forçava `calculation_context_from=2026-08-18` mesmo para consultas exclusivamente futuras como “Próximos 30 dias”.
- Medição do motor base `lts_daily_flow_full_query_v5` para 18/08 → +29 dias: ~7.1s, antes do trabalho adicional da camada v3; isso deixa a chamada vulnerável ao statement timeout.
- Comparação controlada entre cálculo desde 18/08 e cálculo apenas a partir do dia corrente para os mesmos 30 dias futuros: 30/30 dias comparados; `max_bank_delta=R$0.00`; `max_saldo_final_delta=R$0.00`.
- Migration `optimize_browser_flow_future_fast_path` aplicada: para `p_from >= current_date`, o cálculo começa no próprio `p_from`; ranges históricos continuam preservando a âncora.
- Regressão financeira após a otimização: core suite 15/15 PASS, incluindo flow documentary closes, planning parity, projection bridge e CIPÓ account parity.
- Latência-base ainda precisa ser reduzida e transformada em gate de performance; a correção acima remove recomputação sem alterar dinheiro, mas não encerra o incidente sozinha.

## Gates obrigatórios antes da próxima homologação
- Despesas: caminho autenticado real precisa carregar sem timeout e dentro de limite de latência definido.
- Fluxo Diário: “Hoje”, “Próximos 30 dias” e um período histórico representativo devem passar gate de latência e paridade financeira.
- Classificação de extrato: save/refresh/cache/UI deve passar teste integrado sem depender de versão hardcoded do payload.
- Atualizações: todo item elegível deve mostrar sugestão/opções ou estado explícito de “sem sugestão por falta de evidência”; confiança percentual só quando houver score real; histórico encontrado/não encontrado/não verificado deve ser direto.
- Planejamento e Cartões: redesign material para cockpit executivo antes de novo pedido de homologação.
- Parser/smoke/gates financeiros continuam obrigatórios e v136 permanece fallback em qualquer falha.
