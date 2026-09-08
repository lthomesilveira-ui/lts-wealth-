# LTS Wealth — Matriz de Requisitos, Decisões e Validações

Última auditoria material: 08/09/2026 08:05 BRT (America/Sao_Paulo)

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
| Canonical v1.6 Briefing Capability Recovery | Mantém Pass 5 e recupera Central de Gestão com dez capacidades históricas, sem aumentar as seis rotas primárias mobile. | `VERDE_AUTOMATICO` no gate; E2E autenticado e paridade visual do Dashboard continuam abertos. |
| Canonical v1.6 Dashboard Fidelity Pass 6 | Recupera ordem de navegação da referência, competência/as-of, `Hoje`, sinais de evidência e drill-downs reais; preserva os dez contratos de gestão. | `VERDE_AUTOMATICO` em Chromium/WebKit e exposto na homologação fixa; paridade pixel-perfect e E2E autenticado continuam abertos. |
| Canonical v1.7 Route Continuity + DoD Receipt | Preserva integralmente Pass 6, restaura rota/painel após refresh/sessão/back-forward e produz um recibo único da definição de pronto. | `VERDE_AUTOMATICO`; recibo mantém E2E autenticado, iPhone físico e promoção pública explicitamente abertos. |
| Canonical v1.8 Unified Expenses | Remove o segundo dono de Despesas e reúne histórico mensal/anual, natureza × contexto, semântica de `Não atribuído`, insights evidenciados e drill-down de mês/item. | `VERDE_AUTOMATICO` em Chromium/WebKit e exposto na homologação fixa; E2E autenticado/iPhone físico continuam abertos. |

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
| FLOW-01 | Fluxo passado/hoje/futuro, horizonte operacional de 90 dias, prioridade absoluta de confiabilidade. | Rota canônica, `lts_browser_flow_v8` e contrato `v150-validated-flow-plus-v157-liquidity-v1`; botão Hoje e próximos cinco dias completos restaurados. | Gate local Chromium desktop/mobile: presets, 14 colunas consolidadas, cinco dias, expansão e troca de conta. | Uso real ainda não fechado. | CI WebKit desta versão e E2E autenticado físico. |
| FLOW-02 | Consolidado + Itaú + Bradesco + C6, sem inferir banco ausente. | Implementado. | Gate físico de seleção das quatro visões. | Regra original e atual. | Provar com dados reais no iPhone. |
| FLOW-03 | Transferência interna e banco↔ativo têm efeito econômico consolidado zero; pagamento de fatura não duplica despesa. | Implementado nos leitores/movimentos; o débito da fatura abre resumo/composição conciliada dentro do dia via `lts_browser_card_settlement_detail_v2`. | Gate percorre direção/neutro da transferência, resumo, total, créditos, delta caixa×detalhe e fatura completa. | Regra original e comportamento V150 recuperado. | Save→refresh e fatura real autenticados ainda pendentes. |
| FLOW-04 | Projeção pode ser editada, duplicada, dividida/substituída ou cancelada sem apagar a origem. | UI canônica usa `lts_browser_flow_event_editor_v1` + `lts_browser_flow_mutate_v1`; divisão suporta 2–12 partes e soma visível. | Gate executa tabs, adicionar/remover partes, soma e confirma `writer_called:false` na fixture; backend append-only permanece comprovado. | Comportamento V150 recuperado; nenhum write financeiro real usado no teste. | E2E autenticado de edit/duplicate/split/cancel e readback. |
| DASH-01 | Dashboard visualmente alinhado à referência oficial 1312×1199. | Pass 6 restaura ordem de navegação, competência/as-of, `Hoje`, cinco sinais de evidência, posição bancária e drill-downs; não é pixel-perfect. | Gates `34185954453` e `34186087590`, artefatos desktop/mobile e smokes pós-exposição verdes. | Referência `VALIDADO_USUARIO`; URL fixa verificada deslogada no alvo exato. | `ABERTO_ENGENHARIA`: detalhe pixel-level, gráficos históricos com evidência e E2E real. |
| DASH-02 | Cinco KPIs liquidity-first com valor real e sem falso zero. | Implementado. | Gate determinístico. | Dados reais completos no iPhone não provados. | E2E autenticado; indisponível deve continuar explícito. |
| DASH-03 | Planejamento mostra data de ação/gestão separada da primeira insuficiência. | Implementado no read model/UI. | Gate de alias/Planning. | Regra financeira atual documentada. | Revalidar no E2E e manter sem projeção futura de FGTS. |
| AUTH-01 | Autenticação e sessão na mesma aplicação; erro visível e seguro. | Implementado; JWT futuro tenta espera/refresh/reset seguro e preserva a rota pretendida até o retorno ao login. | WebKit com sessão persistida futura + gates canônicos v1.7. | Erro real foi reportado em iPhone; correção ainda não retestada no aparelho. | `IMPLEMENTADO_NAO_E2E_REAL`. |
| NAV-01 | Navegação por intenção e rotas úteis próprias. | Desktop segue onze intenções da referência; mobile preserva seis rotas físicas canônicas. `Receitas` referencia o Flow comprovado. | Regressão física Pass 6 + continuidade v1.7 em Chromium/WebKit. | Modelo por intenção veio do fix85 e da referência oficial. | E2E autenticado físico continua pendente. |
| NAV-02 | Financiamentos, Planejamento, Receitas/Entradas, Recorrências, Compromissos, Simulações, Conciliação, Relatórios, Documentos e Configurações não podem desaparecer. | As dez capacidades estão visíveis na Central de Gestão dentro de `Atualizações`; desktop também recebe atalhos secundários e mobile mantém seis rotas. | Gates `34185954453` e `34186087590` certificam presença, troca de painéis, responsividade, estado de formulário e ausência de overflow. | Briefing/artefatos antigos exigem essas capacidades; ainda não homologadas com sessão real. | `IMPLEMENTADO_NAO_E2E_REAL`: provar cada leitor/ação aplicável em sessão autenticada. |
| NAV-03 | Rota/painel não pode ser perdido em refresh, restauração de sessão, back/forward, deep link ou recuperação de JWT. | `canonical-route-session-continuity-v1` + painel allowlisted em `sessionStorage`; estado financeiro não é persistido. | Gates `34190659782` / `34191017877`: refresh, deep link, rota inválida, back/forward, bfcache, painel e JWT futuro. | Sessão real no iPhone ainda não revalidada. | `VERDE_AUTOMATICO`; manter E2E físico como prova final separada. |
| EXP-01 | Despesas separa natureza de contexto/pessoa/centro de custo. | Canonical v1.8 reúne períodos, histórico mensal/anual, insights, semântica de `Não atribuído` e drill-down read-only sob um único dono. | Gates `34199824400` / `34200253901`; cache 3.860/3.860 e total R$8.623.752,53 preservados. | Ainda não homologado materialmente pelo usuário. | Reduzir `A classificar` somente por evidência; E2E autenticado/iPhone físico aberto. |
| CARD-01 | Cartões abertos e funcionais, por instituição e competência; sem duplicar fatura+compras. | Rota canônica com detalhe certificado/fallback agregado. | Gate canônico. | Uso real não fechado. | E2E autenticado; recuperar meses Mastercard/Visa/C6 apenas por documento. |
| WEALTH-01 | Patrimônio líquido derivado; ativos, passivos, RSU, FGTS, CIPÓ 396 e Volvo coerentes. | Rota canônica e drill-downs implementados. | Gate canônico + contratos backend. | Evidência material parcial. | Manter gaps RSU/CIPÓ/Volvo explícitos; não inventar valuation/taxas. |
| FGTS-01 | FGTS atual R$22.432,31 em 21/08/2026, restrito ~D+30, nunca D+3; sem projetar depósitos futuros. | Implementado no contrato atual. | Gates Planning/Dashboard. | Decisão do usuário em V151. | Manter regra conservadora em todos os gráficos/cenários. |
| UPD-01 | Atualizações é action center compacto, sem vazios, com motivo claro e `Lançamento por texto` em preview. | Implementado. | Gate canônico. | Uso real não fechado. | Densidade e ciclo real de writes/documentos. |
| SEARCH-01 | Busca incremental desde 10/10/2013, inclui futuros já existentes, total e CSV Excel. | Implementado via `lts_browser_transactions_v1`. | Mastercard: 239 linhas, 01/11/2013–12/04/2028; gate UI. | Não E2E autenticado. | Provar busca/export real. |
| CLASS-01 | Hierarquia: usuário > histórico exato/consistente > pesquisa pública > revisão manual; intermediário não prova finalidade. | Wiring de leitura/escrita implementado. | Lifecycle determinístico. | Não E2E autenticado. | Save→refresh→sumir/resolver/self-heal real. |
| DOC-01 | Associação documental explícita; filename não determina conta/cartão/competência/valor; upload não lança fato. | Leitura/lifecycle e UI implementados. | Gate v147/v149 + canônico. | Não E2E autenticado com PDF/imagem. | Interpretar→revisar real sem auto-post. |
| LIQ-01 | Aplicar/Resgatar aceita formatos pt-BR, nunca adivinha conta/ativo, mostra duas pernas e R$0, exige confirmação. | Implementado. | Desktop/WebKit; fixture writer bloqueado. | Nenhum write financeiro real usado em QA. | Save→refresh→visível autenticado. |
| SAFE-01 | Backup versionado com schema/build/checksum SHA-256; restauração validada e pré-visualizada; bloquear backup parcial. | Superfície canônica implementada: export privado, checksum local, stage/preview backend, frase exata, segunda confirmação e apply não destrutivo; fixture bloqueia writes. | Gates `34179625830` / `34179823179`; RPCs `lts_browser_backup_status_v1`, `lts_browser_backup_export_v1`, `lts_browser_restore_stage_v1`, `lts_browser_restore_apply_v1`. | Não homologado com sessão/dados reais na app canônica. | `IMPLEMENTADO_NAO_E2E_REAL`: export→checksum→stage→preview→apply autenticado e verificação de auditoria. |
| QA-01 | QA automática antes do usuário; zero regressão; distinguir teste automático de validação real. | Gates permanentes agora geram `lts-canonical-definition-of-done-receipt-v1` em desktop Chromium e mobile WebKit. | Recovery/candidate `34190659782` / `34190659780`; canonical gate/candidate `34191017877` / `34191017858`; main smoke/Pages `34191216218` / `34191215874`; artifact `10042106418`; pós-exposição verde. | Usuário não deve ser QA botão a botão; iPhone físico autenticado segue não alegado. | `IMPLEMENTADO_PARCIAL`: recibo único existe e passa, mas linhas autenticadas/reais/físicas permanecem OPEN. |
| QA-02 | N7/N9: investimento pode ser `nao_aplicavel` quando escopo oficial restrito não compara com LIQ multi-instituição; N8 preservado. | Contrato histórico registrado. | Build 36: meta 232 aprovados, 0 reprovados, 2 N/A, total 234, três execuções idênticas. | Autorizado em 06/08. | Garantir que auditorias futuras não convertam N/A em aprovado. |
| UX-01 | Mobile 390px/768px/desktop, sem overflow, travamento, observador recursivo ou UI escondida. | Implementado/gated na linha canônica, incluindo persistência de rota/painel. | Chromium/WebKit, sem churn/overflow/error; refresh/back-forward/deep-link v1.7. | iPhone real revelou falha de sessão fora do gate anterior. | Revalidar E2E físico final; regressão determinística de estado já está fechada. |
| OF-01 | Open Finance provider-neutral, staging/reconciliação antes de efeito financeiro, sem segredo no cliente. | Arquitetura QA 14/14. | Contratos/ACL/backend. | Nenhum consentimento/fornecedor autorizado. | Pesquisa de preço/SLA/cobertura; decisão e consentimento são `AGUARDA_DECISAO`. |
| SEC-01 | Superfície Supabase deve aplicar menor privilégio, RLS e ownership guard sem quebrar RPCs autenticadas. | Migração `20260908045049` aplicada: RLS deny-by-default em 13/13 tabelas, 12 helpers de `user_id` arbitrário internos, Flow v7-v10 authenticated-only, defaults de cliente fechados e `service_role` preservado. | Pós-condições 13/13, 12/12, 4/4, zero SECURITY DEFINER anônimo e zero autenticado sem guard direto; regressão autenticada Flow v8/Dashboard/produto em rollback; Advisor revisto. | No-policy INFO é intencional nas tabelas internas; 65 avisos authenticated SECURITY DEFINER correspondem a RPCs de navegador guardadas. Proteção contra senhas vazadas segue desativada. | `IMPLEMENTADO_REGREDIDO`: manter o gate; revisar/ativar leaked-password protection em janela controlada de Auth. |
| REL-01 | Homologação fixa preservada; root público separado e protegido. | Homologação aponta ao produto `e618ef48e22872ce718c7932872e2316e5660f67`; exposição `33da29ab0818c9dd59dca45f68d3680ed153f6af`; `index.html` intacto. | Smokes/Pages pré e pós-exposição verdes; URL fixa verificada com asset continuity-v7, login limpo, zero KPIs deslogados e nenhum iframe. | Promoção não autorizada. | Continuar `not_promoted` até autorização explícita. |

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

## Pendências ordenadas sem depender do chat

### P0 executável agora

1. integrar/expor v1.9 somente após gates Chromium/WebKit, preservando a paridade V150 do Flow e as 14 camadas posteriores;
2. preservar o baseline Pass 6 e continuar convergência pixel/detail do Dashboard com dados reais ou estado indisponível honesto;
3. manter Despesas v1.8 regression-protected e melhorar Atualizações sem regressão de densidade ou evidência;
4. manter rota/sessão e o recibo único regression-protected, fechando novas linhas automáticas quando surgirem requisitos;
5. manter o novo baseline Supabase regression-protected e revisar leaked-password protection em uma janela controlada de Auth.

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
