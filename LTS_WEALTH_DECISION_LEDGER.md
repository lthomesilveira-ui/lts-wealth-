# LTS Wealth — Ledger de decisões

Registro cumulativo de decisões humanas e mudanças de direção. Não apagar entradas antigas; uma decisão posterior deve marcar explicitamente a anterior como substituída ou rejeitada.

## 16/09/2026 — Dashboard único e pacote visual completo

Status: **AUTORIZADO PELO USUÁRIO / IMPLEMENTAÇÃO V164 EM ANDAMENTO**

- O layout de cockpit aprovado continua sendo a referência; V163 não foi aceito como execução fiel desse layout.
- `Planejamento` deixa de ser uma aba separada. Escada de liquidez, janelas negativas, recuperações e contingência passam a integrar o Dashboard único.
- A primeira tela deve responder diretamente: há dinheiro suficiente, existe saldo negativo, quando ele começa e qual é a pior falta.
- A leitura deve diferenciar o primeiro gap com vestings programados (30/12/2026) do primeiro gap ainda descoberto se o FGTS estiver disponível (30/01/2027), sem chamar isso de “cenário-base operacional”.
- Despesas, Cartões e Patrimônio devem usar a mesma linguagem visual do Dashboard, preservando leitores reconciliados, drill-downs e regras financeiras.
- A faixa de “diferença Itaú” não pode tratar um dia projetado posterior ao último extrato como divergência bancária. Aviso de conciliação só aparece diante de diferença na própria data de fechamento documental.
- O usuário autorizou implementação, testes e publicação em homologação e pediu um único link já conferido; fixture automática não substitui a validação dos dados reais.

## 10/09/2026 — rejeição da canônica v1.24

Status: **REJEITADA PELO USUÁRIO**

- O Dashboard apresentado não corresponde ao layout esperado e não pode ser usado como baseline aprovado.
- O Fluxo visível perdeu a árvore/continuidade e a distribuição de valores validada.
- As colunas de `RSUs futuras`, `Cash Awards futuros` e `Posição econômica total` criaram uma leitura de saldo incompatível com a regra informada: awards futuros só entram quando efetivamente vested/liquidados/disponíveis.
- Despesas, Receitas e Cartões não foram aceitos como entregues.
- Gates automáticos anteriores permanecem como evidência técnica histórica, não como aceite de produto.

## 10/09/2026 — estratégia de recuperação

Status: **AUTORIZADA**

- Entregar por etapas, começando pelo Fluxo Diário.
- Usar a V152 como ponto técnico recuperado e a V150 como contrato visual/funcional do Fluxo.
- Não executar novo Dashboard agora.
- Para o próximo Dashboard: apresentar primeiro uma imagem completa, validar conteúdo/layout com o usuário e somente depois implementar.
- Registrar briefing, feedbacks e decisões no repositório para continuidade entre chats.

## 10/09/2026 — candidata do Fluxo

Status: **GATE AUTOMÁTICO APROVADO / HOMOLOGAÇÃO HUMANA PENDENTE**

- Criar uma candidata separada que abre diretamente no Fluxo e oculta o Dashboard rejeitado durante esta etapa.
- Manter intactos os arquivos históricos V150–V152 e o `index.html` público.
- Adaptar apenas as leituras legadas `lts_browser_flow_v3`/`v4` para o leitor autenticado atual `lts_browser_flow_v10`.
- Não alterar writers financeiros nem classificar dados automaticamente.
- Validar continuidade histórica, árvore, classificação, ações, faturas Visa/C6 e regra de vesting em desktop e mobile antes da exposição.
- O gate determinístico `34495044417` aprovou desktop 1440×900 e mobile 390×844; isso comprova o contrato da fixture, não os dados reais nem a aprovação humana.

## 10/09/2026 — retirada da cadeia cumulativa de wrappers

Status: **DECISÃO TÉCNICA COMPROVADA PELO GATE**

- A primeira candidata tentou reaproveitar integralmente a cadeia V152→V150 e congelou antes de o Fluxo ficar pronto no teste de navegador (`34492222128`).
- A causa observável é a acumulação de `setInterval` e `MutationObserver` permanentes em diferentes wrappers históricos; manter essa execução repetiria o travamento relatado pelo usuário.
- A recuperação passa a carregar diretamente `index.html`, onde o componente validado do Fluxo permanece preservado, e injeta apenas uma ponte limitada das leituras V3/V4 para V10.
- Os arquivos históricos V150–V152 e o `index.html` continuam intactos. Dashboard, writers e schema permanecem fora desta mudança.

## Pendências de decisão/evidência

