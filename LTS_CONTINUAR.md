# LTS-CONTINUAR — instruções permanentes de retomada

**LTS-CONTINUAR** é uma chave de continuidade definida pelo usuário para qualquer retomada do LTS Wealth, em Chat ou Work. Não corresponde a uma data, versão congelada, comando nativo ou garantia de acesso às ferramentas.

## O que fazer ao receber a chave

1. Recuperar o estado mais recente efetivamente salvo e verificável do projeto: checkpoints privados, backlog, evidências de implementação/teste e registros versionados. Usar datas e resultados de execução para distinguir estado atual de histórico. Não voltar automaticamente ao checkpoint de criação deste documento.
2. Preservar todo o backlog anterior, feedbacks posteriores, classificações confirmadas, regras financeiras e comportamentos homologados. Novas pendências são adicionais.
3. Consultar o repositório `lthomesilveira-ui/lts-wealth-`, os registros privados do projeto e, quando disponível, `public.lts_project_checkpoint` e `public.lts_product_backlog` do LTS Wealth. Ler os registros datados mais recentes; a linha de protocolo `LTS-CONTINUAR` não é um checkpoint de implementação e não deve ser escolhida como o último progresso só por seu updated_at.
4. Não presumir que a mensagem mais recente ou uma nova versão publicada encerre pendências. Cada encerramento exige implementação, teste e validação correspondentes. Registrar separadamente implementação, publicação, teste automático, QA autenticado e aceitação do usuário.
5. Verificar as capacidades reais da sessão e informar, de forma breve, o que pode executar agora, o que pode analisar/preparar e o que depende de Work ou outro ambiente com acesso. Não inferir ausência de ferramentas apenas pelo nome do modo, nem prometer ferramentas que não estejam disponíveis.
6. Retomar do próximo item ainda aberto e avançar autonomamente no que estiver autorizado e for possível. Não reiniciar trabalho já comprovado, pedir novamente decisões resolvidas nem alegar execução em segundo plano inexistente.
7. Se um registro indispensável estiver inacessível, identificar somente a fonte/trecho necessário. Não fabricar continuidade a partir da chave nem pedir a repetição de todo o histórico.
8. Ao concluir ou interromper uma rodada, salvar um checkpoint factual com data/hora, escopo, alterações, evidências, pendências e próximo passo. Manter esta chave permanente, preservando checkpoints anteriores. Uma interrupção abrupta pode deixar a última ação sem registro: conferi-la antes de repetir ou declará-la concluída.

## Fontes iniciais a consultar

- `PROJECT_MASTER_BACKLOG.md`
- `LTS_WEALTH_EXECUTION_STATE.md`
- `LTS_WEALTH_CONTINUITY_HANDOFF.md`
- Registros privados de feedback e checkpoints datados mais recentes
- Código, pull requests, migrações e execuções de teste/publicação associados ao último estado confirmado

As fontes podem estar defasadas entre si. Resolver divergências pelas evidências e registrar a correção; não descartar documentos anteriores.

## Mensagem copiável

LTS-CONTINUAR. Recupere o estado mais recente salvo e verificável do LTS Wealth, preserve todo o backlog e as decisões aprovadas e retome do próximo ponto aberto, sem se prender a uma data ou versão antiga. Verifique as ferramentas desta sessão e informe o que consegue executar aqui, o que consegue preparar e o que depende de Work ou outro ambiente. Avance autonomamente no que for possível e mantenha o checkpoint atualizado, sem afirmar implementação, teste ou publicação que não tenham sido comprovados.
