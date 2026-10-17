# Gate sintético do marcador de contexto

Este pacote é autossuficiente e público: não lê baselines privadas em runtime, não contém dados de usuário e não abre conexão por conta própria. Os números, datas, pessoas, fontes e referências de fixtures são inventados.

## Uso pela suíte integradora

Importe `marker_runner.py` e chame `run_marker(sql_callable)`. A função recebida deve executar a string SQL completa em PostgreSQL 17 descartável e devolver stdout de `psql` como string. Use `psql -X -q -A -t --set=ON_ERROR_STOP=1`, levante erro se o processo terminar com código não zero, e não herde variáveis/credenciais de produção.

O contrato fixo é banco e role `wealth_synthetic_classifications` no PostgreSQL 17 isolado em loopback da CI. O SQL confere a versão, o nome do banco e a inexistência da função que receberá o stub. Todo o gate roda em uma transação terminada por `ROLLBACK`. O nome do banco, sozinho, não comprova isolamento; esse isolamento é responsabilidade da suíte integradora.

`build_marker_sql()` apenas monta a transação a partir dos arquivos deste diretório. `verify_public_sources()` apenas confere proveniência estática. Nenhuma dessas duas chamadas equivale a um teste PostgreSQL aprovado.

## O que realmente é executado

- Projeção final completa de 20 campos, exportada dos dois corpos SQL reais
- Expressão `identity_status` original e candidata literalmente intactas
- Predicados brutos executados separadamente para distinguir `NULL`, `false` e `true`, antes do `CASE`
- 38.880 combinações em matriz e 13 cenários nomeados
- Categoria e decisão de categoria, ausência de pessoa SQL `NULL`, pessoa vazia e pessoa sintética, Educação, outros tipos, grupos e componentes em revisão, seis motivos de imóvel, descrição ausente/desconhecida e valores nulos nos campos de saída
- Comparação `IS DISTINCT FROM` de todos os 19 campos não alterados pelo patch, com JSONB preservando nulidade e tipos de saída
- Somente transições `pending → identified` em Saúde/Vestuário sem pessoa; Educação e todos os outros motivos de revisão continuam preservados
- Cobertura da projeção de imóvel e do ramo de empréstimos com dependência substituída por stub declarado

São 13 verificações SQL agregadas, todas não vazias. A saída contém somente contagens, nomes de verificações e hashes de proveniência. Não emite linhas financeiras ou valores privados.

## Fidelidade e sanitização

O helper privado de autoria verificou os hashes das duas baselines contra o manifesto e comprovou que a única diferença integral é o predicado documentado. A projeção final pública substitui exclusivamente duas strings de imóvel por sentinelas: o código em duas ocorrências e o rótulo em uma ocorrência. A reversão dessas três substituições reproduziu cada projeção original byte a byte. Nenhuma expressão do marcador foi alterada pela sanitização.

`source-proof.json` registra essa conferência local, hashes e contagens sem incluir os literais privados. A CI pública confere os arquivos exportados, a diferença exata entre projeções, a expressão do marcador e a igualdade literal do bloco P05 exportado. `p05-original.sql` e `p05-candidate.sql` são fragmentos de CTE para auditoria de igualdade, não instalações ou testes funcionais de P05.

## Limites explícitos

Este é um teste do marcador e da projeção real sobre linhas `labeled` sintéticas. Não executa a baseline completa, enriquecimentos upstream, decisões e dados produtivos, semântica real de `lts_expense_management_subgroup_v2`, nem a execução funcional P05. O único helper externo da projeção tem um stub sintético constante, criado transacionalmente sem substituir função existente. A compatibilidade produtiva completa e o rebase da definição pós-P05 continuam gates distintos.

O arquivo `source-proof.json` prova verificações realizadas na autoria; a CI pública não relê as fontes privadas. Nenhum sucesso em PostgreSQL é afirmado apenas pela geração dos arquivos.
