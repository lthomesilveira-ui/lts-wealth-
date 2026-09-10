# LTS Wealth — Contrato permanente do produto

Este documento registra o comportamento que não pode depender da memória de um chat. Em conflito com um checkpoint antigo, prevalece a decisão humana mais recente registrada no `LTS_WEALTH_DECISION_LEDGER.md`.

## Fluxo Diário — baseline V150

### Estrutura da linha diária consolidada

| Ordem | Campo | Regra |
|---:|---|---|
| 1 | Data | O controle `+` fica à esquerda da data e abre a árvore daquele dia. |
| 2 | Saldo anterior | Posição operacional de abertura do dia. |
| 3 | Entradas | Apenas entradas operacionais daquele dia. |
| 4 | Saídas | Apenas saídas operacionais daquele dia. |
| 5 | Saldo final | `saldo anterior + entradas - saídas`; o histórico não pode apagar essas colunas. |
| 6 | D0/D1 | Recurso separado, com disponibilidade D0/D1; não é duplicado como entrada. |
| 7 | Saldo c/ D0/D1 | Saldo final acrescido somente do recurso D0/D1. |
| 8 | RSU vested | Somente RSU já vested e reconhecida na camada documental correspondente. |
| 9 | Saldo c/ RSU | Saldo anterior da escada acrescido somente de RSU vested. |
| 10 | FGTS restrito | Saldo documental corrente, separado e restrito; não é D+3. |
| 11 | Saldo total | Escada corrente acrescida do FGTS documental, sem awards futuros. |

`RSUs futuras`, `Cash Awards futuros` e `Posição econômica total` não pertencem ao saldo operacional principal validado. Se forem exibidos futuramente, devem ficar em uma camada condicional separada, nunca somados ao caixa antes da data efetivamente evidenciada de vesting/liquidação/disponibilização.

### Continuidade e árvore diária

- Histórico, hoje e projeção formam uma sequência diária coerente.
- Uma linha histórica continua mostrando saldo anterior, entradas, saídas e saldo final; não pode virar apenas “data + fechamento”.
- Abrir `+` mostra `Histórico / movimentos`, com descrição à esquerda, entrada na coluna de entrada, saída na coluna de saída e classificação/contexto visíveis.
- Fechar ou abrir uma árvore não pode deslocar valores para outra coluna nem perder a posição de rolagem.
- Abas obrigatórias: Consolidado, Itaú, Bradesco e C6. Transferência própria é neutra apenas no consolidado e preserva a direção nas contas.

### Edição e proteção

- Fato realizado/evidenciado é protegido; correção exige conciliação ou reversão auditável.
- Projeção elegível oferece editar, postergar por mudança de data, duplicar, dividir/substituir e cancelar/excluir previsão.
- Toda alteração de projeção preserva origem e trilha append-only. Nenhuma ação pode apagar evidência bruta.
- Classificação pendente aparece como `A classificar · revisar`; o sistema não inventa categoria.

### Faturas

- O pagamento da fatura explica o caixa; as compras explicam consumo. Eles não podem ser contados duas vezes.
- Visa Aeternum e C6 devem usar o mesmo componente: resumo inline, total conciliado, agrupamento por categoria, pendências de classificação e acesso ao detalhe completo.
- Fatura aberta participa da projeção de caixa e pode crescer. Compras só consolidam em Despesas conforme a regra documental de fechamento.
- Ausência de detalhe histórico deve aparecer como ausência de evidência; não autoriza criar compras sintéticas.

### RSU e Cash Awards

- Quantidade/valor total concedido ou futuro não integra saldo disponível.
- RSU entra na escada somente quando vested conforme data e evidência aplicáveis; liquidação e prazo de disponibilidade permanecem explícitos quando distintos.
- Cash Award futuro só afeta caixa na data de vesting/liquidação/disponibilização documentada. Antes disso é cenário condicional, não saldo.
- FGTS nunca compensa ou mascara esses limites.

### Mobile

- Cada dia deve ser legível como bloco, sem overflow horizontal da página.
- O bloco preserva data/status, saldo anterior, entradas, saídas, saldo final, camadas de liquidez e árvore de movimentos.
- Navegação não pode redirecionar automaticamente ao Dashboard durante a homologação do Fluxo.

## Dashboard — processo obrigatório

- Nenhum novo Dashboard pode ser implementado antes de uma imagem completa da proposta ser apresentada e aprovada pelo usuário.
- A referência visual oficial continua em `LTS_WEALTH_VISUAL_CONTRACT.md`, mas ela não torna uma implementação automaticamente aprovada.
- Valores de referência visual são ilustrativos; somente leitores/evidências do LTS podem preencher dados reais.
- O Dashboard rejeitado em 10/09/2026 não é baseline e não pode ser descrito como homologado.

## Demais módulos

- Despesas, Receitas, Cartões, Patrimônio e Atualizações precisam de critérios próprios de aceite antes de serem declarados concluídos.
- Classificação confirmada pelo usuário prevalece sobre sugestão. Pesquisa pública serve como evidência auxiliar, nunca como prova de finalidade.
- Upload não lança fato financeiro. Documento e nome de arquivo não autorizam inferência financeira.
