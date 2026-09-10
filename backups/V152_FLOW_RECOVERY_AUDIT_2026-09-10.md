# LTS Wealth — auditoria de recuperação do Fluxo V152

Data: 10/09/2026

## Objetivo

Recuperar o Fluxo Diário validado sem sobrescrever o checkout com trabalho anterior, sem promover o `index.html` público e sem carregar para o saldo operacional awards futuros.

## Evidência de origem

- V150 validada: `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- Implementação V152: `16319fee1ae22fba9f76b9ed6ecfaba5d63c47c9`.
- Exposição V152: `598d53a441e54d0e416de03f4064e37814019a82`.
- Primeiro shell V153 identificado na sequência histórica: `8527de91a87afab3459a4b82b57590b1bea4412d`.
- Main auditada antes da recuperação: `5ba3dd9648214b65606f39fe02b0777b358299dc`.
- A comparação entre a exposição V152 e a main acima mostrou zero diferenças em `index.html` e em todos os arquivos da cadeia V137–V152. A fonte histórica está preservada; o problema de produto veio da substituição posterior da superfície de homologação.
- Blob protegido de `index.html`: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Evidência do banco

- `lts_browser_flow_v3`, `v4`, `v7`, `v8`, `v9` e `v10` existem e permitem execução ao papel `authenticated`; `anon` não possui execução.
- O leitor V10 separa histórico da leitura futura atual e identifica o motor futuro como `daily-flow-fix86-v18-future-award-economic-parity`.
- A V152 histórica ainda solicita V3/V4. A candidata de recuperação mapeia somente essas leituras para V10 no navegador autenticado; não cria DDL, não amplia privilégios e não toca writers.

## Pacote de recuperação

- `wip35-v162-candidate.html`: entrada isolada da homologação do Fluxo.
- `wip35-v162-flow-recovery.js`: ponte V152/V150 → V10, rota inicial do Fluxo e ocultação do Dashboard fora de escopo.
- `.github/scripts/lts_v162_flow_recovery_gate.js`: prova automatizada desktop/mobile da árvore, colunas, continuidade, faturas e vesting.
- `LTS_WEALTH_PRODUCT_CONTRACT.md`: contrato permanente.
- `LTS_WEALTH_DECISION_LEDGER.md`: decisões e rejeições sem depender do chat.

## Limites explícitos

- A candidata não aprova o Dashboard, Despesas, Receitas ou Cartões como módulos completos.
- Fixture determinístico valida comportamento da interface; não prova os valores reais do usuário.
- Leitura autenticada real e iPhone físico continuam pendentes até execução na sessão/dispositivo do usuário.
- O link fixo de homologação só deve mudar após gate automático verde. O produto público continua sem promoção.

## Estado do gate

`EM_EXECUÇÃO`. Atualizar este checkpoint com o resultado e a identidade exata da candidata antes da exposição.
