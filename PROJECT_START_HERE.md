# LTS Wealth — Comece aqui

Este é o ponto obrigatório de retomada do projeto. Um novo chat ou agente deve ler este arquivo antes de alterar produto, banco ou homologação.

## Verdade atual — 10/09/2026

- A candidata canônica v1.24 foi **rejeitada pelo usuário**. Gates automáticos verdes não equivalem a homologação humana.
- A recuperação está dividida em entregas sequenciais. A entrega atual é exclusivamente o **Fluxo Diário**.
- A V152 permanece como referência auditada, e o contrato visual/funcional do Fluxo é a V150 mostrada e validada pelo usuário. A candidata executa diretamente o componente de Fluxo preservado em `index.html`; a cadeia cumulativa V137–V152 não é executada porque o gate comprovou congelamento causado pela sobreposição de wrappers.
- O Dashboard não pode ser redesenhado nesta etapa. Antes de qualquer implementação futura, deve existir uma imagem completa da proposta e aprovação explícita do usuário.
- O `index.html` público continua protegido. A recuperação só pode ser exposta pelo link fixo de homologação.

## Ordem obrigatória de leitura ao retomar

1. `PROJECT_START_HERE.md`
2. `LTS_WEALTH_PRODUCT_CONTRACT.md`
3. `LTS_WEALTH_DECISION_LEDGER.md`
4. `LTS_WEALTH_EXECUTION_STATE.md`
5. `NEXT_HOMOLOGATION_GATE.md`
6. `PROJECT_MASTER_BACKLOG.md`
7. checkpoint mais recente em `backups/`

Os chats são fonte de contexto, mas não são a memória operacional do produto. Toda decisão recuperada deve estar no contrato ou no ledger. Se uma instrução histórica não puder ser comprovada, registrar como pendência de evidência; não pedir que o usuário repita o projeto inteiro e não inventar a regra ausente.

## Sequência de entrega autorizada

1. Recuperar e homologar diretamente o componente de Fluxo Diário V150 preservado, usando a V152 como referência comparativa.
2. Fechar os ajustes de fatura Visa Aeternum/C6 usando o mesmo modelo de resumo, categorias e detalhe.
3. Produzir uma imagem completa do Dashboard proposto; aguardar aprovação.
4. Somente então implementar o Dashboard aprovado.
5. Evoluir Despesas, Receitas, Cartões e demais módulos em pacotes separados e verificáveis.

## Linha de recuperação vigente

- Candidata: `wip35-v162-candidate.html`
- Fonte executada: componente de Fluxo preservado em `index.html` (o arquivo público não é modificado)
- Referência histórica auditada: V150/V152
- Contrato do Fluxo: `v150-flow-direct-current-read-v2`
- Leitura do Fluxo: `lts_browser_flow_v10`
- Dashboard dentro desta candidata: fora de escopo e oculto da navegação de homologação
- Promoção pública: não autorizada

## Regra de encerramento

Uma etapa só pode ser declarada concluída quando código, teste automático, limite da evidência real e resultado da homologação humana estiverem registrados separadamente. “Abriu”, “workflow verde” e “usuário aprovou” são estados diferentes.
