# Estado vigente — V268 publicada em 13/10/2026

Homologação: https://lthomesilveira-ui.github.io/lts-wealth-/releases/v268/app.html
Código incorporado pelo PR133: https://github.com/lthomesilveira-ui/lts-wealth-/pull/133
Head validado: 02c0235415b863997a6c0e4720ead81a69c3fdcb
Commit do código no main: 823b4ba5aaf86afd76a53330d83f2992e626db0d

A V268 tem uma interface isolada. Diferencia realizado, previsão, pagamento a confirmar, lacuna e ausência de comprovação. Copiar Consolidado preserva a seleção e os valores desconhecidos. A recuperação de leituras invalidadas contempla solicitações em andamento, troca de sessão e saída da rota. As fontes e os controles financeiros anteriores foram preservados; evidências financeiras particulares ficam fora deste repositório público.

Validação: 18 checks finais aprovados; novos controles em Chromium/WebKit, desktop/celular; documentos, cartões, classificações, períodos, edição e repetição idempotente exercitados com dados controlados. Pages run38466150522 PASS: 669 arquivos de V268 e dez releases anteriores conferidos por SHA256. O endereço foi aberto diretamente e mostrou V268 e a tela de entrada. Isso não é prova de sessão real autenticada nem de iPhone físico.

Antes deste handoff, 2.998 dos 2.999 blobs preexistentes estavam iguais. A única alteração anterior era o workflow de Pages para publicar/verificar V268. Raiz, V264, outros releases publicados e frozen-v181 não foram alterados. O estado V267 abaixo é histórico; sua cópia integral está também em evidence/archive/LTS_WEALTH_EXECUTION_STATE_v267_20261013.md.

O projeto não está integralmente encerrado. Permanecem evidências de conciliação histórica, premissas futuras, pagamentos não comprovados, verificações administrativas de Auth, sessões reais, restauração completa e aceite em aparelho. As respostas financeiras já recebidas continuam válidas; não criar lançamentos ou novas perguntas por ausência de evidência técnica.

Checkpoint privado: LTS-CONTINUAR-V268-20261013.
Retomada canônica: LTS_CONTINUAR.md e Evidencias_LTS_Wealth_V268_2026-10-13.json no conjunto privado do projeto. Health fora; Continuity Watch OFF.

---

## Histórico preservado

## Current continuation — 13 October 2026 (V267 backend)

The interface remains V264. V267 improves source-invalidated reads by inlining two fully qualified pure text expressions and reusing the unchanged paid-identity query plan. Complete private Flow, Expenses and Wealth response comparisons passed; financial sources, identities, ACLs, prior fixes and protected assets stay unchanged. Read the current execution state and `backend/patches/README_v267.md` for the bounded scope and the two intentional static-lint observations. P13 and all other unclosed work remain open. Do not ask resolved financial questions or activate Continuity Watch.

--- Prior continuation preserved ---

## Current continuation — 13 October 2026

Read the current top of `LTS_WEALTH_EXECUTION_STATE.md` before the earlier checkpoints. The interface is V264; V266 is a backend correction for received-invoice due-date rollover, payment-evidence versus forecast-gap classification, and server-only lock protection. The complete private current status and source limits are in LTS_CONTINUAR.md. Older release/status sections below remain historical and cannot recreate answered financial questions.

--- Earlier continuation records preserved ---

## Current consolidated register — V236, 1 October 2026

Read [LTS_WEALTH_V236_CLOSEOUT_MATRIX.md](LTS_WEALTH_V236_CLOSEOUT_MATRIX.md) first for current statuses and source limits. The isolated successor is `releases/v236/app.html`; its publication and QA evidence are recorded in the private delivery receipt. The fixed legacy manifest and protected root are separate entries and do not identify the latest isolated release. Earlier sections below remain historical and must not recreate already answered questions or resolved incidents. No user/physical-phone acceptance is implied.

--- Earlier record preserved ---

# LTS Wealth — Retomada sem depender do chat

Criado em 14/09/2026 por pedido explícito do usuário. Este arquivo é a porta de entrada permanente. O estado atualizado fica em LTS_WEALTH_EXECUTION_STATE.md; este guia não substitui os documentos de decisões, pendências e evidências.

## Frase combinada para copiar em outro chat

> Retome o LTS Wealth no repositório lthomesilveira-ui/lts-wealth-. Leia primeiro RETOMAR_LTS_WEALTH.md no main, confira a branch ativa e o checkpoint mais recente e continue de onde parou, sem reiniciar nem perder pendências.

A frase informa onde buscar o estado; não é uma senha ou mecanismo de memória. Um novo executor deve realmente ler o GitHub e conferir o banco autorizado, não responder como se tivesse feito isso. Caso não consiga acessar uma fonte ou executar uma operação, sinalizar o ponto exato e não inventar o estado nem desfazer decisões.

## Ordem de retomada obrigatória

