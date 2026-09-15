# LTS Wealth — Proposta visual do Dashboard e dos reports

Status: **PROPOSTA — AGUARDA APROVAÇÃO EXPLÍCITA**

Data: 15/09/2026

Branch de trabalho: `work/dashboard-visual-proposal-20260915`

Esta proposta continua o LTS Wealth existente. Ela não reativa o Dashboard rejeitado em 10/09/2026, não cria outro produto, não altera o Fluxo V150/V151, não muda leitores, cálculos, classificações, banco, caches ou publicação. Os valores das imagens estão ocultos de propósito: o repositório é público e os números da referência visual não são fonte financeira.

## Entregáveis visuais

- Notebook: `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_NOTEBOOK_2026-09-15.svg` e sua renderização `.png`.
- Celular: `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_MOBILE_2026-09-15.svg` e sua renderização `.png`.
- Checkpoint imutável do pacote: `backups/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_PACKAGE_2026-09-15.md`.

## Evidência recuperada antes da proposta

| Verificação | Estado conferido em 15/09/2026 |
|---|---|
| Referência visual oficial | Original recuperado: 1312 × 1199; SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`, exatamente igual ao contrato. O proxy público de 180 × 164 continua apenas como evidência auxiliar. |
| `main` | `80e5f5ff0a9a5833ff0f14f5021c282da7213779` |
| `recovery-v152-flow-20260910` | Mesmo commit de `main`; nenhuma divergência detectada antes da abertura desta branch. |
| Produto apontado pelo manifest | V162, build `39e47fc60c40fa8f3796fab4f73f05dee5a89419`, `wip35-v162-candidate.html`. |
| Publicação | GitHub Pages run `34914204383` concluída com sucesso. A raiz pública continua protegida e `promotion_status` permanece `not_promoted`. |
| Inspeção ao vivo | O link fixo redireciona para o candidato V162 correto e apresenta a autenticação real. O navegador de verificação não possui a sessão privada do usuário; portanto, as rotas autenticadas e os valores pessoais não foram chamados de validados. |
| Tela ativa | `index.html` inicia em Fluxo Diário e a navegação efetiva omite Dashboard. Existe código histórico de Dashboard, mas ele não é baseline aprovado e não será simplesmente reativado. |
| Despesas | A tela efetiva é a ex135 executiva/mensal, ligada por `lts-expense-screen-alignment.js` aos leitores reconciliados. |

## Direção de produto

O Dashboard responde, nesta ordem:

1. **Quanto está disponível agora?**
2. **O que muda no curto prazo e nos horizontes futuros?**
3. **De onde vem a posição e qual é a data da fonte?**
4. **Quais saídas e compromissos exigem atenção?**
5. **Quando agir?**
6. **O que ainda não pode ser afirmado?**

Liquidez, consumo e patrimônio permanecem conceitos diferentes. Uma projeção não vira saldo presente; RSU futura não vira vested; FGTS não entra em D+3; fatura paga não duplica compras; compromisso sem data explícita não é inventado; ausência de evidência não vira zero.

## Proposta para notebook

### Estrutura

1. **Navegação lateral escura e persistente.** Dashboard volta a ser a entrada executiva. Fluxo Diário, Despesas, Receitas, Cartões, Patrimônio, Planejamento e Atualizações mantêm acesso direto. Relatórios, Documentos e Configurações ficam no grupo de controle, sem competir com as rotas financeiras primárias.
2. **Cabeçalho compacto.** Título, subtítulo, período de análise e posição documental aparecem antes dos números. A data da fonte não fica escondida em tooltip.
3. **Primeira faixa com cinco KPIs.** Os nomes vinculantes são: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS` e `Despesas (mês)`.
4. **Primeira linha analítica.** Evolução de liquidez ocupa o maior espaço; distribuição patrimonial e posição por banco são menores e complementares.
5. **Linha operacional.** Fluxo de caixa, principais despesas e próximos compromissos levam às telas de detalhe.
6. **Linha de decisão.** Planejamento separa data de gestão da primeira data negativa; FGTS mantém a restrição D+30; Atualizações mostra somente ações reais.
7. **Continuidade visual dos reports.** Um rodapé de linguagem demonstra como Despesas, Cartões e Patrimônio usam os mesmos cartões, filtros, estados de cobertura e drill-down.

### Primeira dobra e densidade

Em notebook de 1366 px ou mais, cabeçalho, cinco KPIs e a parte principal da evolução aparecem na primeira dobra. O restante continua em rolagem vertical curta. A proposta preserva a densidade da referência oficial sem reduzir texto a tamanhos impraticáveis e sem criar grandes áreas vazias.

### Comportamento

