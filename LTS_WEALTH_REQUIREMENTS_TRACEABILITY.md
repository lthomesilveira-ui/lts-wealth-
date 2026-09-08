# LTS Wealth — Matriz de Requisitos, Decisões e Validações

Última auditoria material: 07/09/2026 (America/Sao_Paulo)

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

Estado desta definição: `ABERTO_ENGENHARIA`. A linha canônica atende parte relevante, mas ainda não substitui comprovadamente o Excel no uso diário porque os E2Es autenticados e algumas superfícies históricas não estão fechados juntos.

## Contrato final do Dashboard

O Dashboard a entregar não é uma das versões antigas isoladamente. É a combinação obrigatória de três contratos:

1. **Visual** — imagem oficial original 1312×1199, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`: rail escuro, canvas claro, alta densidade, espaçamento compacto, cartões executivos e leitura imediata.
2. **Financeiro** — dados reais do LTS e cinco KPIs liquidity-first: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
3. **Produto** — visão decisória com evolução de liquidez, distribuição patrimonial, posição por banco, fluxo de caixa, principais despesas, próximos compromissos, planejamento, FGTS e atualizações pendentes.

Os valores impressos na imagem oficial são ilustrativos. Nenhum valor da referência pode ser copiado para o app sem evidência LTS.

### Linhagem dos modelos de Dashboard

| Modelo | Papel preservado | Situação atual |
| --- | --- | --- |
| Tesouraria V69 / fix85, jul–ago/2026 | Cockpit temporal; banda de caixa de 90 dias; navegação por intenção; cartões, compromissos, cenários, patrimônio e financiamentos. | `HISTORICO_SUPERADO` como frontend, requisitos funcionais preservados. |
| Claude-era v114 / cockpit v142 | Frase `Sua vida financeira, em uma tela.`; hero D+3; FGTS D+30 separado; horizontes, planejamento, poucas ações e atalhos executivos. | Conteúdo financeiro incorporado às regras atuais; layout antigo não é o alvo final isolado. |
| v150 | Recompôs Dashboard em torno do realizável até D+3; separou caixa, D0 e vested D+3; manteve FGTS restrito; trouxe natureza × contexto em Despesas. | Integrado e preservado no contrato financeiro. |
| v151 | Acrescentou busca transacional server-side/CSV e regra documental conservadora do FGTS; acumulou feedback real de estabilidade/UX. | Funcionalidades preservadas; wrapper v151 não deve voltar. |
| Referência oficial 1312×1199, 04/09/2026 | Contrato visual obrigatório, explicitamente aprovado. | `VALIDADO_USUARIO`. |
| Canonical Dashboard Fidelity Pass 5 | Removeu o segundo dono de DOM e restaurou hierarquia/densidade com os cinco KPIs reais. | `VERDE_AUTOMATICO`; paridade pixel-level e E2E autenticado continuam abertos. |

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
| FLOW-01 | Fluxo passado/hoje/futuro, horizonte operacional de 90 dias, prioridade absoluta de confiabilidade. | Rota canônica e `lts_browser_flow_v8`. | Desktop/mobile; presets, colunas, expansão e troca de conta. | Uso real ainda não fechado. | E2E autenticado físico e verificação de refresh/session. |
| FLOW-02 | Consolidado + Itaú + Bradesco + C6, sem inferir banco ausente. | Implementado. | Gate físico de seleção das quatro visões. | Regra original e atual. | Provar com dados reais no iPhone. |
| FLOW-03 | Transferência interna e banco↔ativo têm efeito econômico consolidado zero; fatura não duplica despesa. | Implementado nos leitores/movimentos. | Preview de duas pernas e invariantes verdes. | Regra original. | Save→refresh autenticado ainda pendente. |
| DASH-01 | Dashboard visualmente alinhado à referência oficial 1312×1199. | Pass 5 restaura o dono e a hierarquia; não é pixel-perfect. | Hierarquia e geometria em Chromium/WebKit. | Referência `VALIDADO_USUARIO`; candidato atual não homologado. | `ABERTO_ENGENHARIA`: paridade visual, controles, gráficos, densidade e drill-down. |
| DASH-02 | Cinco KPIs liquidity-first com valor real e sem falso zero. | Implementado. | Gate determinístico. | Dados reais completos no iPhone não provados. | E2E autenticado; indisponível deve continuar explícito. |
| DASH-03 | Planejamento mostra data de ação/gestão separada da primeira insuficiência. | Implementado no read model/UI. | Gate de alias/Planning. | Regra financeira atual documentada. | Revalidar no E2E e manter sem projeção futura de FGTS. |
| AUTH-01 | Autenticação e sessão na mesma aplicação; erro visível e seguro. | Implementado; JWT futuro agora tenta espera, refresh único e reset seguro. | WebKit com sessão persistida futura + gates canônicos. | Erro real foi reportado em iPhone; correção ainda não retestada no aparelho. | `IMPLEMENTADO_NAO_E2E_REAL`. |
| NAV-01 | Navegação por intenção e rotas úteis próprias. | Seis rotas canônicas: Dashboard, Fluxo, Despesas, Patrimônio, Cartões, Atualizações. | 140 cliques históricos + regressão física atual. | Modelo por intenção veio do fix85; seis rotas são contrato atual. | Auditar descobribilidade das capacidades secundárias abaixo. |
| NAV-02 | Financiamentos, Planejamento, Receitas/Entradas, Recorrências, Compromissos, Simulações, Conciliação, Relatórios, Documentos e Configurações não podem desaparecer. | Parte está incorporada em Dashboard/Patrimônio/Atualizações/read models; não há prova atual de cobertura navegável integral. | Cobertura histórica existe; gate canônico não certifica toda a lista. | Briefing/artefatos antigos exigem essas capacidades. | `ABERTO_ENGENHARIA`: inventário de cada capacidade e rota/atalho final, sem inflar navegação. |
| EXP-01 | Despesas separa natureza de contexto/pessoa/centro de custo. | Implementado com períodos e drill-down read-only. | Gate canônico; cache 3.860/3.860 e total R$8.623.752,53. | Não homologado materialmente. | Melhorar densidade/insights e reduzir `A classificar` só por evidência. |
| CARD-01 | Cartões abertos e funcionais, por instituição e competência; sem duplicar fatura+compras. | Rota canônica com detalhe certificado/fallback agregado. | Gate canônico. | Uso real não fechado. | E2E autenticado; recuperar meses Mastercard/Visa/C6 apenas por documento. |
| WEALTH-01 | Patrimônio líquido derivado; ativos, passivos, RSU, FGTS, CIPÓ 396 e Volvo coerentes. | Rota canônica e drill-downs implementados. | Gate canônico + contratos backend. | Evidência material parcial. | Manter gaps RSU/CIPÓ/Volvo explícitos; não inventar valuation/taxas. |
| FGTS-01 | FGTS atual R$22.432,31 em 21/08/2026, restrito ~D+30, nunca D+3; sem projetar depósitos futuros. | Implementado no contrato atual. | Gates Planning/Dashboard. | Decisão do usuário em V151. | Manter regra conservadora em todos os gráficos/cenários. |
| UPD-01 | Atualizações é action center compacto, sem vazios, com motivo claro e `Lançamento por texto` em preview. | Implementado. | Gate canônico. | Uso real não fechado. | Densidade e ciclo real de writes/documentos. |
| SEARCH-01 | Busca incremental desde 10/10/2013, inclui futuros já existentes, total e CSV Excel. | Implementado via `lts_browser_transactions_v1`. | Mastercard: 239 linhas, 01/11/2013–12/04/2028; gate UI. | Não E2E autenticado. | Provar busca/export real. |
| CLASS-01 | Hierarquia: usuário > histórico exato/consistente > pesquisa pública > revisão manual; intermediário não prova finalidade. | Wiring de leitura/escrita implementado. | Lifecycle determinístico. | Não E2E autenticado. | Save→refresh→sumir/resolver/self-heal real. |
| DOC-01 | Associação documental explícita; filename não determina conta/cartão/competência/valor; upload não lança fato. | Leitura/lifecycle e UI implementados. | Gate v147/v149 + canônico. | Não E2E autenticado com PDF/imagem. | Interpretar→revisar real sem auto-post. |
| LIQ-01 | Aplicar/Resgatar aceita formatos pt-BR, nunca adivinha conta/ativo, mostra duas pernas e R$0, exige confirmação. | Implementado. | Desktop/WebKit; fixture writer bloqueado. | Nenhum write financeiro real usado em QA. | Save→refresh→visível autenticado. |
| SAFE-01 | Backup versionado com schema/build/checksum SHA-256; restauração validada e pré-visualizada; bloquear backup parcial. | Evidência forte nas versões históricas; paridade canônica não fechada. | V69/fix85 e baseline 48 chaves/checksum. | Não homologado na app canônica. | `ABERTO_ENGENHARIA`: regressão backup/restore/traceabilidade do app atual. |
| QA-01 | QA automática antes do usuário; zero regressão; distinguir teste automático de validação real. | Gates permanentes e checkpoints. | Chromium, WebKit, rotas, overflow, lifecycle e invariantes. | Usuário não deve ser QA botão a botão. | Expandir receipt único da definição de pronto e manter claims honestos. |
| QA-02 | N7/N9: investimento pode ser `nao_aplicavel` quando escopo oficial restrito não compara com LIQ multi-instituição; N8 preservado. | Contrato histórico registrado. | Build 36: meta 232 aprovados, 0 reprovados, 2 N/A, total 234, três execuções idênticas. | Autorizado em 06/08. | Garantir que auditorias futuras não convertam N/A em aprovado. |
| UX-01 | Mobile 390px/768px/desktop, sem overflow, travamento, observador recursivo ou UI escondida. | Implementado/gated na linha canônica. | Chromium/WebKit, sem churn/overflow/error. | iPhone real revelou falha de sessão fora do gate anterior. | Acrescentar regressões de estado persistido/refresh e E2E físico final. |
| OF-01 | Open Finance provider-neutral, staging/reconciliação antes de efeito financeiro, sem segredo no cliente. | Arquitetura QA 14/14. | Contratos/ACL/backend. | Nenhum consentimento/fornecedor autorizado. | Pesquisa de preço/SLA/cobertura; decisão e consentimento são `AGUARDA_DECISAO`. |
| REL-01 | Homologação fixa preservada; root público separado e protegido. | Homologação canônica ativa; `index.html` intacto. | Smokes/Pages verdes. | Promoção não autorizada. | Continuar `not_promoted` até autorização explícita. |

## V150 e V151 — preservação explícita

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

## Pendências ordenadas sem depender do chat

### P0 executável agora

1. fechar inventário navegável das capacidades do briefing que não estão nas seis rotas primárias;
2. aproximar o Dashboard da referência oficial em pixel, densidade, controles, gráficos e drill-down, com dados reais ou estado indisponível honesto;
3. completar recuperação de rota após refresh/restauração de sessão;
4. ampliar o receipt automático para a definição de pronto completa;
5. melhorar Despesas/Atualizações sem regressão de densidade ou evidência.

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

