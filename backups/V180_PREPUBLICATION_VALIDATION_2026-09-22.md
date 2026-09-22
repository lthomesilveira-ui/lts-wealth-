# LTS Wealth V180 — validação pré-publicação documental

Data: 22/09/2026

## Escopo

- Atualização documental de posições bancárias, aplicação D0, posição de corretora e faturas fornecidas pelo usuário.
- Regra de apresentação: categorias sem pessoa confirmada ou pertencentes ao titular aparecem sem prefixo; Benjamin e Larissa permanecem segregados quando identificados.
- Preservação integral dos contratos da V179 para caixa completo, recuperação limitada, recarga e retorno do Fluxo.
- Nenhuma promoção da raiz pública.

## Guardrails aplicados

- Nenhum saldo ausente foi substituído por zero ou por posição antiga.
- O saldo anterior contido em uma fatura aberta não foi contado novamente como obrigação do ciclo seguinte.
- Pagamentos e créditos de fatura não foram classificados como despesa.
- Diferenças entre o total da corretora e os componentes visíveis foram preservadas como componentes não alocados, sem natureza presumida.
- Pendências de identificação, composição histórica e fonte da venda de ações permanecem abertas.
- Valores, documentos, identificadores pessoais e evidências privadas não são publicados neste repositório.

## Gates privados antes da exposição fixa

- Leitores autenticados devem retornar posição completa do dia e igualdade entre Dashboard e Fluxo.
- A entrada fixa deve ser validada após login, recarga completa e Dashboard → Fluxo → Dashboard.
- O teste responsivo automatizado não equivale a uma validação física em telefone.
- A V177 e o `index.html` protegido devem permanecer inalterados.