- O seletor de período governa Despesas e as comparações correspondentes; a `posição documental` permanece uma data de fonte independente.
- O horizonte de 90 dias pertence apenas ao gráfico de liquidez. Alterá-lo não modifica silenciosamente os outros cartões.
- Cada KPI e painel abre a análise que explica o valor; não existe cartão decorativo sem origem.
- Estados de carregamento mantêm o rótulo e substituem somente o valor por skeleton. Erro, sessão expirada, fonte desatualizada e dado ausente têm mensagens distintas.
- Valor ausente aparece como `—` e motivo legível. Zero aparece somente quando o leitor devolve zero válido.

## Proposta para celular

A arte representa três trechos da mesma tela em rolagem vertical, não três produtos diferentes:

1. **Resumo:** cabeçalho, período/data-base, cinco KPIs em grade 2 + 2 + 1 e evolução da liquidez.
2. **Análises:** horizontes, cobertura patrimonial honesta e posição por banco.
3. **Decisões:** fluxo, despesas, compromissos, planejamento e FGTS.

A navegação inferior permanece fixa em toda a rolagem. Os rótulos curtos são apenas adaptações móveis e mapeiam sem ambiguidade:

| Rótulo móvel | Rota canônica |
|---|---|
| Início | Dashboard |
| Fluxo | Fluxo Diário |
| Gastos | Despesas |
| Cartões | Cartões |
| Bens | Patrimônio |
| Ações | Atualizações |

Regras móveis:

- largura de referência de 390 px, sem overflow horizontal da página;
- cartões empilhados e gráficos redimensionados, não uma miniatura do desktop;
- alvos de toque de pelo menos 44 × 44 px na implementação;
- informações críticas não dependem de hover;
- as seis rotas primárias continuam fisicamente acessíveis;
- `Dashboard → Fluxo Diário → Dashboard` será um fluxo obrigatório de teste físico.

## Contrato de dados por bloco

Os campos abaixo são caminhos de leitura, não autorização para criar novas fórmulas na camada visual.

| Bloco visível | Leitor e origem canônica | Regra de apresentação | Destino |
|---|---|---|---|
| Data da posição | `lts_browser_dashboard_cockpit_v1.as_of`; metadados de cache de `lts_browser_product_v1.cache` | Mostrar data e aviso de defasagem. Nunca escrever “ao vivo” para uma posição documental. | Atualizações / fontes |
| Dinheiro em contas | `lts_browser_dashboard_cockpit_v1.liquidity.bank_cash` e `.accounts[]` | Total deve reconciliar com as contas exibidas; divergência bloqueia o total, não é arredondada na UI. | Posição por banco / Fluxo |
| Contas + curto prazo | Componentes evidenciados do cockpit: `bank_cash`, `d0`, `through_d3`, `d3_vested`, segundo o contrato já registrado | A composição evidenciada existente (`bank_cash + d0`, com fallback contratado `through_d3 - d3_vested`) deve ser encapsulada uma única vez no adaptador do read model e coberta por teste. O componente recebe um campo semântico pronto; se os componentes faltarem, mostra `—`. | Liquidez |
| RSUs vested | `cockpit.liquidity.d3_vested`; detalhe em `lts_browser_wealth_detail_v1.rsu.vested_positions[]` | Somente posição adquirida. Awards futuros não entram no valor. | Patrimônio / RSUs vested |
| FGTS | `cockpit.liquidity.fgts_d30` e `.fgts_as_of` | Restrito, aproximadamente D+30, fora do disponível D+3 e sem contribuições futuras projetadas. | Patrimônio / FGTS |
| Despesas (mês) | Resumo reconciliado do mês no cockpit, com prova de paridade em `lts_browser_expense_executive_v3.summary.selected_total` | Identificar mês parcial e fatura aberta. Diferença entre leitores bloqueia o KPI até conferência. | Despesas no período |
| Evolução da liquidez | `cockpit.through_d3` como âncora atual; `cockpit.horizons[].current_liquidity_balance`, `.conditional_rsu_balance`, `.restricted_total_balance` | Observado em linha contínua; base, RSU condicional e FGTS restrito em séries nomeadas. Nenhuma série projetada é apresentada como saldo atual. | Planejamento / Fluxo |
| Distribuição patrimonial | `lts_browser_wealth_detail_v1.wealth.summary` e `.distribution[]` | Enquanto Patrimônio não tiver validação independente completa, mostrar cobertura/camadas e `posição em validação`; não fechar donut em 100% nem publicar patrimônio líquido como certificado. | Patrimônio |
| Posição por banco | `cockpit.liquidity.accounts[]` | Banco, saldo e data da fonte por linha. Conta sem data recebe aviso; nenhuma estimativa substitui a fonte. | Fluxo filtrado por banco |
| Fluxo de caixa | `lts_browser_flow_v11(p_from,p_to)` | Preservar 5 dias anteriores + hoje + 30 futuros, inclusive dias zero, projeções e fechamento de dias/faturas. O Dashboard só resume; o Fluxo continua dono das mutações. | Fluxo Diário |
| Principais despesas | `lts_browser_expense_executive_v3.rankings.categories` e janelas já validadas pelo adaptador | Ordem decrescente. Um clique abre mês/categoria e apenas o nível documental disponível. | Despesas |
| Próximos compromissos | `cockpit.cards.next_due`; compromissos contratuais com `next_due`, incluindo `wealth_detail.volvo_financing.next_due` quando aplicável | Somente fatura real ou compromisso contratual com data explícita. `top_actions` sem vencimento não vira compromisso financeiro. | Cartões, Patrimônio ou Planejamento |
| Planejamento | `cockpit.planning_audited.management_point_date` e `.first_negative_date`; detalhe em `lts_browser_planning_executive_v1` | Datas ficam separadas. Ausência de uma delas não autoriza copiar a outra, salvo compatibilidade já documentada no leitor. | Planejamento |
| Atualizações | `cockpit.work.top_actions[]`, contagens e estados de fonte do produto | Ações do usuário, revisões e defasagens são tipos diferentes. Zero na fila revisada não certifica cobertura total. | Atualizações |

