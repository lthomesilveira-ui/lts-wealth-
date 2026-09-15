# V163 Dashboard executivo — checkpoint de implementação

Data: 15/09/2026

Estado: **IMPLEMENTAÇÃO TESTADA NA BRANCH; PUBLICAÇÃO EM HOMOLOGAÇÃO AINDA PENDENTE**

## Decisão do usuário

O usuário aprovou seguir com os modelos de notebook e celular e ajustar depois de vê-los na prática. A aprovação reforçou que a tela inicial deve responder diretamente se há dinheiro suficiente no horizonte, se o caixa fica negativo, quando ocorre a primeira ruptura e qual é o pior saldo projetado. A ausência de evidência permanece estado indisponível, nunca resposta positiva inferida.

## Implementação

Branch: `work/dashboard-executive-implementation-20260915`

Head remoto testado: `56a083c5a6a77e3425c638474fb0641f80f2c321`

Tree remoto testado: `bb6a980aadfb5213c5b2c32d2999c47438ac829e`

Arquivos centrais:

- `wip35-v163-candidate.html`: candidato direto sobre o `index.html`, sem cadeia histórica de wrappers;
- `lts-dashboard-read-model.js`: estados suficiente, negativo e evidência insuficiente;
- `lts-dashboard-executive-v1.js`: tela inicial, navegação e apresentação responsiva somente-leitura;
- contratos e gates V163 sob `.github/scripts/` e `.github/workflows/`.

O candidato mantém sem alteração os runtimes V162 do Fluxo e da tela reconciliada de Despesas. O `index.html`, writers financeiros, banco, caches e regras financeiras não foram modificados.

## Contratos preservados

- `Contas + curto prazo = bank_cash + d0`, com fallback evidenciado `through_d3 - d3_vested`.
- RSUs vested aparecem separadas; RSUs futuras não viram liquidez presente.
- FGTS continua restrito e separado do caixa atual.
- Primeiro saldo negativo e ponto de gestão são datas diferentes.
- Patrimônio permanece em validação independente; nenhum total foi apresentado como certificado.
- Projeção e fato documentado permanecem camadas distintas.

## Testes e correções

Run final: `34920486665` — **SUCCESS**.

Artifact: `10378150657`.

Digest: `sha256:3df506dc5df98f3b82dc30ee01784f26ca8f58ff1f161564c9de9edaf4ea3c95`.

Cobertura final: notebook 1440 × 1000; celular 390 × 844; cinco KPIs; seis destinos móveis; leitor `lts_browser_dashboard_cockpit_v1`; largura exata sem overflow; navegação Dashboard → Fluxo → Dashboard; nenhum writer financeiro novo.

Runs `34919593554`, `34920023408` e `34920351733` falharam e não são aprovação. Eles revelaram fragilidade de localização do frame, disputa de rota na inicialização e recursão no retorno ao Dashboard. Tudo foi corrigido antes do run final. Runs intermediários que passaram foram supersedidos pelo gate integrado final.

Os valores do gate são controlados e sintéticos. Eles comprovam semântica e geometria, não os dados pessoais reais do usuário.

## Pendências

- integrar o head testado em `main` sem force;
- atualizar o manifest fixo para V163 em commit de exposição separado;
- executar e verificar GitHub Pages;
- verificar o link fixo publicado e a autenticação real;
- realizar revisão material do usuário com sua sessão real;
- manter promoção da raiz pública como decisão explícita separada.