1. Comparar o main com a branch ativa indicada em LTS_WEALTH_EXECUTION_STATE.md. Em 14/09 a branch é recovery-v152-flow-20260910. Se houver trabalho paralelo, inspecionar a divergência; nunca usar force nem sobrescrever uma versão com outra mais antiga.
2. Ler LTS_WEALTH_EXECUTION_STATE.md e o checkpoint mais recente ali apontado em backups/. A referência inicial desta atualização é V162_N1_N3_AND_INSTALLMENT_RECOVERY_2026-09-14.md; no futuro usar o checkpoint efetivamente mais recente, não esta data fixa.
3. Ler PROJECT_MASTER_BACKLOG.md, PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md, LTS_WEALTH_COVERAGE_FROM_2026-07-07.md e NEXT_HOMOLOGATION_GATE.md. Eles se complementam. Uma fila parcial ou antiga não certifica o período completo.
4. Ler LTS_WEALTH_DECISION_LEDGER.md, LTS_WEALTH_USER_DECISIONS_Q1_Q8_2026-09-13.md, LTS_WEALTH_PRODUCT_CONTRACT.md, LTS_WEALTH_CATEGORY_EQUIVALENCE_PLAN.md e os suplementos/checkpoints citados no estado atual. Uma confirmação posterior substitui apenas a decisão explicitamente tratada, não o restante do histórico.
5. Ler LTS_WEALTH_CONTINUITY_HANDOFF.md e CANONICAL_DELIVERY_MASTER_PLAN.md como contratos e histórico. Trechos antigos sobre versões, bloqueios ou contagens podem estar superados; confrontar com o estado mais recente e a evidência real.
6. Verificar a situação real pela fonte adequada: manifest/Pages para a interface; invoice/Flow readers para dados; source_documents para confirmação, fontes e antes/depois; produto armazenado para o que chega ao resumo. Só depois executar o próximo pacote permitido.

## Onde estão as fontes e as decisões

O GitHub mantém código, requisitos, decisões operacionais, versão publicada, testes, limites e pendências. Os checkpoints em backups/ preservam estados anteriores e não devem ser reescritos. O histórico de commits também deve ser preservado. Isso é um registro operacional, não uma transcrição integral de todos os chats nem uma cópia completa dos dados financeiros.

O Supabase do projeto, acessível pelo conector autorizado, mantém os dados e auditorias privadas de source_documents. Os documentos recebidos ficam no Drive privado/Gmail ou nas origens indicadas nessas auditorias. Recuperar os documentos já recebidos antes de pedir reenvio. Não publicar valores de fatura, dados bancários, endereços, senhas ou recibos privados no repositório.

Os audit_key no checkpoint permitem recuperar a decisão e o registro específico. Não usar apenas o nome do estabelecimento para recriar uma classificação. Dados de origem, categoria original e resposta humana devem permanecer rastreáveis. Nenhuma referência de arquivo deve ser tratada como arquivo local sem verificar sua existência.

## Contratos que não podem regredir

- Preservar o histórico original desde 2013. A revisão pendente é inclusiva desde 07/07/2026, bancos e cartões, inclusive parcelas de compras anteriores que compõem o período. Não declarar o período anterior certificado sem evidência.
- V150/V151 é a referência funcional do Fluxo; a versão publicada precisa ser lida de homologacao-current.json. Em 14/09 o manifest permanece V162. Não voltar a uma release antiga só porque foi referência visual.
- Todas as faturas usam lista única de categorias do maior valor para o menor, resumo e detalhe documental. Ao trocar de banco, dias e faturas fecham; o período escolhido permanece. Padrão: cinco dias anteriores, hoje e trinta futuros, inclusive dias sem movimento.
- Manter as categorias históricas, inclusive Restaurantes e Ifood separados conforme decisão do usuário, e as exceções de novos nomes explicitamente aprovadas. Não ativar o mapa futuro de equivalências agora nem renomear o passado.
- Não contar pagamento de cartão como nova compra, nem adiantamento/reembolso como consumo adicional. Não apagar movimentos de caixa para corrigir relatórios. A ligação Volvo foi confirmada; sua correção no relatório continua um problema técnico enquanto não houver prova de leitura.
- Distinguir decisão recebida, categoria aplicada na origem, consulta verificada, resumo sincronizado, teste de navegador, publicação e homologação humana. Falha de gravação não é sucesso; aprovação de um item não é aprovação do aplicativo inteiro.
- Não reenviar perguntas já respondidas. N1, N2 e N3 do último conjunto estão encerradas: Presentes, Benjamin - Estrutura e manutenção e Cursos, respectivamente. Escopos e fontes estão no checkpoint de 14/09.
- Não contornar operações negadas por outro canal. Uma operação nova aceita não comprova que as anteriormente bloqueadas foram liberadas. Consultar as evidências atuais sem repetir a alegação antiga como se fosse eterna.

## Continuidade de execução

Antes de cada write no GitHub, atualizar main, branch ativa e documentos obrigatórios. Preservar uma cópia imutável do estado anterior ao substituir o resumo operacional. Fechar pacotes coerentes, com antes/depois e testes, em vez de anunciar microbuilds ou devolver QA básico ao usuário. Manter todos os itens antigos abertos até prova específica de conclusão.

O foco é recuperar classificações e fechar inconsistências do Fluxo desde 07/07. Dashboard exige proposta completa aprovada antes de implementação e a raiz pública index.html permanece protegida. Os títulos dos updates são Concluído / Em execução / Próximos passos. Não prometer trabalho automático entre mensagens sem uma automação realmente criada.
