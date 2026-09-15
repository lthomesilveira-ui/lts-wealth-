# LTS Wealth — Briefing de continuidade para o pacote visual

Preparado em 14/09/2026 a pedido do usuário, que perguntou se vale aproveitar o Work para recuperar a tela inicial executiva e chegar aos dashboards/reports previamente desenhados. Este documento prepara uma delegação opcional; NÃO registra que o Work já foi iniciado, que o usuário aprovou um novo desenho ou que a implementação visual começou. Não altera código ativo, dados, publicação ou critérios financeiros.

## Mandato e resultado esperado

Continuar o mesmo LTS Wealth. Não criar um novo produto, um Site paralelo, outro banco ou outra arquitetura. A próxima frente visual é recuperar a tela inicial com resumo executivo e alinhar Despesas, Cartões e os demais reports à linguagem visual documentada. O usuário pretende conferir o publicado com atenção no notebook; sua homologação material ainda não ocorreu. A preparação visual pode avançar sem mudar a versão que ele vai conferir.

A recomendação é usar o Work em um pacote delimitado de recuperação das referências, auditoria da interface e proposta visual completa, não migrar todo o projeto nem dar a dois executores controle simultâneo das mesmas telas. A vantagem operacional esperada deve ser demonstrada pelo primeiro entregável. A disponibilidade de créditos não prova fidelidade visual, continuidade automática ou maior qualidade. A mesma tarefa pode continuar no Chat caso o Work não tenha os acessos necessários.

## Primeira ação: recuperar o estado real

Repositório: lthomesilveira-ui/lts-wealth-.
Link fixo de homologação: https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html
Raiz pública protegida: https://lthomesilveira-ui.github.io/lts-wealth-/
Branch operacional conhecida: recovery-v152-flow-20260910. Confirmar se ainda é a ativa.

Ler RETOMAR_LTS_WEALTH.md, LTS_WEALTH_EXECUTION_STATE.md, homologacao-current.json e o checkpoint/release mais recente indicado pelo estado. Ler também PROJECT_MASTER_BACKLOG.md e seus deltas, NEXT_HOMOLOGATION_GATE.md, LTS_WEALTH_CONTINUITY_HANDOFF.md, CANONICAL_DELIVERY_MASTER_PLAN.md, LTS_WEALTH_PRODUCT_CONTRACT.md, LTS_WEALTH_VISUAL_CONTRACT.md e LTS_WEALTH_DECISION_LEDGER.md com seus suplementos. LTS_WEALTH_DESPESAS_EXECUTION_PLAN.md preserva os critérios de Despesas.

Confrontar documentos antigos com o estado mais recente. Alguns arquivos-mestres têm marcações de versões rejeitadas ou problemas que foram posteriormente resolvidos. Não recuperar contagens antigas nem chamar código rejeitado de baseline aprovado. Antes de qualquer write, atualizar main, branch ativa e documentos obrigatórios; inspecionar divergências sem force.

## Base verificada ao preparar este briefing

main e recovery-v152-flow-20260910 estavam iguais em 3cfb9347d0b4aa46862b1d95d00ba03637ee72ad. O produto ativo publicado é 39e47fc60c40fa8f3796fab4f73f05dee5a89419, V162. Referência de entrega: backups/V162_DESPESAS_PUBLISHED_READY_FOR_REVIEW_2026-09-14.md. Revalidar, não fixar esse commit como destino de rollback.

Consulta somente de leitura às 00:56 UTC de 15/09, ainda 14/09 em São Paulo, retornou ZERO pendências de cartão e banco tanto nas filas diretas quanto nos resumos armazenados. As sete classificações de cartão, os dois reembolsos do plano de saúde e os nove nomes Benjamin - Presentes já foram aplicados. Não perguntar novamente nem repetir os bloqueios anteriores como status atual.

Auditorias privadas: answered_classifications_native_closeout_20260914_v1 e expense_current_sources_alignment_20260914_v1. Os leitores corrigidos reconciliaram dezenove saldos de fechamento documentados do Itaú e oito ciclos de fatura. As três representações duplicadas do histórico e o adiantamento do Volvo como consumo extra foram corrigidos na leitura, preservando registros e caixa. O cache de Despesas corresponde às fontes; os totais executivos e mensais foram comparados. Informações brutas não foram apagadas.

