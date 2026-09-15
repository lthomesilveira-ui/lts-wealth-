# V163 Dashboard executivo — recibo de publicação

Data: 15/09/2026

Estado: **PUBLICADO EM HOMOLOGAÇÃO; VALIDAÇÃO FINANCEIRA DA SESSÃO REAL PENDENTE**

## Produto e exposição

- implementação integrada em `main`: `6cc1e61630f31694172b6a2a1e0075161cb8bbd5`;
- exposição V163 em `main`: `b2f105e7b48cee6aa1a93c57ef3512df38c6f618`;
- candidato fixo: `wip35-v163-candidate.html`;
- `candidate_head` preservado no manifest: `6cc1e61630f31694172b6a2a1e0075161cb8bbd5`;
- promoção da raiz pública: `not_promoted`.

## Gates e publicação

- V163 Dashboard: `34921104839` — SUCCESS;
- Flow default window: `34921104878` — SUCCESS;
- Integrated Flow and invoices: `34921104879` — SUCCESS;
- Candidate smoke: `34921104916` — SUCCESS;
- GitHub Pages nativo: `34921104617` — SUCCESS.

O Pages nativo publicou o mesmo commit de exposição V163. O painel do workflow manual histórico `pages.yml` exibiu erro ao carregar e não foi tratado como evidência nem usado para alterar o workflow. Não houve workaround de trigger.

## Verificação pública

O link fixo `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` redirecionou para:

`https://lthomesilveira-ui.github.io/lts-wealth-/wip35-v163-candidate.html?homologacao=6cc1e61630f31694172b6a2a1e0075161cb8bbd5&ts=<cache-buster>`

Título observado: `LTS Wealth · Homologação do Resumo Executivo`.

A tela genuína assinada para fora foi exibida, sem valores de fixture. Isso comprova publicação e roteamento, não valida os dados financeiros reais do usuário.

## Pendências preservadas

- autenticar no próprio LTS Wealth e revisar materialmente as respostas de suficiência, primeira data negativa e pior saldo com os dados reais;
- revisar notebook e celular em uso real e registrar ajustes adicionais;
- manter Patrimônio em validação independente;
- decidir separadamente qualquer promoção da raiz pública.
