# LTS Wealth — Dashboard cockpit v142 checkpoint — 2026-08-30

Status: ROUND 1/3 DO PACOTE DE DASHBOARD CONCLUÍDA TECNICAMENTE. Ainda não promover para `homologacao-current.json` nem para `index.html`.

## Referência visual recuperada
A referência não é um novo redesign. É o cockpit Claude-era já preservado no `index.html`, especialmente o pacote `dashboard-planning-v114-cockpit` / classes `d114-*`.

Hierarquia preservada:
1. `Sua vida financeira, em uma tela.`
2. Hero `Disponível realizável até D+3` com caixa bancário + D0 + RSU vested e FGTS separado/restrito.
3. Snapshot operacional de cartões e pendências.
4. `Quanto sobra nos próximos horizontes` para 30d / 90d / fim do ano.
5. Bloco de decisão/Planejamento.
6. `O que merece você agora` com poucas ações.
7. Agenda de liquidez futura.
8. Atalhos executivos para Fluxo, Despesas, Cartões e Patrimônio.

Regra de produto: poucos números que decidem; zero narrativa técnica/QA como mensagem primária.

## Read model novo
Criado backend cached `dashboard-cockpit-v1-claude-layout-audited`:
- `lts_refresh_dashboard_cockpit_v1(uuid)` internal-only;
- `lts_browser_dashboard_cockpit_v1()` auth.uid-scoped;
- `lts_dashboard_cockpit_qa_v1(uuid)` internal QA;
- cache dedicado invalida quando `lts_product_read_cache.refreshed_at` muda.

O cockpit usa:
- Flow efetivo já cacheado em v13 para posição atual;
- Planning Excel→motor auditado via `lts_planning_bridge_executive_v1` para semântica de janeiro;
- Wealth effective v5;
- cartões, Atualizações e Despesas do cache canônico atual.

Não usa o `planning_executive` antigo para chamar janeiro de falta real.

### Valores atuais certificados no cockpit
- caixa bancário: R$4.766,99;
- D0 / Cofrinho: R$42.842,59;
- RSU vested D+3: R$32.772,30;
- disponível até D+3: R$80.381,88;
- FGTS atual: R$17.509,05, separado como D+30;
- ponto de gestão: 08/01/2027;
- solicitar FGTS até 09/12/2026;
- pior saldo antes da contingência: R$-21.046,80;
- pior saldo conservador após cobertura: R$+11.262,25;
- primeiro gap não coberto no horizonte auditado: nenhum.

Cockpit QA: 13/13 PASS.
Auth-role DB simulation do browser RPC: PASS.

## Implementação v142
Novo layer `wip35-v142-dashboard-cockpit.js` ligado por `wip35-v142-candidate.html`.

Comportamento:
- restaura Dashboard como primeira aba da navegação;
- abre Dashboard após o cockpit autenticado ficar disponível, uma vez por sessão;
- mantém o layout d114 recuperado;
- adiciona a ponte auditada `Ponto de gestão auditado → Plano de cobertura · FGTS D+30`;
- atalhos mostram números compactos de Fluxo, Despesas, Cartões e Patrimônio;
- comparação de Despesas permanece descritiva quando a cobertura histórica não é homogênea;
- não altera `index.html`.

## Evidência browser/Pages
Head de smoke: `8f9fb976891a7f5d7cafddcd68f22dca4d12742b`.
Candidate-smoke run `33337978951`: SUCCESS.
Pages run `33337978699`: SUCCESS.

Chromium não autenticado:
- desktop 1440×1000 PASS;
- mobile 390×844 PASS;
- chain v142→v141→v140→v139→v138→v137→index PASS;
- visible ownership v142 PASS;
- Planning bridge PASS;
- Dashboard renderer/nav PASS;
- Dashboard nav visible PASS;
- dashboard static copy PASS;
- CSS injections PASS;
- zero new console/page errors;
- zero root overflow desktop/mobile.

Limite: isso não é E2E visual autenticado.

## Financial gates
Heavy gate v14 foi reexecutado após a correção do health-check e voltou a verde:
- 24 suites;
- 293 checks;
- PASS.

Delta gate v15 separado para evitar timeout da infraestrutura:
- liquidity writer v2 10/10;
- transactional rollback 15/15;
- read-path 12/12;
- browser liquidity ACL 17/17;
- Dashboard cockpit 13/13;
- total delta 67/67 em 5 suítes, PASS.

Evidência staged atual: 29 suítes / 360 checks PASS. Não equivale a E2E visual autenticado nem homologação do usuário.

## Pendências imediatas para rounds 2/3
- revisar densidade e hierarquia do Dashboard com dados reais, especialmente mobile;
- garantir que ações `agora` não sejam contaminadas por pendências distantes de 2030/31;
- fechar refresh/invalidation do cockpit para todos os writers que alteram módulos relevantes;
- integrar a nova leitura de Flow v13 de forma coerente nos caminhos de rollover sem reintroduzir v12 na composição pós-movimentação;
- fechar UI revisada de resgate/aplicação somente após preview/confirm/write/read refresh verde;
- sincronizar `PROJECT_MASTER_BACKLOG.md` e `NEXT_HOMOLOGATION_GATE.md` antes de expor v142;
- manter `homologacao-current.json` em v141 até o pacote final dos 3 rounds;
- real authenticated visual E2E continua PENDING / NOT CLAIMED.