A base bancária mais recente está documentada até 11/09/2026. Datas posteriores são projeções ou informação ainda não recebida, não consulta bancária ao vivo. A fatura aberta de setembro permanece provisória. Zero pendências no lote revisado não certifica todos os documentos históricos, movimentos futuros, outros cartões ainda sem documento ou todas as posições patrimoniais. A homologação da sessão real do usuário e a validação independente de Patrimônio continuam abertas.

## Recuperar o visual antes de redesenhar

LTS_WEALTH_VISUAL_CONTRACT.md é o contrato. Ele identifica:

- Miniatura no repositório: design/LTS_WEALTH_DASHBOARD_REFERENCE_OFFICIAL_2026-09-04.jpeg, 180 x 164, SHA-256 914019a3b94c6d8f4d63fb701c6c18be5e07d4c46c1c29f776cfe36523e7e44a.
- Original oficial: 1312 x 1199, SHA-256 0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b.

Lacuna verificada nesta preparação: foi localizado o contrato e o arquivo reduzido no diretório design. O binário original em alta resolução NÃO foi recuperado nas buscas realizadas. Pesquisas direcionadas na Biblioteca e no Drive não o localizaram, e a consulta específica às auditorias privadas de referência não retornou registro. Isso não prova que o original deixou de existir. Recuperar fontes/artefatos já citados no histórico antes de pedir reenvio. Não confundir imagens do LTS Health com a referência do LTS Wealth. Não declarar comparação fiel ao original a partir de uma miniatura, de memória ou de um novo desenho gerado.

Se a referência original não puder ser recuperada, registrar precisamente o arquivo ausente e os caminhos pesquisados. Continuar o inventário de requisitos e a auditoria de leitura sem alegar fidelidade que não foi demonstrada. Não pedir ao usuário para recontar briefing, categorias e decisões.

O contrato visual determina navegação lateral escura no desktop, área executiva clara, cinco indicadores na primeira faixa, controles compactos de período/data-base, composição de painéis com gráficos, posição bancária, compromissos e ações. Preservar hierarquia, proporções e legibilidade; não reduzir fontes apenas para caber. No celular, manter identidade/hierarquia com navegação funcional e sem rolagem horizontal da página. Recuperar os nomes e significados específicos dos indicadores nas referências, em vez de inventá-los.

A tela inicial foi ocultada durante a recuperação para não exibir o Dashboard rejeitado. Restaurar seu papel de resumo não significa simplesmente reativar a implementação rejeitada de 10/09. O processo ainda exige uma imagem completa da proposta e aprovação explícita antes de implementar um novo Dashboard.

## Primeiro pacote no Work: auditoria e proposta, sem publicação

1. Demonstrar acesso ao estado do repositório e às referências efetivamente recuperadas. Ler o app publicado e, quando houver sessão autorizada disponível, navegar pelas rotas existentes; diferenciar tela autenticada real de fixture. Não exportar dados privados para protótipo público. Não criar credenciais nem contornar autenticação.
2. Inventariar o que a tela inicial e os reports deveriam apresentar, o que o produto atual já apresenta e o que diverge da referência. Separar falta de dado, falta de navegação e diferença visual. Mapear cada indicador ao leitor/campo existente; não recalcular dinheiro no frontend para imitar uma imagem.
3. Apresentar uma proposta completa de tela inicial para notebook e celular, com hierarquia do resumo, caixa por banco e disponibilidade, evolução/projeção, compromissos, despesas e acesso às análises conforme os contratos recuperados. Saldos presentes, projeções e patrimônio/ativos restritos permanecem distintos. Não inventar posição patrimonial atual para preencher um cartão bonito.
4. Especificar como a mesma linguagem será aplicada aos reports de Despesas e Cartões existentes e posteriormente a Patrimônio, mantendo filtros, ranking decrescente, evolução e abertura até o nível documental disponível. Não tratar uma composição histórica por categoria como se contivesse compras individuais.
5. Salvar a proposta e sua origem fora do chat, com status proposto/aprovado claramente separado. Pedir somente aprovação de produto/visual ou acesso genuinamente ausente. Neste primeiro pacote, não modificar frontend ativo, manifest, SQL, categorias, caches ou raiz pública.