## Aplicação da linguagem aos reports

### Despesas

- Preservar a tela ex135 e `lts-expense-screen-alignment.js`; a mudança é visual e composicional, não de fonte.
- Cabeçalho com intervalo e base bancária; KPIs de período; evolução mês a mês; ranking decrescente; cobertura documental; detalhe do mês/categoria.
- Continuar distinguindo `transaction`, `category_only` e `total_only`. Composição histórica por categoria não é uma lista de compras.
- Fatura aberta e mês parcial continuam destacados; comparações não equivalentes permanecem indisponíveis.

### Cartões

- Cabeçalho de conferência, não um segundo painel de gasto.
- Separar ciclo fechado/vencido, ciclo aberto provisório, piso parcelado e parcelas futuras.
- Usar `card_operating`, `card_history`, `lts_browser_card_history_coverage_v1` e detalhe exato por `lts_browser_card_settlement_detail_v2`.
- Pagamento/adiantamento continua evento de caixa, não consumo adicional. Cobertura agregada nunca é transformada em compras inventadas.

### Patrimônio

- Cabeçalho mostra data-base, disponibilidade e cobertura.
- Camadas separadas: contas e liquidez, RSUs vested, awards futuros, FGTS restrito, CIPÓ 396, Volvo, ativos e passivos documentados.
- Valor de ativo, dívida e patrimônio líquido só aparece como certificado depois da validação independente ainda aberta. Até lá, a tela mantém o estado `em validação` e aponta a lacuna concreta.

## Tokens e acessibilidade

| Uso | Token proposto |
|---|---|
| Navegação | `#0D1D31` / selecionado `#1E3B5D` |
| Canvas | `#F3F6FA` |
| Cartão | `#FFFFFF`, borda `#E0E6ED` |
| Texto principal | `#142941` |
| Texto secundário | `#6F7E91` |
| Base / ação | azul `#337BEA` |
| Confirmado / vested | verde `#2AAC7A` |
| Restrito / atenção | âmbar `#D69B2D` |
| Saída / risco | coral `#E56D77` |

Cor nunca é o único indicador: legenda, rótulo e padrão de linha acompanham cada estado. Contraste, foco visível, navegação por teclado, landmarks, nomes acessíveis e redução de movimento entram no gate de implementação.

## Critérios de aceite da implementação, depois da aprovação visual

1. Nova camada de Dashboard, sem reativar a implementação rejeitada de 10/09.
2. `index.html`, Fluxo V150/V151 e Despesas reconciliada preservados; nenhum novo cálculo financeiro espalhado por componentes.
3. Testes determinísticos de seleção, ausência, erro, sessão, data-base, mês parcial, fatura aberta, ranking, compromissos e invariantes de liquidez.
4. Regressão das rotas Fluxo, Despesas, Cartões e Patrimônio nos perfis notebook e celular.
5. Screenshots reais da candidata integrados lado a lado com a referência oficial; geometria/fixture sozinhas não bastam.
6. Navegação física móvel `Dashboard → Fluxo Diário → Dashboard` e ausência de overflow horizontal.
7. CI, commit e artefato de Pages conferidos pelo SHA exato.
8. Homologação em sessão real descrita como pendente até ser executada; somente resposta humana explícita vale como aprovação.
9. Raiz pública continua protegida até autorização separada de promoção.

## Limites e decisão pendente

O pacote não acessou dados privados autenticados porque não havia sessão autorizada no navegador de verificação. Isso não impede aprovar a estrutura visual, pois a proposta usa valores ocultos e contratos já versionados; impede afirmar que números e todas as interações das rotas privadas foram validados neste momento.

A única decisão necessária para iniciar a implementação é: **aprovar esta direção visual para notebook e celular, ou listar os ajustes desejados**. A aprovação autoriza a camada visual e os testes em branch própria; não autoriza promover a raiz pública nem alterar regras financeiras.
