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
