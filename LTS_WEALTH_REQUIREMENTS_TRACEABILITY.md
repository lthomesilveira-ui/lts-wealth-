# LTS Wealth — Matriz de Requisitos, Decisões e Validações

Última auditoria material: 08/09/2026 18:50 BRT (America/Sao_Paulo)

Objetivo: impedir que briefing, decisões, dados, validações ou pendências se percam entre chats, versões ou trocas de arquitetura. Esta matriz complementa `PROJECT_MASTER_BACKLOG.md`; ela não substitui os checkpoints imutáveis nem a evidência financeira.

## Regra de precedência

1. decisão explícita mais recente do usuário;
2. estado atual e evidências versionadas no GitHub;
3. checkpoints imutáveis e contratos financeiros/visuais;
4. artefatos históricos originais e histórico de conversas recuperável;
5. nenhuma inferência quando a evidência não resolve o conflito.

O GitHub é a memória operacional. Uma conversa não pode, sozinha, marcar requisito como concluído ou apagar uma pendência.

## Legenda de status

- `VALIDADO_USUARIO`: aceito ou definido explicitamente pelo usuário.
- `VERDE_AUTOMATICO`: implementado e coberto por teste determinístico.
- `IMPLEMENTADO_NAO_E2E_REAL`: existe no produto, mas falta prova autenticada com dados reais.
- `ABERTO_ENGENHARIA`: executável autonomamente sem nova decisão financeira.
- `AGUARDA_EVIDENCIA`: não pode ser fechado sem documento/dado real.
- `AGUARDA_DECISAO`: depende de escolha, consentimento, gasto ou premissa do usuário.
- `HISTORICO_SUPERADO`: preservado como evidência, mas não é a arquitetura ou regra atual.

## Definição de pronto recuperada do briefing

O app só está entregue quando, simultaneamente:

- substitui o uso diário do Excel, sem redigitação dos dados já existentes;
- apresenta Fluxo Diário consistente para passado, hoje e próximos 90 dias;
- mantém cartões, recorrências, compromissos, transferências, simulações e conciliação integrados;
- entrega Dashboard executivo, Cartões abertos e funcionais e navegação por intenção;
- usa uma única aplicação canônica, com autenticação e dados reais;
- preserva história, ledger, auditoria, idempotência, backups e restauração segura;
- respeita diferença de reconciliação aceitável de `R$ 0,00`;
- separa Realizado de Projetado, envia ambiguidade para Revisão e mantém movimentos internos com efeito consolidado zero;
- passa recibo automático de Fluxo, Cartões, Dashboard, Recorrências, Compromissos, Simulações, Conciliação, performance e UX, sem regressão;
- funciona intencionalmente em desktop e mobile, sem travamento, rota presa, clipping ou overflow;
- passa E2E autenticado com dados materiais no iPhone físico antes de qualquer alegação de homologação real;
- só promove `index.html` após autorização explícita.

Estado desta definição: `IMPLEMENTADO_NAO_E2E_REAL`. A V1.19 fecha a recuperação e o pacote UX executável, mas ainda não substitui comprovadamente o Excel no uso diário porque os lifecycles autenticados e o iPhone físico não foram executados juntos.

## Contrato final do Dashboard

O Dashboard a entregar não é uma das versões antigas isoladamente. É a combinação obrigatória de três contratos:

