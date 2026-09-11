# LTS Wealth — Comece aqui

Este é o ponto obrigatório de retomada do projeto. Um novo chat ou agente deve ler este arquivo antes de alterar produto, banco ou homologação.

## Verdade atual — 11/09/2026

- A candidata canônica v1.24 foi **rejeitada pelo usuário**. Gates automáticos verdes não equivalem a homologação humana.
- A recuperação está dividida em entregas sequenciais. A entrega atual continua exclusivamente o **Fluxo Diário**.
- A V150/V151 permanece como contrato visual/funcional validado pelo usuário; a V152 é referência auditada. A perda material ocorreu na V153. A candidata V162 executa diretamente o componente de Fluxo preservado em `index.html`, sem restaurar a cadeia cumulativa V137–V152 que congelava.
- O runtime de leitura vigente é `lts_browser_flow_v11`, contrato `v150-flow-direct-current-read-v3`; as mutações V150 preservadas são encaminhadas ao writer guardado `lts_browser_flow_mutate_v2`.
- O gate V11 de desktop/mobile e o Pages estão verdes. A homologação humana autenticada do Fluxo permanece em andamento e nunca deve ser inferida de automação.
- Em 11/09 foi aplicado um refresh de dados reais suportados por novas evidências: âncoras bancárias documentadas, faturas/pagamentos evidenciados, posição de brokerage e lançamentos futuros inequívocos. O detalhe fechado de cartão recebido foi conciliado a delta zero e usa a mesma camada semântica do modelo Visa Aeternum; descrições sem regra confirmada permanecem `A classificar`.
- A data contratual de vencimento de fatura e a data documentada de efeito no caixa podem ser distintas; a camada de Fluxo preserva ambas e usa o efeito de caixa quando houver evidência separada.
- A edição manual do usuário no financiamento de setembro foi preservada pela trilha append-only e deve continuar prevalecendo no Fluxo efetivo.
- Existem pendências que exigem decisão/evidência humana e não podem ser inferidas: possíveis duplicidades de dois pagamentos para Larissa, identidade de um pequeno débito de cartão Bradesco, composição exata do total de investimentos Itaú, um boleto DDA Mercado Pago sem confirmação de obrigação e um CSV de cartão fornecido dentro de ZIP criptografado.
- **Não orientar classificação em massa ainda.** Antes disso, provar uma classificação real autenticada com ciclo `salvar → atualizar → reler/self-heal` na superfície recuperada.
- O Dashboard não pode ser redesenhado nesta etapa. Antes de qualquer implementação futura, deve existir uma imagem completa da proposta e aprovação explícita do usuário.
- O `index.html` público continua protegido e a promoção pública permanece não autorizada.

## Ordem obrigatória de leitura ao retomar

1. `PROJECT_START_HERE.md`
2. `LTS_WEALTH_PRODUCT_CONTRACT.md`
3. `LTS_WEALTH_DECISION_LEDGER.md`
4. `LTS_WEALTH_EXECUTION_STATE.md`
5. `NEXT_HOMOLOGATION_GATE.md`
6. `PROJECT_MASTER_BACKLOG.md`
7. `backups/V162_FLOW_REAL_DATA_REFRESH_CHECKPOINT_2026-09-11.md`
8. checkpoint posterior em `backups/`, se existir

Os chats são fonte de contexto, mas não são a memória operacional do produto. A evidência privada recebida em 11/09 foi preservada fora do chat; o ponteiro de recuperação fica na camada privada de dados, não neste repositório público. Toda decisão recuperada deve estar no contrato, ledger ou checkpoint. Se uma instrução histórica não puder ser comprovada, registrar como pendência de evidência; não pedir que o usuário repita o projeto inteiro e não inventar a regra ausente.

## Sequência de entrega autorizada

1. Concluir a homologação humana do Fluxo Diário V150/V151 recuperado na V162 usando dados reais atualizados.
2. Fechar os ajustes de faturas e garantir o mesmo conceito validado do Visa Aeternum para os demais cartões: resumo inline, categorias pelas regras confirmadas, ordenação útil e acesso ao detalhe completo, sem fabricar detalhe ausente.
3. Provar um ciclo real de classificação e só então liberar a retomada da classificação acumulada pelo usuário.
4. Produzir uma imagem completa do Dashboard proposto; aguardar aprovação.
5. Somente então implementar o Dashboard aprovado.
6. Evoluir Despesas, Receitas, Cartões e demais módulos em pacotes separados e verificáveis.

## Linha de recuperação vigente

- Candidata: `wip35-v162-candidate.html`
- Fonte executada: componente de Fluxo preservado em `index.html` (o arquivo público não é modificado)
- Referência histórica auditada: V150/V151 como contrato; V152 como comparação
- Contrato do Fluxo: `v150-flow-direct-current-read-v3`
- Leitura do Fluxo: `lts_browser_flow_v11`
- Mutação do Fluxo: chamadas V150 preservadas mapeadas para `lts_browser_flow_mutate_v2`
- Runtime adicional aplicado em 11/09: `card_invoice_cash_effect_date_overlay_2026_09_11`
- Checkpoint corrente: `backups/V162_FLOW_REAL_DATA_REFRESH_CHECKPOINT_2026-09-11.md`
- Dashboard dentro desta candidata: fora de escopo e oculto da navegação de homologação
- Promoção pública: não autorizada

## Regra de encerramento

Uma etapa só pode ser declarada concluída quando código, teste automático, limite da evidência real e resultado da homologação humana estiverem registrados separadamente. “Abriu”, “workflow verde”, “dados foram atualizados” e “usuário aprovou” são estados diferentes.
