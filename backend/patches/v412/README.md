# V412 — Projeções por regra confirmada

## Comportamento

O horizonte termina em 31 de dezembro do ano atual mais cinco. O motor reutiliza
o leitor operacional instalado e o job diário de continuidade V366/V376. As novas
linhas são calculadas na leitura; esta migração não insere receitas, despesas,
pagamentos nem parcelas nas fontes financeiras.

Uma política pertence a um usuário e fica no namespace
`lts_owner_projection_policy_v412`. Uma referência derivada completa fica em
`lts_projection_reference_v412`. Ambos usam o armazenamento e o backup já
existentes. Os contratos JSON descrevem os campos; nenhum titular, valor ou
documento particular é incluído nestas fontes públicas.

## Métodos

| Método | Regra |
| --- | --- |
| `history_total_budget` | Média nominal de 12 competências completas. Orçamento total = maior entre a média e o valor já coberto; somente a diferença positiva entra no fluxo. |
| `fixed` | Valor nominal confirmado durante a vigência, sem reajuste automático. |
| `salary_net` | Base nominal menos a parcela documental persistida. Um salário líquido já presente é preservado; não recebe outro desconto. |
| `inflated_calendar` | Calendário de referência e taxa anual explícita. Só substitui estimativas futuras identificadas, da mesma série e direção. Valores futuros documentados prevalecem. |
| `repeat_calendar` | Repete as datas e os valores de um ano de referência explícito, sem aumento. |

O orçamento total do cartão não é uma previsão de novas compras somada às
parcelas. Compras adicionais podem ultrapassar esse orçamento quando as parcelas
já o dominam. Uma fatura fechada ou pagamento confirmado prevalece na competência
e não recebe complemento até a média. Datas canônicas dos ciclos já incluem a
transição de vencimento e não são deslocadas uma segunda vez.

## Fontes e cobertura

Cabeçalhos de fatura exigem validade, unicidade da competência e vínculo à conta
do próprio usuário. Pagamento da fatura não é somado à despesa de compras.
Despesas bancárias periódicas exigem a seleção explícita da política e uma
ocorrência identificada por mês. Ausência não representa zero.

Na despesa classificada, meses sem gasto entram como zero somente quando há uma
auditoria de cobertura com hashes correspondentes ao acervo e às fontes bancárias
atuais. A despesa em cartão e sua liquidação documental ficam fora do orçamento
de desembolso direto. Uma mudança da fonte invalida essa cobertura até a revisão;
não elimina a última referência completa.

`coverage_months` conta meses completos; `observed_months` também inclui meses
parciais. Valores atípicos permanecem na média e são sinalizados. A soma do ano
corrente considera só datas futuras e é identificada como parcial.

## Virada anual e atualização

A primeira janela usa os 12 meses encerrados antes da aprovação. Nos anos
seguintes, a revisão usa janeiro a dezembro do ano anterior. Uma janela incompleta
mantém a última referência completa e sua data, inclusive para o novo ano do
horizonte. A atualização da referência exige os 12 meses completos, usa aritmética
decimal, verifica o hash do estado anterior, grava auditoria e é idempotente.

`lts_browser_projection_refresh_v412()` exige a identidade validada pelo servidor.
Ele atualiza somente a referência derivada, reutiliza o materializador de planos
fixos existente e invalida cinco caches derivados por usuário, além do epoch de
leitura. Nenhum novo cron é criado. Uma decisão de encerramento posterior à
ativação da política continua valendo nos anos acrescentados ao horizonte.

## Aplicação e verificação

O arquivo de migração foi criado com a CLI do Supabase e é montado por:

```sh
python3 backend/tools/projection_policy_v412/build_migration.py
python3 backend/tools/projection_policy_v412/build_migration.py --check
python3 backend/tools/projection_policy_v412/test_sql.py --help
```

O gate usa PostgreSQL 17 descartável, fixtures fictícias e a migração exata. Cobre
as regras, fronteiras anuais, fontes incompletas, isolamento, caches, repetição da
migração, preservação dos predecessores e reversão. A interface tem testes de
modelo e navegador separados; esses testes não representam uma sessão privada
nem um iPhone físico.

O seed particular é uma etapa separada, com guardas de identidade e fonte. Seu
replay não deve sobrescrever uma referência derivada mais nova nem mudar o marco
de ativação de uma política idêntica. Após o seed, o administrador pode chamar
`lts_projection_private_v412.invalidate_reads(owner_uuid)` sem fabricar uma
sessão do usuário.

`rollback.sql` restaura os dois corpos de função anteriores apenas se não houver
drift, desativa os dois RPCs novos e preserva fontes, política, referência e
auditoria. Reaplicar a migração restaura a integração.

Fixed rules may include ordered `amount_changes` with a documentary `source_ref`,
`effective_on` and positive two-decimal `amount_brl`. The original amount applies
until each effective date. These dates never redefine the billing day; cancelled,
existing and documentary occurrences retain precedence. Changes on other methods,
duplicate dates and incomplete price evidence are rejected.
