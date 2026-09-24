# LTS Wealth — Retomada 24/09/2026

Chave de continuidade: **LTS-RETOMADA-20260924**.
Este registro complementa o backlog anterior; não o substitui. É um checkpoint de continuidade, não uma declaração de entrega ou aprovação da V183.

## Fontes e estado confirmado

- Ler também `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_EXECUTION_STATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` e a documentação financeira anterior. Se houver divergência temporal, verificar evidências e não reapresentar estados antigos como atuais.
- O registro privado `LTS_WEALTH_V181_REGRESSAO_E_FEEDBACKS_2026-09-22.md` preserva decisões, fontes e QA anteriores. A última versão lida nesta retomada foi 81.
- O checkpoint privado `public.lts_project_checkpoint`, id `LTS-RETOMADA-20260924`, contém o texto integral do novo roteiro do usuário, valores reportados, requisitos de continuidade, evidências de publicação e limitações. A gravação foi relida e confirmou texto integral idêntico. A linha histórica `canonical` foi preservada.
- Oito novos itens foram acrescentados a `public.lts_product_backlog`, sem substituir os anteriores: cinco requisitos de produto, continuidade/regressão, piloto Open Finance e retomada em Chat.
- PR #79 integrada em `eab1fb7d41b435814afa79ebfdce0a0b3e330a76`; dez workflows da cabeça `edf4fae6f53ceffd2e084101ae8c7db946f74e14` concluídos com sucesso.
- Pages run `36017234485` concluído com sucesso. A conferência final do aplicativo publicado em navegador autenticado não foi confirmada nesta sessão.
- Classificações do recorte 01/01–24/09/2026 foram encerradas no lote anterior; isso não encerra ambiguidades históricas de imóveis, composição de faturas ou o backlog inteiro.
- Novo feedback ainda não implementado nem validado. Não apresentar uma versão nova como concluída.

## Novo escopo preservado

1. **Histórico do apartamento:** recuperar a auditoria da duplicidade de obra/reforma e o valor exato após ajuste; reconciliar aquisição, obra, custos recorrentes e impostos contra as fontes. Desde 2013 deve incluir todo o histórico disponível.
2. **Moradia / imóvel a confirmar:** reaproveitar identificação inequívoca do Excel e decisões anteriores; separar imóvel anterior e atual; solicitar ao usuário somente exceções realmente ambíguas.
3. **Linguagem de produto:** revisar Dashboard, Fluxo, Despesas, Patrimônio, Atualizações, modais e detalhes. Converter informação útil em linguagem clara, sem expor diagnóstico de desenvolvimento.
4. **Composição clicável:** remover sinais decorativos “+”, preservando funcionalidade e acessibilidade. Todo valor relevante deve levar a lançamentos cuja soma seja exata; não classificar por suposição.
5. **Patrimônio:** recuperar versões/decisões aprovadas e mostrar ativos brutos, dívidas atuais, patrimônio líquido e liquidez disponível. Separar saldo para quitação hoje de soma de parcelas futuras, sem somá-los como duas dívidas.
6. **Continuidade e regressão:** registrar requisito, implementação, evidência, validação e pendências. Só encerrar itens implementados e validados. Publicar uma candidata única após regressão financeira e de interface, com resumo objetivo.

IDs do lote: `V183-R20260924-F01` a `F05`, `V183-R20260924-G01`.

## Piloto Open Finance

- A arquitetura existente está em `OPEN_FINANCE_ARCHITECTURE.md`; o estudo anterior em `OPEN_FINANCE_PROVIDER_RESEARCH_2026-08-29.md` é histórico e suas condições comerciais precisam ser revalidadas.
- A consulta de 24/09 confirmou as tabelas de conexões, staging e sincronizações existentes e **zero conexões bancárias cadastradas**. Isso comprova estrutura inicial, não um conector ativo ou teste real.
- A página oficial atual do Meu Pluggy informa uso pessoal gratuito, até cinco conexões do mesmo titular, API pessoal e atualização a cada 24 horas. Não confundir com o plano comercial ou com dados simulados.
- Proposta: começar pelo Itaú, lendo saldo e movimentos de um intervalo curto disponível, e comparar com a fonte bancária/LTS. Dados entram em conferência; nenhuma promoção automática ao fluxo ou despesas.
- Etapa do usuário: criar/acessar Meu Pluggy, selecionar Itaú e concluir o consentimento no banco. Depois, criar/acessar o Dashboard Pluggy e vincular o conector MeuPluggy à aplicação.
- Client ID/Client Secret ficam exclusivamente em configuração segura do servidor. Não solicitar senha bancária ou segredo no chat, nem colocá-los em código público.
- O teste deve demonstrar leitura real, correspondência de saldos/lançamentos e reimportação sem duplicidade. Conectar no portal não significa que o LTS já esteja integrado.
- A atualização do provedor a cada 24 horas não configura, por si só, a sincronização do LTS; essa automação precisa ser implementada no backend.
- Não houve criação de conta, consentimento, conexão real, contratação paga ou chamada autenticada à API do provedor nesta sessão.

Fontes verificadas em 24/09/2026:
- https://www.pluggy.ai/meu-pluggy
- https://www.pluggy.ai/precos
- https://docs.pluggy.ai/en/docs/open-finance/institutions-coverage

## Continuidade entre Chat e Work

Um novo Chat pode ser aberto no mesmo projeto, que reúne fontes e instruções compartilhadas. Isso não garante que todas as ferramentas e sessões autenticadas estejam disponíveis em ambos.

No início da retomada:
1. Leia este checkpoint e as fontes disponíveis.
2. Inspecione as ferramentas reais da sessão.
3. Separe: **posso executar aqui**, **posso analisar/preparar aqui**, **depende de ambiente/acesso adicional**.
4. Continue autonomamente o que for possível, preservando autorizações anteriores e verificando permissões concretas.
5. Não confunda código proposto com arquivo alterado; arquivo alterado com teste executado; teste automático com QA visual; publicação com aceitação.
6. Se uma fonte indispensável não estiver acessível, pedir apenas o trecho/arquivo exato que falta, sem exigir repetição do histórico inteiro.
7. Não afirmar trabalho em segundo plano após encerrar uma resposta se não existir uma execução ativa de fato.

Ferramentas confirmadas nesta sessão: GitHub, Supabase SQL, leitura de texto dos registros e pesquisa web.
Limitação confirmada: conexão com o ambiente local falhou; execução de código local e navegador autenticado não estavam disponíveis.

Fontes oficiais:
- https://learn.chatgpt.com/docs/projects
- https://learn.chatgpt.com/docs/use-chatgpt

## Próxima ação útil

Concluir a configuração pessoal do provedor com consentimento do titular, recuperar a auditoria exata de obra/reforma e avançar nas correções que tenham fonte suficiente. Manter validação visual e regressão integral como pendências enquanto o ambiente de execução não permitir executá-las.