- Os ajustes exatos de fatura posteriores à V152 que não estejam demonstrados por código, screenshot ou documento permanecem `ABERTO_EVIDÊNCIA`; não devem ser reconstruídos por memória presumida.
- Homologação humana do Fluxo recuperado permanece aberta.
- Proposta visual do Dashboard permanece aberta e bloqueia sua implementação.
- Prova autenticada com dados reais e prova em iPhone físico permanecem distintas dos fixtures automáticos e não são alegadas como concluídas.

## 12/09/2026 — rentabilidade da conta Bradesco

Status: **CONFIRMADA PELO USUÁRIO / OCORRÊNCIA APLICADA E RELIDA**

O resíduo positivo mostrado para a posição Bradesco de 11/09 é rentabilidade da conta, conforme a confirmação do usuário. A natureza já existia no histórico e na regra de RENTAB.INVEST FACILCRED*. Preservar a descrição da planilha Rentabilidade Conta Corrente Bradesco e a categoria canônica Rendimentos financeiros. O aviso de diferença sem explicação para essa ocorrência está SUPERADO.

A aplicação reconhece o rendimento acumulado uma única vez na posição documentada, sem afirmar data de crédito bancário não fornecida e sem somar novamente ao saldo que já o inclui. Não transformar esta confirmação específica em tolerância geral ou classificação automática de qualquer diferença de centavos. Antes de perguntar novamente, consultar este registro e a evidência privada. Checkpoint: backups/V162_BRADESCO_YIELD_CONFIRMED_2026-09-12.md.

A sequência permanece: fechar os problemas funcionais/UX do Fluxo, incluindo troca de bancos, e depois recuperar as classificações bancárias e de cartões pela planilha/histórico validados. Esta correção não libera classificação em massa nem representa homologação humana do conjunto.

## 13/09/2026 — preservar a taxonomia do Excel e usar Restaurantes

Status: **CONFIRMADA PELO USUÁRIO / COMPRAS IDENTIFICADAS APLICADAS E RELIDAS**

O usuário confirmou que a classificação do histórico Excel desde 2013 era **Restaurantes**. Para consolidar os dois meses pendentes desde a migração, manter essa nomenclatura e as demais categorias históricas validadas. A escolha entre Restaurantes e Restaurantes e Lazer para as compras de restaurante discutidas está resolvida em favor de Restaurantes; não pedir a mesma decisão novamente.

A revisão de nomenclaturas fica para etapa posterior, separada da recuperação pendente. Não renomear retrospectivamente todo o histórico, não criar categoria concorrente e não converter genericamente lazer, intermediadores, marketplaces ou Pix em Restaurantes. Eventual mapa de equivalências futuro deve preservar a classificação original e receber aprovação antes de alterar a leitura consolidada.

A autorização atual para recuperação/classificação apoiada em evidência substitui a restrição temporária de não classificar durante o isolamento do Fluxo em 10/09, apenas dentro do escopo confirmado. Não autoriza inventar finalidade ou sobrescrever decisões específicas anteriores.

A aplicação desta rodada alcançou as quatro compras identificadas em três restaurantes na fatura atual, por registro de origem, sem regra global e sem alteração de valores. A fila e o detalhe foram conferidos depois da gravação. Checkpoint: backups/V162_RESTAURANTES_EXCEL_CONFIRMATION_2026-09-13.md. A recuperação completa dos dois meses e a liberação da classificação manual em massa continuam gates separados.

## 13/09/2026 — mapa de equivalências aprovado como etapa futura

Status: **CONCEITO APROVADO / REGISTRADO / CONTINUIDADE DA CLASSIFICAÇÃO AUTORIZADA**

O usuário concordou com o mapa de equivalências entre categorias antigas e uma futura nomenclatura analítica, preservando a categoria original, e pediu que a decisão fosse registrada. O plano está em LTS_WEALTH_CATEGORY_EQUIVALENCE_PLAN.md. A aprovação é do conceito e da sequência, não de correspondências ainda não apresentadas ou de uma renomeação imediata do histórico.

Prioridade atual: continuar classificando os dois meses pendentes, movimentos bancários e compras de cartões, com o padrão original do Excel/LTS. Não aguardar nova autorização para classificações apoiadas em evidência. Perguntar somente pelas ambiguidades restantes após recuperar o histórico. A revisão de nomes e a ativação do mapa ficam para depois; preservar originais, explicar impacto e validar as correspondências antes de usá-las na consolidação.

Nesta continuação, três novas linhas de restaurante nos ciclos de agosto e setembro foram classificadas por origem com base em evidência já disponível e na categoria Restaurantes confirmada. Não foram criadas regras globais, fundidas categorias ou alterados valores. Evidência privada e leitura posterior estão registradas no checkpoint backups/V162_MAP_APPROVAL_CLASSIFICATION_CONTINUED_2026-09-13.md. A aprovação do mapa não equivale à conclusão dos dois meses nem à liberação irrestrita da interface manual.
