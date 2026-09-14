# LTS Wealth — Despesas: próximo pacote de execução

14/09/2026. O usuário pediu avançar para Despesas depois de responder o lote de classificação. Essa é agora a prioridade entre módulos. Não significa aceite dos relatórios existentes, certificação de 100% das classificações aplicadas ou autorização para promover o Dashboard/raiz pública.

## Situação conferida
O lote H01–H13 está respondido. A consulta direta ainda retorna sete linhas de cartão e dois grupos bancários pendentes na origem; todas essas decisões já foram recebidas. O resumo armazenado continua em quarenta linhas e onze grupos. A mudança de nome para Benjamin - Presentes permanece uma tarefa separada. Não perguntar novamente nem contar respostas recebidas como gravações concluídas.

Foram inspecionadas as definições existentes: lts_browser_expense_executive_v3 e v4 chamam lts_expense_executive_report_v12_cached, apoiado no cache lts_expense_effective_read_cache. O detalhe mensal v2 chama lts_expense_total_rows_v5. A cadeia de linhas v5 preserva alocação histórica certificada e usa v4/v3/v2/v1; v2 ainda contém uma ponte pelo leitor antigo lts_daily_flow_fix86_v12. Essas rotas distintas precisam de prova de correspondência com as fontes atuais de faturas e bancos; categorias atualizadas no detalhe da fatura não certificam automaticamente um relatório armazenado.

A consulta adicional de comparação monetária foi bloqueada pela ferramenta antes de retornar resultado. Não foi reexecutada por outra rota. Portanto não foram obtidos novos totais reais de Despesas nem corrigidos os defeitos de agregação nesta rodada. Nenhuma alteração financeira, categoria, migração ou atualização de cache foi executada aqui.

## Implementação iniciada, sem reiniciar arquitetura
Foi implementado .github/scripts/lts_expense_integrity.cjs, um verificador offline para comparar leituras normalizadas por identidade documental. Não contém rede, SQL, credenciais, regras de classificação, aproximação por comerciante/valor ou correção automática. O adaptador entre os leitores existentes e esse formato ainda precisa ser implementado e validado por uma operação permitida. Não há integração com a tela ou gate de CI nesta entrega preparatória.

O verificador exige identidade da origem e tratamento econômico previamente comprovados. Distingue respostas do usuário de aplicação; categoria antiga de atual; parcelas de datas de compra; fontes ausentes/duplicadas; totais divergentes; liquidações de cartão/adiantamentos de consumo; cobertura parcial; ausência de dado de zero; período aberto de fechado. Os testes usam dados sintéticos e não executam a consulta negada nem aplicam decisões bloqueadas.

Execução local: node .github/scripts/lts_expense_integrity.cjs --self-test. Resultado: 20 cenários PASS. Isso testa o verificador, não certifica o relatório real nem a sessão autenticada do usuário.

## Escopo de produto a preservar na tela existente
Análise de despesas deve explicar onde o dinheiro foi consumido, mantendo as categorias do Excel/LTS e as exceções aprovadas. Não ativar o mapa futuro de equivalências. Preservar Visão geral, Insights, Categorias, Contrapartes, Recorrências, Maiores gastos e Cobertura como referência recuperada; confrontar o componente atual antes de qualquer alteração visual, sem recriar uma arquitetura paralela.

A visão deve permitir períodos mensais/anuais e intervalos históricos, ranking de categorias do maior para o menor, contexto/pessoa somente onde confirmado, comparação entre períodos equivalentes e abertura de categoria até o lançamento/documento que sustenta o total. Referências de detalhe apenas por categoria ou apenas total não podem se transformar em compras inventadas. Meses abertos e base parcial precisam ser explícitos.

A reconciliação inicial é inclusiva desde 07/07/2026, preservando histórico desde 2013 e parcelas originadas antes do corte. Regime de caixa, competência da fatura e data original de compra continuam distintos; o novo pacote não pode mudar essas regras silenciosamente. Comparativos e demais filtros precisam usar a mesma definição financeira e a mesma base verificada.

## Sequência e critérios de aceite
1. Adaptar a comparação aos leitores existentes, recuperar somente fontes permitidas e verificar categorias/valores/origens em Despesas, faturas e Fluxo. Encerrar as gravações já autorizadas apenas quando houver execução permitida, sem repetir perguntas ou contornar bloqueios.
2. Corrigir a leitura de consumo e a linhagem das duplicidades conhecidas, preservando todo o caixa real. A relação do veículo já está confirmada; os adiantamentos/reembolsos não são compras adicionais. Liquidação de fatura não pode duplicar seus itens. Financiamentos e patrimônio devem manter as camadas/definições já aprovadas, sem exclusão silenciosa nem regra nova.
3. Sincronizar o resumo por meio permitido e ligar o detalhe da tela existente à mesma base. Fechar centro de custo confirmado, datas, períodos e cobertura. Demonstrar correspondência antes de gerar conclusões por categoria ou pessoa.
4. Testar mês completo, mês aberto, faixa desde 07/07, período histórico com detalhe parcial, troca de filtros e clique até origem. Depois conferir salvar/atualizar/reabrir na sessão real, sem afirmar que fixture é prova no dispositivo.
5. Só apresentar o relatório como definitivo no escopo efetivamente reconciliado. Outras fontes/cartões não recebidos e posições de patrimônio não são certificados por um questionário encerrado.

Patrimônio continua uma frente posterior com critérios próprios: posição documental dos ativos, passivos, disponibilidade, data-base e avaliação autorizada. A classificação de compras não prova valor de mercado nem quitação de dívida. Cartões mantém seu próprio fechamento/documento/datas. Nenhum desses módulos foi validado automaticamente nesta mudança de prioridade.

## Responsabilidade e limites
O usuário não precisa preencher de novo o lote no link. A execução, o teste e a atualização documental são do assistente. Perguntas novas apenas para evidência realmente nova; incertezas já aceitas como Mercado Livre não devem ser reabertas por hábito.

V162, manifest e index.html não mudaram. Não há novo link de homologação ou nova tela publicada nesta rodada. Manter a proposta de Dashboard sujeita a aprovação explícita. Este plano complementa, não apaga, o backlog, os checkpoints e as decisões anteriores. Retomar pelo RETOMAR_LTS_WEALTH.md e estado de execução atualizado.