1. **Visual** — imagem oficial original 1312×1199, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`: rail escuro, canvas claro, alta densidade, espaçamento compacto, cartões executivos e leitura imediata.
2. **Financeiro** — dados reais do LTS e cinco KPIs liquidity-first: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
3. **Produto** — visão decisória com evolução de liquidez, distribuição patrimonial, posição por banco, fluxo de caixa, principais despesas, próximos compromissos, planejamento, FGTS e atualizações pendentes.

Os valores impressos na imagem oficial são ilustrativos. Nenhum valor da referência pode ser copiado para o app sem evidência LTS.

Semântica vinculante: pontos até `as_of` podem ser apresentados como posição observada somente quando o contrato os identifica dessa forma; datas posteriores são projeções e precisam de linguagem/traço visual distinto. A evolução separa base operacional, vestings programados condicionais e FGTS documental restrito; cenários condicionais/restritos nunca viram posição atual. `Próximos Compromissos` representa obrigações documentadas — vencimento de cartão e contratos com `next_due` explícito — e nunca tarefas de revisão, classificação ou planejamento.

### Linhagem dos modelos de Dashboard

| Modelo | Papel preservado | Situação atual |
| --- | --- | --- |
| Tesouraria V69 / fix85, jul–ago/2026 | Cockpit temporal; banda de caixa de 90 dias; navegação por intenção; cartões, compromissos, cenários, patrimônio e financiamentos. | `HISTORICO_SUPERADO` como frontend, requisitos funcionais preservados. |
| Claude-era v114 / cockpit v142 | Frase `Sua vida financeira, em uma tela.`; hero D+3; FGTS D+30 separado; horizontes, planejamento, poucas ações e atalhos executivos. | Conteúdo financeiro incorporado às regras atuais; layout antigo não é o alvo final isolado. |
| v150 | Recompôs Dashboard em torno do realizável até D+3; separou caixa, D0 e vested D+3; manteve FGTS restrito; trouxe natureza × contexto em Despesas. | Integrado e preservado no contrato financeiro. |
| v151 | Acrescentou busca transacional server-side/CSV e regra documental conservadora do FGTS; acumulou feedback real de estabilidade/UX. | Funcionalidades preservadas; wrapper v151 não deve voltar. |
| Referência oficial 1312×1199, 04/09/2026 | Contrato visual obrigatório, explicitamente aprovado. | `VALIDADO_USUARIO`. |
| Canonical Dashboard Fidelity Pass 5 | Removeu o segundo dono de DOM e restaurou hierarquia/densidade com os cinco KPIs reais. | `VERDE_AUTOMATICO`; paridade pixel-level e E2E autenticado continuam abertos. |
| Canonical v1.6 Briefing Capability Recovery | Mantém Pass 5 e recupera Central de Gestão com dez capacidades históricas, sem aumentar as seis rotas primárias mobile. | `VERDE_AUTOMATICO` no gate; E2E autenticado e paridade visual do Dashboard continuam abertos. |
| Canonical v1.6 Dashboard Fidelity Pass 6 | Recupera ordem de navegação da referência, competência/as-of, `Hoje`, sinais de evidência e drill-downs reais; preserva os dez contratos de gestão. | `VERDE_AUTOMATICO` em Chromium/WebKit e exposto na homologação fixa; paridade pixel-perfect e E2E autenticado continuam abertos. |
| Canonical v1.7 Route Continuity + DoD Receipt | Preserva integralmente Pass 6, restaura rota/painel após refresh/sessão/back-forward e produz um recibo único da definição de pronto. | `VERDE_AUTOMATICO`; recibo mantém E2E autenticado, iPhone físico e promoção pública explicitamente abertos. |
| Canonical v1.8 Unified Expenses | Remove o segundo dono de Despesas e reúne histórico mensal/anual, natureza × contexto, semântica de `Não atribuído`, insights evidenciados e drill-down de mês/item. | `VERDE_AUTOMATICO` em Chromium/WebKit e exposto na homologação fixa; E2E autenticado/iPhone físico continuam abertos. |
| Canonical v1.9 V150 Flow Parity | Porta as interações validadas V150–V152 para a aplicação única atual, preservando o modelo posterior de liquidez e sem restaurar wrappers. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `6aba220…` exposto no manifesto fixo por `90aad3a…`, com E2E autenticado/iPhone físico ainda abertos. |
| Canonical v1.10 Dashboard Decision Truth | Preserva toda a linha v1.9 e torna explícitas as fronteiras observado×projetado e compromisso financeiro×tarefa operacional. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `de4362d…` exposto no manifesto fixo por `661be37…`, com E2E autenticado/iPhone físico ainda abertos. |
| Canonical v1.11 Layered Liquidity | Preserva v1.10/v1.9 e materializa a evolução separada de posição atual, base operacional, vestings programados condicionais e FGTS restrito D+30. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `8a9c675…` exposto no manifesto fixo por `04c051f…`, com E2E autenticado/iPhone físico ainda abertos. |
| Canonical v1.12 Reviewed Text Input | Preserva toda a linha v1.11 e restaura em `Atualizações` o `Lançamento por texto` revisável que existia na V150 e estava ausente da aplicação canônica renderizada. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `70c49b1…` exposto pelo manifesto `adac528…`; save/readback autenticado e iPhone físico ainda abertos. |
| Canonical v1.13 Classification-first Updates + Guided Document Intake | Preserva toda a linha v1.12 e restaura a hierarquia V147 com classificação em primeiro plano, ações secundárias recolhidas e associação documental explícita antes do upload privado. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `6d2b546…` exposto pelo manifesto `6a25aa9…`; upload/register/interpret autenticado e iPhone físico ainda abertos. |
| Canonical v1.14 Document Interpretation Review | Preserva toda a linha v1.13 e restaura a comparação V149, somente leitura, entre o vínculo informado e a evidência extraída, sem aprovar/classificar/reconciliar ou lançar fato. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `0d50699…` exposto pelo manifesto `ac5d467…`; upload/register/interpret/review autenticado e iPhone físico ainda abertos. |
| Canonical v1.15 Dashboard Density | Preserva toda a linha v1.14 e fecha o overflow desktop mensurável contra a referência aprovada 1312×1199, sem alterar semântica financeira ou composição mobile. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `a0a2675…` exposto pelo manifesto `b1998a9…`; dados reais autenticados e iPhone físico ainda abertos. |
| Canonical v1.16 V151 Planning Decision Recovery | Preserva toda a linha v1.15 e recupera a distinção decisória V151 entre início da gestão e primeiro saldo negativo, com marcador somente quando houver ponto negativo exato evidenciado. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `4028321…` exposto pelo manifesto `d9a63c9…`; dados reais autenticados e iPhone físico ainda abertos. |
| Canonical v1.17 Product Language | Preserva toda a linha v1.16 e remove build/release técnico da superfície normal, mantendo diagnóstico interno e um gate contra regressão de linguagem. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `e4cea675…` exposto pelo manifesto `06fdcbba…`; dados reais autenticados e iPhone físico ainda abertos. |
| Canonical v1.18 Flow History + Horizon | Preserva toda a linha v1.17 e fecha 01/01/2026, o tratamento visual de `Hoje` e a cobertura exata até 2029 + D+30 sem restaurar wrappers ou projetar FGTS futuro. | `VERDE_AUTOMATICO` em Chromium/WebKit; produto `692535276…` exposto pelo manifesto `65cb675…`; mutações reais e iPhone físico ainda abertos. |

### Feedback explícito recuperado dos projetos Homologação e Execução

- **24/08:** no Fluxo, `+` deve ficar à esquerda e as colunas devem manter o modelo validado; fatura Itaú aberta entra no total, enquanto o detalhe de despesa só se consolida após o fechamento. Essa decisão não deve ser reaberta sem nova evidência.
- **04–05/09:** versões visualmente próximas, porém com botões/dados falhando no iPhone, foram rejeitadas; teste visual/automático não substitui o E2E real. Também foi pedido que a evolução não regrida visualmente à V150.
- **05/09:** a direção visual V155 agradou, mas a hierarquia deveria priorizar quatro blocos de liquidez — caixa bancário, contas + curto prazo, RSUs vested e FGTS — com patrimônio abaixo, despesas consolidadas + detalhe, ações discretas/clicáveis e evolução em camadas separadas para conta, curto prazo, RSUs e FGTS.
- **07/09:** V150 é o piso funcional; melhorias V151–V153+ devem ser preservadas. Ausência de RSUs/futuras RSUs e saldo anterior negativo incorreto foram rejeitados. Fluxo deve manter história/classificação e evitar texto técnico.
- **Histórico recuperado:** v1.18 fechou com evidência a abertura de 01/01/2026, a faixa amarela rejeitada e a cobertura exata 31/12/2026–31/12/2029 + D+30. Diferença Bradesco R$0,01, evento Cofrinho 06/08, intervalo Bradesco R$0,17 e hipótese Cofrinho R$186,10 permanecem documentais; nenhum pode ser “resolvido” por inferência visual.
- **Classificação/Fix85:** precedência operacional é decisão do usuário > classificação gerada já evidenciada/aceita > vínculo de conciliação > regra textual limitada > não classificado; pesquisa pública é sugestão separada com confiança/evidência e nunca prova finalidade.
- Esses itens são requisitos/feedback do usuário. `VERDE_AUTOMATICO` indica apenas cobertura determinística; não transforma itens ainda não testados com sessão real/iPhone físico em validação do usuário.

### Hierarquia desktop obrigatória

- rail lateral escuro e canvas executivo claro;
- título, subtítulo e controle de competência/período;
- primeira linha com cinco KPIs reais;
- `Evolução da Liquidez`, `Distribuição do Patrimônio`, `Posição por Banco`;
- `Fluxo de Caixa`, `Principais Despesas`, `Próximos Compromissos`;
- `Planejamento – Visão de Caixa`, `FGTS`, `Atualizações Pendentes`;
- detalhe/drill-down acessível sem transformar o Dashboard em tela técnica.

### Hierarquia mobile obrigatória

- mesma identidade e prioridade informacional, recomposta para 390px;
- navegação primária persistente e fisicamente clicável;
- todas as seis rotas canônicas acessíveis;
- nenhuma tela desktop apenas comprimida;
- sem overflow horizontal, clipping, rota presa ou erro de sessão bruto.

## Matriz mestre

| ID | Requisito/decisão | Estado de implementação | Prova automática | Prova do usuário/dados reais | Pendência exata |
| --- | --- | --- | --- | --- | --- |
| GOV-01 | Assistente atua como gerente de produto, arquiteto, implementador, QA e release owner; usuário não programa nem redigita dados. | Processo versionado em state/handoff/backlog. | Frescor antes de write e gates permanentes. | Reiterado pelo usuário em 31/07, 01/08, 28/08 e 07/09. | Continuar autonomamente; interromper só por decisão/acesso material. |
| GOV-02 | Entregas grandes e coerentes; não microfeatures; nenhuma pendência apagada. | Backlog/checkpoints preservados. | Gate por pacote e comparação de branches. | `VALIDADO_USUARIO`. | Aplicar a todo pacote futuro. |
| ARC-01 | Uma aplicação canônica, sem cadeia de iframe/wrappers históricos. | `canonical-app.html` + módulos V157+. | Chromium + WebKit, seis rotas, no iframe. | Ainda não homologado com sessão real no iPhone. | Manter arquitetura; nunca restaurar wrapper V150–V160. |
| DATA-01 | Fonte original `Controle_Financeiro_v16.xlsm`; arquivos originais não são alterados. | Importação/read models substituem escrita na planilha. | Reconciliações e invariantes históricos. | Arquivos v0.1/v0.2 registram a decisão. | Auditar qualquer lacuna até o corte sem redigitação. |
| DATA-02 | Histórico fechado até 31/12/2025 e corte operacional: até 07/07/2026 vem da migração; 08/07 em diante vem de fatos LTS. | Contratos históricos/backend preservados. | Paridades históricas e FIX86. | Evidência em artefatos históricos. | Manter imutabilidade e rastrear exceções documentais. |
| DATA-03 | Diferença de reconciliação aceitável `R$ 0,00`. | Núcleo/backend historicamente reconciliado. | v0.2: 2 anos, diferença máxima zero, 31 itens, três bancos; gates posteriores preservam invariantes. | Sem nova divergência autorizada. | E2E da UI canônica ainda deve provar consumo coerente do dado real. |
| DOM-01 | Daily balance chain; Realizado ≠ Projetado; ambiguidade vai para Revisão. | Regras de Flow/FIX86 preservadas. | Gates de Flow, planning e classificação. | Baseline Domain Model v1.2 de 16/07. | Não converter cenário em fato. |
| DOM-02 | Ledger append-only, ingestão idempotente, bruto preservado e Advisor read-only; confirmação humana para mutação. | Contratos de writer/readback e audit tables existentes. | Cancel/edit/split 10/10; writers com rollback/idempotência. | Regra histórica explícita. | UI de undo/reversal continua desabilitada até contrato append-only explícito. |
| HIST-01 | Anomalias 01/01/2026, faixa amarela 24/08 e diferenças Bradesco/Cofrinho devem ser explicadas por evidência, sem transformar hipótese em fato. | V1.18 corrige a abertura histórica e remove a faixa rejeitada; questões Bradesco/Cofrinho continuam separadas. | Gates desktop/mobile + backend real 01/01; checkpoint v1.18. | R$0,01/R$0,17/R$186,10 exigem documento. | `FECHADO_ENGENHARIA` para 01/01/faixa; `ABERTO_DOCUMENTAL` para Bradesco/Cofrinho. |
| HIST-02 | Comparar saldos original×app em 31/12/2026 e 31/12/2029. | V1.18 inventaria os snapshots exatos dos workbooks e prova cobertura real da app até 31/12/2029 + D+30, sem alegar igualdade entre modelos diferentes. | Gate v1.18 + migração de horizonte + checkpoint com fronteira de claim. | Workbook contém camadas antigas, inclusive FGTS futuro obsoleto. | `FECHADO_ESTRUTURAL`; reconciliação numérica só se o usuário definir quais camadas de cenário comparar. |
| FLOW-01 | Fluxo passado/hoje/futuro, horizonte operacional de 90 dias, prioridade absoluta de confiabilidade. | Rota canônica, `lts_browser_flow_v8` e contrato `v150-validated-flow-plus-v157-liquidity-v1`; botão Hoje e próximos cinco dias completos restaurados. | Gates `34219446266` / `34219669569`: Chromium desktop + WebKit mobile, presets, 14 colunas consolidadas, cinco dias, expansão e troca de conta. | Uso real ainda não fechado. | E2E autenticado físico. |
| FLOW-02 | Consolidado + Itaú + Bradesco + C6, sem inferir banco ausente. | Implementado. | Gate físico de seleção das quatro visões. | Regra original e atual. | Provar com dados reais no iPhone. |
| FLOW-03 | Transferência interna e banco↔ativo têm efeito econômico consolidado zero; pagamento de fatura não duplica despesa. | V1.23 distingue `Fatura aberta` de `Fatura fechada`: a aberta afeta a projeção de caixa sem expor/consolidar compras; a fechada mantém composição conciliada e detalhe completo via `lts_browser_card_settlement_detail_v2`. | Gate percorre transferência neutra, ciclos aberto/fechado, resumo, créditos, delta caixa×detalhe, detalhe completo e ausência de compras não fechadas em Chromium/WebKit. | Regra original e comportamento V150 recuperado sem dupla contagem. | Save→refresh e fatura real autenticados ainda pendentes. |
| FLOW-04 | Projeção pode ser editada, postergada, duplicada, dividida/substituída ou cancelada sem apagar a origem. | V1.23 usa `lts_browser_flow_event_editor_v1` + `lts_browser_flow_mutate_v1`; oferece validação inline, cinco intenções explícitas, divisão 2–12 partes, Escape e restauração de foco. | Gate prova a sequência append-only `edit → postpone → duplicate → split → cancel`, payloads e `writer_called:false` na fixture; recuperação/canônico `34413082102` / `34413258158`. | Comportamento V150 recuperado; nenhum write financeiro real usado no teste. | E2E autenticado das cinco ações e readback. |
| FLOW-05 | Mobile deve manter o Flow legível sem eliminar as nove camadas de liquidez futuras. | V1.23 mantém 14 colunas no desktop e recolhe as nove camadas por dia no mobile sob `mobile-layer-disclosure-open-closed-invoice-actions-v1`, com `aria-expanded` e abertura/fechamento explícitos. | WebKit 390×844 prova cinco dias inicialmente compactos, nove valores após abrir e novo recolhimento; Chromium preserva a tabela consolidada. | Divulgação progressiva altera apresentação, não valores nem semântica financeira. | `VERDE_AUTOMATICO`; confirmar materialmente no iPhone físico. |
| DASH-01 | Dashboard visualmente alinhado à referência oficial 1312×1199. | Pass 6 restaura hierarquia/conteúdo; V1.15 fecha o overflow; V1.16 adiciona a decisão V151; V1.17 remove linguagem técnica; V1.19 fecha a revisão material desktop/mobile. | Gates V1.19 `34279813550` e `34281714299`, artefatos desktop/mobile e smokes pós-exposição verdes. | Referência `VALIDADO_USUARIO`; URL fixa V1.19 verificada no alvo exato. | `IMPLEMENTADO_NAO_E2E_REAL`: material visual automático fechado; falta dado real autenticado/iPhone. |
| DASH-02 | Cinco KPIs liquidity-first com valor real e sem falso zero. | Implementado. | Gate determinístico. | Dados reais completos no iPhone não provados. | E2E autenticado; indisponível deve continuar explícito. |
| DASH-03 | Planejamento mostra data de ação/gestão separada da primeira insuficiência. | V1.16 materializa `v151-first-negative-management-separation-v1`: callout distinto e marcador vermelho apenas para uma linha de horizonte exata com `base < 0`; sem interpolação. | Gate prova `01/12/2026` gestão, `12/01/2027` primeiro negativo, ordem temporal, ausência de falso marcador no overview e regressão desktop/mobile completa. | Regra financeira atual e racional V151 documentados. | Revalidar datas/valor no E2E autenticado e manter sem projeção futura de FGTS. |
| DASH-04 | Gráficos não podem apresentar projeção como fato; compromissos financeiros não podem ser derivados de tarefas operacionais. | V1.10 usa `as_of` + status/basis dos horizontes para série observada/projetada; compromissos vêm de fatura `next_due` + `product.commitments.commitments[].next_due`; tarefas ficam em Atualizações. | Gates `34225155424` / `34225365210` percorrem 2 gráficos, pontos/traços, fonte e contagem de compromissos, ausência de vazamento de 3 tarefas e navegação para Flow em Chromium/WebKit. | Sem alterar valores/regras financeiras e sem inferir `first_date` como próximo vencimento. | `VERDE_AUTOMATICO`; E2E autenticado real continua pendente. |
| DASH-05 | Evolução da liquidez deve separar posição atual, base operacional, RSUs programadas condicionais e FGTS restrito, com os quatro componentes atuais legíveis. | V1.11 usa `through_d3` como âncora atual e os campos backend `current_liquidity_balance`, `conditional_rsu_balance` e `restricted_total_balance`; contrato `current-base-scheduled-rsu-restricted-fgts-v1`. | Gates `34229899061` / `34230146792` validam dois gráficos, 1 ponto observado, 5 base projetados, 5 condicionais, 5 restritos, legendas, composição e bounds desktop/mobile; artefatos `10057369616` / `10057455711`. | Implementa o feedback explícito de 05/09 sem somar RSU futura ou FGTS à posição atual. | `VERDE_AUTOMATICO`; confirmar dados materiais em sessão autenticada/iPhone físico. |
| DASH-06 | O Dashboard executivo aprovado deve caber inteiro no canvas desktop 1312×1199 sem eliminar camadas ou compromissos. | V1.15 reduz apenas a altura desktop dos dois gráficos/legendas; página 1325→1199 px, Dashboard bottom 1184 px, painel principal 350→295 px e planejamento 373→297 px. | Gate falha se houver overflow vertical, painel principal >315 px ou ausência de uma das quatro legendas; recovery/canonical `34256124696` / `34256598442`. | Medida deriva diretamente do arquivo oficial 1312×1199; mobile continua scrollável por decisão responsiva, sem clipping horizontal. | `VERDE_AUTOMATICO`; preservar como baseline e validar materialmente quando houver sessão real. |
| AUTH-01 | Autenticação e sessão na mesma aplicação; erro visível e seguro. | Implementado; JWT futuro tenta espera/refresh/reset seguro e preserva a rota pretendida até o retorno ao login. | WebKit com sessão persistida futura + gates canônicos v1.7. | Erro real foi reportado em iPhone; correção ainda não retestada no aparelho. | `IMPLEMENTADO_NAO_E2E_REAL`. |
| NAV-01 | Navegação por intenção e rotas úteis próprias. | Desktop segue onze intenções da referência; mobile preserva seis rotas físicas canônicas. `Receitas` referencia o Flow comprovado. | Regressão física Pass 6 + continuidade v1.7 em Chromium/WebKit. | Modelo por intenção veio do fix85 e da referência oficial. | E2E autenticado físico continua pendente. |
| NAV-02 | Financiamentos, Planejamento, Receitas/Entradas, Recorrências, Compromissos, Simulações, Conciliação, Relatórios, Documentos e Configurações não podem desaparecer. | As dez capacidades estão visíveis na Central de Gestão dentro de `Atualizações`; desktop também recebe atalhos secundários e mobile mantém seis rotas. | Gates `34185954453` e `34186087590` certificam presença, troca de painéis, responsividade, estado de formulário e ausência de overflow. | Briefing/artefatos antigos exigem essas capacidades; ainda não homologadas com sessão real. | `IMPLEMENTADO_NAO_E2E_REAL`: provar cada leitor/ação aplicável em sessão autenticada. |
| NAV-03 | Rota/painel não pode ser perdido em refresh, restauração de sessão, back/forward, deep link ou recuperação de JWT. | `canonical-route-session-continuity-v1` + painel allowlisted em `sessionStorage`; estado financeiro não é persistido. | Gates `34190659782` / `34191017877`: refresh, deep link, rota inválida, back/forward, bfcache, painel e JWT futuro. | Sessão real no iPhone ainda não revalidada. | `VERDE_AUTOMATICO`; manter E2E físico como prova final separada. |
| EXP-01 | Despesas separa natureza de contexto/pessoa/centro de custo. | Canonical v1.8 reúne períodos, histórico mensal/anual, insights, semântica de `Não atribuído` e drill-down read-only sob um único dono. | Gates `34199824400` / `34200253901`; cache 3.860/3.860 e total R$8.623.752,53 preservados. | Ainda não homologado materialmente pelo usuário. | Reduzir `A classificar` somente por evidência; E2E autenticado/iPhone físico aberto. |
| CARD-01 | Cartões abertos e funcionais, por instituição e competência; sem duplicar fatura+compras. | Rota canônica com detalhe certificado/fallback agregado. | Gate canônico. | Uso real não fechado. | E2E autenticado; recuperar meses Mastercard/Visa/C6 apenas por documento. |
| WEALTH-01 | Patrimônio líquido derivado; ativos, passivos, RSU, FGTS, CIPÓ 396 e Volvo coerentes. | Rota canônica e drill-downs implementados. | Gate canônico + contratos backend. | Evidência material parcial. | Manter gaps RSU/CIPÓ/Volvo explícitos; não inventar valuation/taxas. |
| FGTS-01 | FGTS atual R$22.432,31 em 21/08/2026, restrito ~D+30, nunca D+3; sem projetar depósitos futuros. | Implementado no contrato atual. | Gates Planning/Dashboard. | Decisão do usuário em V151. | Manter regra conservadora em todos os gráficos/cenários. |
| UPD-01 | Atualizações é classification-first conforme V147, sem vazios; `Lançamento por texto` mantém preview/revisão e documentos/gestão ficam em ações secundárias recolhidas. | V1.19 preserva integralmente v1.14/v1.13/v1.12, classificação no foreground, hosts estáveis, linguagem segura e navegação de mesma rota sem remount. | Gates V1.19 preservam hierarquia, coexistência, fixture sem writer, safe errors e desktop/mobile. | Uso real autenticado não fechado; V147/V150 são as origens comprovadas dos requisitos. | Save→refresh autenticado e iPhone físico. |
| SEARCH-01 | Busca incremental desde 10/10/2013, inclui futuros já existentes, total e CSV Excel. | Implementado via `lts_browser_transactions_v1`. | Mastercard: 239 linhas, 01/11/2013–12/04/2028; gate UI. | Não E2E autenticado. | Provar busca/export real. |
| CLASS-01 | Precedência: decisão do usuário > classificação já aceita/gerada com evidência > vínculo de reconciliação > regra textual limitada > não classificado; pesquisa pública fica separada e intermediário não prova finalidade. | Wiring de leitura/escrita implementado sem promover pesquisa ou hipótese a fato. | Lifecycle determinístico. | Não E2E autenticado. | Save→refresh→sumir/resolver/self-heal real. |
| DOC-01 | Associação documental explícita; filename não determina conta/cartão/competência/valor; upload não lança fato. | V1.13 implementa formulário guiado por tipo, upload privado em `lts-documents`, registro `lts_browser_register_document_v2`, cleanup em falha e lifecycle existente; V1.14 preserva tudo sem auto-post. | Gates `34250450654` / `34250649137` preservam campos por tipo, resumo, limite/formato, seção recolhida, writer proibido na fixture e mobile. | Não E2E autenticado com PDF/imagem real nem Storage/register/readback. | Upload→register→lifecycle→interpretar→revisar real sem auto-post. |
| DOC-02 | Revisão de interpretação deve comparar associação informada com evidência extraída e permanecer somente leitura. | V1.14 restaura a superfície V149 sob `v149-evidence-review-readonly-canonical-v1`; `lts_browser_document_review_queue_v1` usa leitor interno owner-scoped/bounded e nenhum writer. | Gates `34250450654` / `34250649137` provam dois casos, 12+ linhas, vínculo presente/ausente, escaping, zero controles e `financial_writer_called:false`; probes ACL/unauthenticated passam. | Não foi exibido documento material de usuário em sessão autenticada. | `IMPLEMENTADO_NAO_E2E_REAL`: upload/register/interpret/review/readback autenticado, sem aprovação ou lançamento implícito. |
| LIQ-01 | Aplicar/Resgatar aceita formatos pt-BR, nunca adivinha conta/ativo, mostra duas pernas e R$0, exige confirmação. | Implementado. | Desktop/WebKit; fixture writer bloqueado. | Nenhum write financeiro real usado em QA. | Save→refresh→visível autenticado. |
| SAFE-01 | Backup versionado com schema/build/checksum SHA-256; restauração validada e pré-visualizada; bloquear backup parcial. | Superfície canônica implementada: export privado, checksum local, stage/preview backend, frase exata, segunda confirmação e apply não destrutivo; fixture bloqueia writes. | Gates `34179625830` / `34179823179`; RPCs `lts_browser_backup_status_v1`, `lts_browser_backup_export_v1`, `lts_browser_restore_stage_v1`, `lts_browser_restore_apply_v1`. | Não homologado com sessão/dados reais na app canônica. | `IMPLEMENTADO_NAO_E2E_REAL`: export→checksum→stage→preview→apply autenticado e verificação de auditoria. |
| QA-01 | QA automática antes do usuário; zero regressão; distinguir teste automático de validação real. | Gates permanentes geram `lts-canonical-definition-of-done-receipt-v1` em desktop Chromium e mobile WebKit, incluindo V1.23 e toda a linha V1.22→V1.9. | V1.23 recovery/candidate `34413082102` / `34413082087`; canonical gate/candidate `34413258158` / `34413258173`; main/Pages `34413472119` / `34413471764`; pós-exposição smokes `34413672709` / `34413684107` / `34413697593` e Pages `34413696615`; artifacts `10128027518` e `10128113898`. | Usuário não deve ser QA botão a botão; iPhone físico autenticado segue não alegado. | `IMPLEMENTADO_PARCIAL`: recibo único existe e passa, mas linhas autenticadas/reais/físicas permanecem OPEN. |
| QA-02 | N7/N9: investimento pode ser `nao_aplicavel` quando escopo oficial restrito não compara com LIQ multi-instituição; N8 preservado. | Contrato histórico registrado. | Build 36: meta 232 aprovados, 0 reprovados, 2 N/A, total 234, três execuções idênticas. | Autorizado em 06/08. | Garantir que auditorias futuras não convertam N/A em aprovado. |
| UX-01 | Mobile 390px/768px/desktop, sem overflow, travamento, observador recursivo ou UI escondida. | V1.19 adiciona legibilidade/touch, foco, reduced motion, estados ARIA e modal por teclado sobre a continuidade de rota/painel existente. | Chromium/WebKit sem churn/clipping; Dashboard desktop 1312×1199 e mobile 390×844; contrato `safe-errors-accessible-controls-readable-mobile-v1`. | iPhone real revelou falha de sessão fora do gate anterior. | `VERDE_AUTOMATICO`; revalidar apenas o E2E físico final. |
| OF-01 | Open Finance provider-neutral, staging/reconciliação antes de efeito financeiro, sem segredo no cliente. | Arquitetura QA 14/14. | Contratos/ACL/backend. | Nenhum consentimento/fornecedor autorizado. | Pesquisa de preço/SLA/cobertura; decisão e consentimento são `AGUARDA_DECISAO`. |
| SEC-01 | Superfície Supabase deve aplicar menor privilégio, RLS e ownership guard sem quebrar RPCs autenticadas. | Migração `20260908045049` aplicada: RLS deny-by-default em 13/13 tabelas, 12 helpers de `user_id` arbitrário internos, Flow v7-v10 authenticated-only, defaults de cliente fechados e `service_role` preservado. | Pós-condições 13/13, 12/12, 4/4, zero SECURITY DEFINER anônimo e zero autenticado sem guard direto; regressão autenticada Flow v8/Dashboard/produto em rollback; Advisor revisto. | No-policy INFO é intencional nas tabelas internas; 65 avisos authenticated SECURITY DEFINER correspondem a RPCs de navegador guardadas. Proteção contra senhas vazadas segue desativada. | `IMPLEMENTADO_REGREDIDO`: manter o gate; revisar/ativar leaked-password protection em janela controlada de Auth. |
| REL-01 | Homologação fixa preservada; root público separado e protegido. | Manifesto exposto em `d804eb0b5e972d2e86f8abc57d375e4de3e82219` aponta ao produto V1.23 `7f6bac39ec0705e21a498b416762276ea3b8dbea`; `index.html` intacto. | Gates pré/pós-exposição e Pages verdes; URL fixa resolveu o alvo exato e assets `flow23` / `ux23`; browser gate certifica zero iframe. | Homologação autorizada; promoção do root público não foi necessária e permanece separada. | Manter `not_promoted` até decisão explícita específica sobre o root. |

## V150–V160 — preservação explícita e ponto de regressão

### V150

- candidato verde `a67ba2d9c8fb770a463397349c67e654fe2e781f`;
- Dashboard centrado no realizável até D+3, separando caixa bancário, D0 e vested D+3;
- FGTS somente como contingência D+30;
- Despesas com natureza × contexto e estados de revisão explícitos;
- atalho de Atualizações para `Entradas` apenas como preview, sem writer novo;
- gates herdados V146–V149 e recomposição desktop/mobile verdes;
- foi integrada/exposta, mas nunca provou E2E autenticado físico.

### V151

- feedback material: busca por Flow amplo era lenta/inaceitável;
- resposta preservada: `lts_browser_transactions_v1`, type-as-you-go, total e CSV;
- evidência `Mastercard`: 239 resultados, 01/11/2013–12/04/2028;
- documento CAIXA atualizou FGTS para R$22.432,31 em 21/08/2026;
- decisão conservadora: não estimar novos depósitos/acréscimos de FGTS;
- gates herdados passaram, mas o smoke específico V151 teve falhas intermediárias até correções de ownership/observer;
- o wrapper V151 é histórico; suas capacidades aprovadas pertencem à aplicação canônica.

### Auditoria cronológica V152–V160

| Versão | Evidência de release | Resultado relevante para o produto atual |
| --- | --- | --- |
| V152 | candidato `16319fe`, exposição `598d53a` | Herdou o Flow rico de V150/V151; não é a origem da perda. |
| V153 | candidato `8527de9`, exposição/follow-up `a2eb869` | Introduziu shell nativo mais simples e reduziu o Flow visível às cinco colunas básicas; este é o ponto material da regressão. |
| V154 | exposição visual `30c92d1` | Consolidou direção visual; não restaurou fatura inline/divisão/rótulos do Flow. |
| V155 | recuperação funcional `5a8f43c` | Corrigiu falsos zeros e navegação de dados reais; Flow rico continuou incompleto. |
| V156 | liquidez/performance `f3e0fde` | Reforçou liquidez e desempenho, mas não recuperou todas as interações V150. |
| V157 | iOS/WebKit `cb0b442` | Cobriu classe de compatibilidade móvel; não equivaleu à homologação física autenticada. |
| V158 | native core `aa5495f` | Avançou arquitetura nativa/fallback honesto; ainda sem a paridade completa do Flow. |
| V159 | protótipo real-core `70619ad` | Recuperou apresentação, mas a prova material de KPI no iPhone continuou insuficiente. |
| V160 | real-data bridge `cbc4bc9` | Melhorou readiness por dado material e fallback; a paridade V150 do Flow permaneceu ausente. |
| Canônica v1.9 | contrato `v150-validated-flow-plus-v157-liquidity-v1` | Porta apenas o comportamento validado para a aplicação única atual e preserva `lts_browser_flow_v8`, quatro contas e 14 camadas; não reintroduz wrappers. |
| Canônica v1.10 | contrato `reference-fact-projection-commitments-v2` | Mantém a paridade v1.9 e fecha a separação projeção×fato e compromisso×tarefa. |
| Canônica v1.11 | contrato `reference-layered-liquidity-commitments-v3` | Mantém v1.10/v1.9 e fecha a separação visual/semântica entre base operacional, vestings condicionais e FGTS restrito. |
| Canônica v1.12 | contrato `review-before-explicit-apply-v1` | Mantém toda a linha v1.11 e recupera o `Lançamento por texto` V150 como preview editável, confirmação explícita e writer idempotente; fixture nunca grava. |
| Canônica v1.13 | contrato `classification-first-guided-document-intake-v1` | Mantém toda a linha v1.12, restaura a prioridade V147 e exige associação documental explícita antes do upload privado; upload nunca lança fato. |
| Canônica v1.14 | contrato `v149-evidence-review-readonly-canonical-v1` | Mantém toda a linha v1.13 e recupera a revisão V149 de vínculo versus evidência como leitura estrita, sem controle ou writer financeiro. |
| Canônica v1.15 | contrato `approved-1312x1199-single-screen-v1` | Mantém toda a linha v1.14 e fecha a densidade vertical do Dashboard aprovado no desktop, preservando as quatro camadas e o mobile scrollável. |
| Canônica v1.16 | contrato `v151-first-negative-management-separation-v1` | Mantém toda a linha v1.15 e recupera a distinção V151 entre início da gestão e primeiro negativo; marcador visual só existe para ponto negativo exato, sem aproximação. |
| Canônica v1.17 | contrato `user-facing-product-language-v1` | Mantém toda a linha v1.16 e elimina rótulos técnicos de build/release da superfície normal; o gate impede regressão sem retirar diagnóstico interno. |
| Canônica v1.18 | contratos `historical-opening-from-close-and-net-v1`, `today-marker-without-row-band-v1`, `future-through-2029-plus-d30-v1` | Mantém toda a linha v1.17, corrige a abertura histórica, remove o tratamento amarelo rejeitado e prova horizonte exato até 2029 + D+30. |
| Canônica v1.19 | contrato `safe-errors-accessible-controls-readable-mobile-v1` | Mantém toda a linha v1.18 e fecha o pacote UX executável: erro seguro, acessibilidade de estado/teclado, um único Hoje e legibilidade mobile. |
| Canônica v1.20 | contrato `projection-edit-postpone-duplicate-split-cancel-v1` | Restaura a geometria histórica e o conjunto de ações projetadas do Flow V150/V151+ sem reabrir fatos certificados. |
| Canônica v1.21 | contrato `evidence-backed-executive-report-v1` | Reconstrói Relatórios como superfície executiva baseada nos leitores certificados, mantendo export e backup separados. |
| Canônica v1.22 | contrato `executive-cockpit-readable-density-v1` | Refina a leitura do Dashboard aprovado sem alterar valores, camadas ou a distinção gestão×primeiro negativo. |
| Canônica v1.23 | contrato `mobile-layer-disclosure-open-closed-invoice-actions-v1` | Fecha o uso diário do Flow em desktop/mobile: nove camadas progressivas, faturas abertas/fechadas verdadeiras e ciclo completo append-only de projeções. |

## Pendências ordenadas sem depender do chat

### P0 executável agora

1. preservar V1.23 `7f6bac39…` / exposição `d804eb0b…` como baseline e manter toda a linha V1.22→V1.9 regression-protected;
2. manter fechados 01/01/2026, faixa 24/08, cobertura 31/12/2026–31/12/2029 e o pacote UX; tratar Bradesco/Cofrinho apenas com nova evidência documental;
3. manter o baseline Supabase regression-protected e revisar leaked-password protection em uma janela controlada de Auth.

### P0 que exige sessão/evidência real no gate final

1. E2E autenticado físico no iPhone;
2. liquidez save→refresh→visível;
3. classificação save→refresh→resolvido;
4. busca/CSV autenticada;
5. PDF/imagem interpret→review;
6. backup/restore canônico com estado real.

### Bloqueado legitimamente por evidência ou decisão

- Mastercard/Visa/C6 documental incompleto;
- liquidação histórica de RSU ainda não itemizada;
- CIPÓ R$303,60, fórmula de condomínio e gaps raw/dedup;
- versão/km exatos do Volvo;
- fornecedor, gasto e consentimento Open Finance;
- promoção pública de `index.html`.

## Fontes auditadas

- histórico de decisões recuperado de 16/07, 31/07, 01/08, 06/08, 28/08 e 02–07/09/2026;
- artefatos persistentes: `LTS Wealth Tesouraria V69.html`, `LTS Wealth Estado Final.json`, `LTS Wealth fix85 CANDIDATO.html`, `LTS_Wealth_Alpha.xlsx`, `LTS_Wealth_Fase2.xlsx`, `LTS_Wealth_v0.1_Reconciliado.xlsx`, `LTS_Wealth_v0.2_Reconciliacao_Financeira.xlsx`, `LTS_Wealth_v0.3_Base_Transacional.xlsx` e `CLAUDE.md`;
- 760 commits locais de história Git, com publicação no GitHub desde 23/08/2026;
- `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `CANONICAL_DELIVERY_MASTER_PLAN.md`, `LTS_WEALTH_VISUAL_CONTRACT.md`, `HISTORICAL_RECOVERY_LOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` e checkpoints V142–V160/canônicos;
- referência visual original anexada e proxy versionado no repositório.

## Limite conhecido da auditoria

O ambiente não fornece exportação sequencial integral de todas as mensagens pelos títulos dos dois projetos. A recuperação de conversas é indexada e parcial. Por isso, esta matriz cruza o que foi recuperável com os artefatos e o GitHub e marca lacunas; ela nunca presume que ausência de busca significa decisão inexistente. Novos fatos recuperados devem ser acrescentados aqui sem apagar os anteriores.
