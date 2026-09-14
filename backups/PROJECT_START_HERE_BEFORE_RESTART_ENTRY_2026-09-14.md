# LTS Wealth — Comece aqui

Estado vigente: 12/09/2026. Ler também LTS_WEALTH_EXECUTION_STATE.md. O estado anterior deste arquivo está preservado em backups/PROJECT_START_HERE_BEFORE_INTEGRATED_2026-09-12.md.

## O que foi feito
A conciliação do extrato Itaú já recebido foi aplicada no Supabase e conferida após a gravação. As seis movimentações faltantes e os dois vínculos de substituição de previsões foram tratados sem apagar os originais ou criar ajuste artificial. Os fechamentos históricos agora respeitam as posições documentadas por data. Não repetir o diagnóstico antigo de que o extrato falta ou a gravação continua bloqueada.

As faturas no Fluxo passaram a usar um único modelo baseado no Visa Aeternum: resumo inline, categorias LTS em ordem decrescente, situação documental, total, pendências, acesso completo e retorno ao resumo. O reconhecimento do Personnalite, a distinção de vencimento/data de caixa e a apresentação de créditos/estornos foram corrigidos. Ausência de documento para outro Visa é apresentada como ausência; não inventar detalhe ou importar outra competência por valor parecido.

A janela padrão continua com cinco dias anteriores, hoje e os próximos trinta, inclusive dias sem movimentos. Datas manuais continuam disponíveis e não são desfeitas pela troca de banco. O Fluxo V150/V151 preservado continua sendo o contrato; a V162 não reativa a cadeia cumulativa que congelava.

O produto testado é f202ec7f24f832952ba62b9d27ab9d179135280a. Os três testes automáticos de recuperação, janela e integração passaram. A exposição da homologação deve ser confirmada pelo último Pages e testes do main. Não confundir metadados de publicação com publicação concluída.

## Como retomar sem este chat
1. Ler LTS_WEALTH_EXECUTION_STATE.md.
2. Ler backups/V162_INTEGRATED_FLOW_ACCEPTANCE_2026-09-12.md e eventual checkpoint posterior.
3. Ler NEXT_HOMOLOGATION_GATE.md.
4. Ler PROJECT_MASTER_BACKLOG.md junto de PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md. O delta atualiza estados; não elimina pendências históricas.
5. Consultar LTS_WEALTH_PRODUCT_CONTRACT.md e LTS_WEALTH_DECISION_LEDGER.md para regras. Consultar a camada privada source_documents para valores, originais, decisões, antes/depois e QA real.
6. Antes de escrever, atualizar main, branch ativa e SHAs dos documentos obrigatórios. Não sobrescrever trabalho paralelo nem usar force.

## Limites que continuam explícitos
O saldo atual Bradesco confere com a imagem, mas permanece um pequeno resíduo histórico sem lançamento inventado. O débito genérico de outro cartão Bradesco e o Visa Itaú ainda precisam de vínculo documental atual seguro. Essas lacunas não podem ser mascaradas como saldo zero ou fatura detalhada.

Os testes de navegador usam dados de teste; o banco foi conferido separadamente com entradas reais de consulta. A sessão autenticada do usuário e seu iPhone físico não foram operados pelo agente. A classificação em massa ainda depende da prova real de salvar, atualizar e reler; o teste mecânico com recarga passou e o erro de mensagem após salvar foi corrigido.

O index.html público continua protegido. Promoção pública não autorizada. Dashboard fora do pacote; exige imagem completa aprovada antes de implementação. Preservar todas as confirmações anteriores sobre financiamento, Larissa, seguro, Cofrinho, RSUs, faturas e DDA sem perguntar novamente.

## Referências operacionais
Branch: recovery-v152-flow-20260910. Homologação: homologacao.html -> wip35-v162-candidate.html. Leitura: lts_browser_flow_v11. Escrita protegida: lts_browser_flow_mutate_v2. Detalhe de fatura: assinatura V2 mantida, delegando ao leitor exato V3. Contrato visual: all-cards-aeternum-summary-source-v1. Sem timers permanentes nem observadores acumulados.
