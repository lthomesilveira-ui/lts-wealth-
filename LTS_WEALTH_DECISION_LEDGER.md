# LTS Wealth — Ledger de decisões

Registro cumulativo de decisões humanas e mudanças de direção. Não apagar entradas antigas; uma decisão posterior deve marcar explicitamente a anterior como substituída ou rejeitada.

## 10/09/2026 — rejeição da canônica v1.24

Status: **REJEITADA PELO USUÁRIO**

- O Dashboard apresentado não corresponde ao layout esperado e não pode ser usado como baseline aprovado.
- O Fluxo visível perdeu a árvore/continuidade e a distribuição de valores validada.
- As colunas de `RSUs futuras`, `Cash Awards futuros` e `Posição econômica total` criaram uma leitura de saldo incompatível com a regra informada: awards futuros só entram quando efetivamente vested/liquidados/disponíveis.
- Despesas, Receitas e Cartões não foram aceitos como entregues.
- Gates automáticos anteriores permanecem como evidência técnica histórica, não como aceite de produto.

## 10/09/2026 — estratégia de recuperação

Status: **AUTORIZADA**

- Entregar por etapas, começando pelo Fluxo Diário.
- Usar a V152 como ponto técnico recuperado e a V150 como contrato visual/funcional do Fluxo.
- Não executar novo Dashboard agora.
- Para o próximo Dashboard: apresentar primeiro uma imagem completa, validar conteúdo/layout com o usuário e somente depois implementar.
- Registrar briefing, feedbacks e decisões no repositório para continuidade entre chats.

## 10/09/2026 — candidata do Fluxo

Status: **EM IMPLEMENTAÇÃO / AINDA NÃO HOMOLOGADA**

- Criar uma candidata separada que abre diretamente no Fluxo e oculta o Dashboard rejeitado durante esta etapa.
- Manter intactos os arquivos históricos V150–V152 e o `index.html` público.
- Adaptar apenas as leituras legadas `lts_browser_flow_v3`/`v4` para o leitor autenticado atual `lts_browser_flow_v10`.
- Não alterar writers financeiros nem classificar dados automaticamente.
- Validar continuidade histórica, árvore, classificação, ações, faturas Visa/C6 e regra de vesting em desktop e mobile antes da exposição.

## Pendências de decisão/evidência

- Os ajustes exatos de fatura posteriores à V152 que não estejam demonstrados por código, screenshot ou documento permanecem `ABERTO_EVIDÊNCIA`; não devem ser reconstruídos por memória presumida.
- Homologação humana do Fluxo recuperado permanece aberta.
- Proposta visual do Dashboard permanece aberta e bloqueia sua implementação.
- Prova autenticada com dados reais e prova em iPhone físico permanecem distintas dos fixtures automáticos e não são alegadas como concluídas.
