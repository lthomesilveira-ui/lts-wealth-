# LTS Wealth V179 — validação pré-publicação da recuperação de caixa

Data: 21/09/2026

## Incidente reproduzido

- A mensagem de indisponibilidade de caixa foi reproduzida no navegador publicado com sessão autenticada.
- Em uma carga controlada de oito primeiros carregamentos concorrentes, duas chamadas a `lts_browser_cash_today_v178` atingiram o limite de 20 segundos do cliente e foram abortadas antes de receber resposta HTTP.
- Na mesma medição, chamadas que concluíram chegaram a 19,64 segundos. Isso demonstrou margem insuficiente quando o leitor de caixa competia com os leitores pesados do Dashboard.
- Nenhum acesso anônimo foi concedido e nenhuma posição financeira foi alterada para realizar a reprodução.

## Correção

- A V179 conclui primeiro a leitura de caixa do dia e só então inicia despesas, patrimônio, awards e projeção.
- Uma única nova tentativa automática é admitida apenas para timeout do cliente, falha de rede, timeout SQL ou HTTP temporário.
- Payload incompleto, data divergente, valor não finito ou soma inconsistente continua bloqueado.
- A correção não usa zero, saldo antigo nem total parcial como substituto.

## Evidências pré-publicação

- Workflow `V179 cash recovery`, execução `35592641264`: aprovado.
- Gate específico: ordem de caixa, recuperação automática, limite de uma tentativa, payload incompleto bloqueado, falha persistente controlada e recuperação manual.
- Gates V178 de desktop, mobile e ações: aprovados.
- Regressões protegidas V172–V176 e contratos financeiros/Fluxo: aprovados.
- Sete workflows históricos acionados pelo PR 27: aprovados.
- Hash protegido de `index.html`: `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`, inalterado.
- Candidata direta publicada, em sessão autenticada: caixa completo do dia, soma consistente e total igual ao exibido no Fluxo; retorno Fluxo → Dashboard preservou a posição.

## Limites antes da exposição pelo endereço fixo

- A entrada `homologacao.html` ainda apontava para a V178 durante esta validação.
- O teste autenticado da entrada fixa após login, recarga completa e retorno do Fluxo deve ocorrer somente depois da atualização do manifesto.
- A matriz mobile é automatizada; não houve validação física em telefone nesta etapa.
- A raiz pública protegida não será promovida por esta alteração.