## Depois da aprovação visual

Implementação em branch própria a partir do main atualizado. Um único executor deve controlar o pacote e sua integração; não editar as mesmas telas em paralelo neste chat e no Work. Abertura de PR/diff, testes e revisão precedem merge. Não usar force, não restaurar a cadeia de wrappers antigos e não substituir a arquitetura para facilitar um protótipo.

O componente ativo de Despesas é o ex135 executivo/mensal com lts-expense-screen-alignment.js; o index tem definições antigas sobrepostas. Não editar a primeira ocorrência e presumir que ela é a rota final. Preservar a base e os leitores atuais; visual não autoriza nova classificação, novos efeitos de caixa ou novos critérios de consumo.

Testar a página realmente integrada em notebook e celular, inspecionar screenshots lado a lado com a referência, verificar navegação Dashboard/Fluxo/Despesas/Cartões, cliques de categorias, períodos, ausência de dados, fonte/data-base e fatura aberta. Manter os testes existentes de Fluxo/faturas e a prova de paridade dos dados. CI verde e screenshot de fixture não equivalem a homologação na sessão do usuário. Só chamar de publicado após confirmar manifest e deploy correspondentes e inspecionar o produto entregue; só chamar de aprovado após resposta humana.

## Preservações obrigatórias

Histórico desde 2013 e revisão inclusiva desde 07/07/2026; categorias originais e exceções aprovadas; mapa futuro de equivalências ainda não ativado. Fluxo V150/V151 como contrato funcional, janela de cinco dias anteriores + hoje + trinta futuros; ao trocar banco, fechar dias/faturas mantendo o período escolhido. Todas as faturas seguem lista única de categorias do maior para o menor.

Caixa, consumo e patrimônio não são o mesmo total. Pagamento de fatura não duplica compras; adiantamento confirmado não duplica consumo; transferência própria preserva direção nas contas. Cofrinho separado e datado; awards futuros não são disponibilidade atual; FGTS restrito não é dinheiro de livre uso. Não mudar a política financeira para resolver design.

Continuam independentes: documentos/identidades de outros cartões, movimentos após extratos, atribuição histórica de alguns pagamentos, navegação documental ausente, persistência manual de novos lançamentos na sessão real, patrimônio com ativos/passivos/disponibilidade/data-base, e aceite do produto completo. Não declarar tudo encerrado porque o H questionário terminou.

## Continuidade e limites

A memória operacional é o GitHub com referências às auditorias/recibos privados no Supabase/Drive/Gmail; não um suposto acesso integral aos outros chats. Conservar before-images/checkpoints e atualizar estado/lista-mestra ao terminar cada pacote. Não inserir dados bancários, recibos, endereços ou credenciais no repositório público.

Este briefing não iniciou nenhuma tarefa automática nem migrou o projeto. O usuário pode copiar a mensagem de delegação e iniciar Work para o pacote acima, ou permanecer no chat atual. Não exigir repetir contexto. Informar limitações reais de acesso/execução sem transformar achados em entregas inexistentes. Updates: Concluído / Em execução / Próximos passos.

## Referências oficiais consultadas para a recomendação da ferramenta

https://help.openai.com/en/articles/20001275 — distingue Chat, Work e Codex; Work é voltado a entregas de várias etapas e reports, Codex a desenvolvimento de software; acessos dependem da experiência e permissões.
https://openai.com/index/chatgpt-for-your-most-ambitious-work/ — descreve execução multietapas do Work através de apps/arquivos.
https://help.openai.com/en/articles/11369540 — Work/Codex compartilham cota onde disponíveis, com consumo variável conforme tarefa. A disponibilidade da conta é informada pelo usuário, não foi consultada por este executor.
