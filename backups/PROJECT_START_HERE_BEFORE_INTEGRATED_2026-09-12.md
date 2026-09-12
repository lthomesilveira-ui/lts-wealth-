# LTS Wealth — Comece aqui

Este é o ponto obrigatório de retomada do projeto. Leia também `LTS_WEALTH_EXECUTION_STATE.md` antes de alterar produto, banco ou homologação.

## Verdade atual — 11/09/2026, após confirmações do usuário

- A candidata canônica v1.24 foi rejeitada pelo usuário. Gates automáticos verdes não equivalem a homologação humana.
- A entrega atual continua exclusivamente o Fluxo Diário. V150/V151 é o contrato visual/funcional validado; V152 é referência auditada; a perda material ocorreu na V153.
- A V162 executa diretamente o componente de Fluxo preservado em `index.html`, sem a cadeia cumulativa V137–V152 que congelava.
- Leitor vigente: `lts_browser_flow_v11`, contrato `v150-flow-direct-current-read-v3`; mutações V150 preservadas são encaminhadas a `lts_browser_flow_mutate_v2`.
- A atualização anterior de dados reais permanece aplicada. Vencimento contratual da fatura e data documentada de efeito no caixa são preservados separadamente. A edição manual do financiamento de setembro permanece efetiva.
- As confirmações posteriores resolveram os itens antes ambíguos: o pagamento revisado para Larissa é ajuste do mesmo compromisso de saúde; o Pix de outubro é o seguro Volvo existente; o total de investimentos Itaú é o Cofrinho; o boleto DDA Mercado Pago não é obrigação do usuário e permanece excluído.
- O ZIP do C6 foi aberto com a senha fornecida. O CSV foi importado como detalhe da fatura já existente/paga, conciliado a diferença zero. Anuidade e estorno são linhas separadas com efeito líquido zero; o pagamento anterior do arquivo não virou consumo nem outro débito bancário.
- Foi acrescentada uma posição datada do Cofrinho, preservando a anterior. O leitor de posição corrente foi corrigido para escolher somente o snapshot mais recente de cada ativo, sem duplicá-lo e sem fabricar rendimento ou entrada de caixa.
- Regras exatas já existentes no projeto foram reaproveitadas nas classificações; categorias genéricas do emissor não substituem a taxonomia LTS.
- As decisões, fontes decodificadas, checksums, antes/depois e verificações estão na camada privada e nos checkpoints de execução. A senha não foi gravada nesses documentos ou metadados.
- Continua pendente a identidade documental do pequeno débito de cartão Bradesco. Não atribuir a um Visa específico por aproximação de data ou valor.
- Não orientar classificação em massa ainda: primeiro provar uma classificação real no navegador com `salvar → atualizar → reler/self-heal`.
- O Dashboard segue fora de escopo. Antes de implementação futura deve existir uma imagem completa da proposta e aprovação explícita.
- `index.html` público continua protegido; promoção pública não autorizada.

## Ordem de leitura

1. `LTS_WEALTH_EXECUTION_STATE.md` e este arquivo.
2. `LTS_WEALTH_PRODUCT_CONTRACT.md` e `LTS_WEALTH_DECISION_LEDGER.md`.
3. `backups/V162_USER_CONFIRMATIONS_C6_IMPORT_CHECKPOINT_2026-09-11.md` e eventual checkpoint posterior.
4. Se necessário para a tarefa: `NEXT_HOMOLOGATION_GATE.md`, `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` e `CANONICAL_DELIVERY_MASTER_PLAN.md`.

A decisão humana mais recente, registrada com evidência, prevalece sobre uma pendência antiga. Os chats não são a memória operacional. Não pedir ao usuário que repita o projeto inteiro e não inventar regra ausente. O documento de execução anterior foi arquivado integralmente em `backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_USER_CONFIRMATIONS_2026-09-11.md`; os demais históricos e backlogs não foram apagados.

## Sequência autorizada

1. Continuar a homologação prática do Fluxo V150/V151 recuperado na V162, com os dados confirmados.
2. Garantir o conceito validado do Visa Aeternum nos demais cartões: resumo inline, categorias pelas regras confirmadas, ordenação decrescente por valor e acesso ao detalhe completo, sem fabricar detalhe ausente.
3. Provar uma classificação real e só então liberar a classificação acumulada.
4. Produzir a imagem completa do Dashboard proposto e aguardar aprovação.
5. Implementar o Dashboard aprovado e evoluir os demais módulos em pacotes coerentes e verificáveis.

## Linha vigente e evidência

- Candidata: `wip35-v162-candidate.html`; link fixo: `homologacao.html`.
- Fonte: componente de Fluxo preservado em `index.html`, sem alteração pública.
- Leitura: `lts_browser_flow_v11`; mutação guardada: `lts_browser_flow_mutate_v2`.
- Overlays aplicados em 11/09: `card_invoice_cash_effect_date_overlay_2026_09_11` e `evidence_current_asset_latest_snapshot_guard_2026_09_11`.
- Checkpoint atual: `backups/V162_USER_CONFIRMATIONS_C6_IMPORT_CHECKPOINT_2026-09-11.md`.
- Evidência privada: `source_documents`, tipos `user_confirmation` e `card_statement_csv`, referência 2026-09-11. Os ponteiros de Drive ficam nos metadados privados, não neste repositório público.
- O pós-teste de dados e o RPC de detalhe C6 passaram; isso não significa E2E visual autenticado ou aprovação humana de todo o produto.

## Regra de encerramento

Separar sempre código, publicação, teste automático, dados gravados, leitura pós-gravação e homologação humana. São estados diferentes. Manter todas as pendências históricas não resolvidas na lista-mestra.
