# TaxMiner — estado do projeto

## Checkpoint mais recente — Git/GitHub publicado em 2026-11-10T11:02:28-03:00

Autorização humana explícita: identidade Lucas Rodrigues Amaral
<amaral.lr@gmail.com>, repositório privado, primeiro commit e envio.
Identidade configurada somente neste Git local. Repositório criado e
confirmado PRIVATE: https://github.com/amarallr/taxminer.
Origin: https://github.com/amarallr/taxminer.git; branch main acompanha origin/main.
Primeiro commit: 48cc18973133c3fe749b9e96607fc6c86cb0a3d7
Mensagem: chore: initialize TaxMiner development foundation.

45 arquivos regulares revisados; índice e árvore do commit conferidos contra
lista explícita. Nenhum link ou submódulo; único commit raiz antes do envio;
busca limitada de padrões sensíveis sem ocorrências. Push concluído e
ls-remote confirmou o mesmo hash em refs/heads/main. Nova consulta confirmou
PRIVATE e isEmpty false. Evidências em docs/github_setup.md e
reports/execution/github_publication.txt. Arquivos de estação, bibliotecas,
binários, relatórios de execução e ZIP histórico não foram incluídos.
Nenhuma área protegida acessada. Nenhuma configuração global alterada.

work_0003: implementação in_progress, testes locais/remotos passed, aceite
pending, release not_released, operations not_started. A verificação Git/CLI
no terminal integrado do RStudio continua não confirmada: a tentativa não
gerou relatório. Isso não invalida o commit e envio verificados pelo terminal
do agente. Setup geral e integrações opcionais continuam pendentes de revisão.
Publicar código em repositório privado não equivale a release ou aceite de MVP.
Não houve execução de pipeline; saúde operacional unknown.

Painel Common: implementação not_started 4 / in_progress 3 / blocked 3;
testes not_run 5 / passed 2 / blocked 3; aceite pending 10;
release not_released 10; operations not_started 10. Collect/Data/Intelligence
continuam respectivamente com 2/2/3 itens não iniciados, testes não executados,
aceite pending, release not_released e operations not_started.

Pendência estática: git diff --cached --check inicial apontou espaços finais
no arquivo gerado renv/activate.R e linhas vazias finais em três registros.
As linhas vazias dos registros foram corrigidas; o bootstrap gerado do renv
foi preservado sem alteração. Não declarar essa checagem global aprovada.
O teste R no RStudio permanece aprovado com 5 verificações e aviso de versão
compilada do testthat. Aceite humano do setup não foi inferido da autorização
para commit/envio.

Próximas ações: (1) developer revisar setup e decidir as integrações opcionais;
(2) codex/developer verificar o CLI no terminal integrado se requerido para
fechamento do setup; (3) executar Common P03 após autorização da etapa.
Este registro será incluído em um commit documental de acompanhamento, com
hash final disponível em git log e evidência local após o envio.
Os checkpoints anteriores abaixo são históricos.


## Autorização e configuração — 2026-11-10T11:00:26-03:00

Usuário confirmou: usar Lucas Rodrigues Amaral / amaral.lr@gmail.com,
repositório privado e autorização para commit e envio. Identidade gravada
somente em git config --local. Criado https://github.com/amarallr/taxminer;
consulta autenticada confirmou visibility PRIVATE e isEmpty true.
Origin configurado como https://github.com/amarallr/taxminer.git.
Índice inicialmente vazio; os 45 candidatos tinham hashes idênticos à revisão.
Commit e envio serão registrados após resultados reais; aceite do setup e
MVPs continua pending. A tentativa adicional de teste GitHub no RStudio não
gerou relatório; resultado não confirmado, sem alegação de teste aprovado.


## Checkpoint mais recente — Git/GitHub em 2026-11-10T10:51:56-03:00

Escopo autorizado: concluir a preparação Git/GitHub do Common P02.
Git 2.55.0.windows.4, branch main, HEAD ausente e nenhum remoto na consulta.
GitHub CLI portátil 2.103.3 disponível em .local/github_cli/bin/gh.exe,
com SHA-256 conferido contra a release oficial; sem instalação global ou PATH.
Autenticação existente do terminal validada pela rede para amarallr: success.
Plugin GitHub também identificou amarallr. Não houve novo login.
Evidências e limites em docs/github_setup.md e reports/execution/github_validation.txt.

Preparada lista explícita de arquivos para revisão do primeiro commit,
com hashes e busca limitada de padrões sensíveis sem ocorrências.
Simulação inicial de inclusão dos 44 candidatos passou após autorização de
acesso ao índice; não houve staging, commit, criação remota ou push.
Relatórios com caminhos de estação permanecem locais por regra de .gitignore.
Lista e hashes finais em reports/execution/initial_commit_files.txt e
reports/execution/initial_commit_review.csv; revisão não inclui áreas protegidas.

work_0003 permanece blocked/test blocked: faltam identidade escolhida pelo
usuário, destino/visibilidade, teste de commit e verificação do CLI no terminal
integrado. Perguntas de identidade e destino enviadas; respostas pendentes.
Aceite pending, release not_released, operations not_started. Estados dos MVPs
inalterados. A validação R no RStudio permanece passed, com 5 verificações.

Próximas ações: (1) developer responder identidade local e destino/visibilidade;
(2) codex aplicar identidade confirmada e apresentar lista final de commit;
(3) codex/developer realizar commit e operações remotas dentro da autorização
específica confirmada. Common P03 ainda não executado; sem aceite humano inferido.
Os checkpoints anteriores abaixo são históricos.


## Checkpoint mais recente — validação no RStudio em 2026-11-10T10:45:08-03:00

Common P02: validação executada no terminal integrado da janela original do
TaxMiner, sem abrir outra instância nesta retomada. R 4.5.1; testthat 3.3.2;
5 verificações aprovadas, 0 falhas, 0 avisos internos, código de saída 0.
Permanece o aviso externo de testthat compilado no R 4.5.3.
Evidências: reports/execution/rstudio_validation_dispatch.txt e
reports/execution/rstudio_environment_validation.txt.

A tentativa anterior no terminal integrado em 2026-11-10T10:42:51-03:00 falhou:
4 verificações aprovadas e 1 falha de acentos, com avisos de locale.
Preservada em reports/execution/rstudio_environment_validation_failed.txt.
A reexecução passou após limpar LANG e as categorias LC explicitamente listadas
em scripts/validate_rstudio_terminal.ps1, apenas no processo filho.
O helper scripts/validate_rstudio_terminal.R inicia esse comando pelo RStudio.
Para reproduzir no console R do projeto aberto:
source("scripts/validate_rstudio_terminal.R")

Setup permanece in_progress; teste passed; aceite pending;
release not_released; operations not_started. Os estados dos MVPs e das
integrações opcionais não mudaram. Não houve commit, push ou instalação.
Próximas ações: (1) developer revisar resultado e pendências de setup;
(2) developer definir identidade Git local e decidir integrações opcionais;
(3) codex/developer detalhar Common P03 após consolidação do setup e autorização
da etapa. Nenhum aceite humano inferido desta solicitação de execução.
Os checkpoints anteriores abaixo são históricos.


## Checkpoint atual — Common P02

Atualização: 2026-11-10T10:29:15-03:00. Fase: `environment_setup`.
Branch `main`; commit `unknown` (repositório local inicializado sem commits).
Remotos: nenhum. Escopo autorizado: executar Common P02 localmente.

Fundação criada: projeto RStudio, AGENTS.md, exclusões Git/renv, manifesto e
lockfile de dependências, scripts de diagnóstico/setup/validação, README e
changelog. Bootstrap offline executado; teste sintético passou nas 5 verificações.
Uma falha anterior com duas causas foi corrigida e preservada no registro de
testes. Reexecução do bootstrap manteve o hash do lockfile. Evidências completas
em `docs/development_environment.md` e `reports/execution/environment_validation.txt`.

| module | items | implementation_status | test_status | acceptance_status | release_status | operations_status |
|---|---:|---|---|---|---|---|
| common | 10 | not_started: 4; in_progress: 2; blocked: 4 | not_run: 5; passed: 1; blocked: 4 | pending: 10 | not_released: 10 | not_started: 10 |
| collect | 2 | not_started: 2 | not_run: 2 | pending: 2 | not_released: 2 | not_started: 2 |
| data | 2 | not_started: 2 | not_run: 2 | pending: 2 | not_released: 2 | not_started: 2 |
| intelligence | 3 | not_started: 3 | not_run: 3 | pending: 3 | not_released: 3 | not_started: 3 |

Common P02 permanece em andamento. Faltam abertura/teste no RStudio, identidade
Git, commit local autorizado e validação das integrações opcionais. GitHub CLI,
Claude e Gemini não foram encontrados no PATH; Copilot não foi ativado/testado.
Codex instalado/autenticado; workflow no terminal RStudio não verificado.
Nenhum aceite humano concedido. Há aviso de testthat compilado no R 4.5.3,
enquanto a execução usa R 4.5.1. Última operação de pipeline: nenhuma registrada;
saúde operacional `unknown`. Os três MVPs continuam não iniciados e pendentes
de testes, aceite, release e operação; o teste de ambiente não altera seus estados.

Próximas três ações:

| priority | action | owner | dependency |
|---:|---|---|---|
| 1 | Abrir taxminer.Rproj e executar validação no terminal integrado | developer | fundação local disponível |
| 2 | Definir identidade Git local; decidir instalações e ativação das integrações opcionais | developer | revisão da matriz de capacidades; autorização de mudanças fora do projeto |
| 3 | Revisar o setup e detalhar Common P03 | codex; developer | evidências mínimas do ambiente; pendências opcionais explicitamente documentadas |

Nenhuma instalação global, commit, push, configuração global ou coleta foi
realizada. Aprovações pendentes: aceite do setup, commit quando desejado,
instalações externas necessárias, escopos/aceites de cada fase e publicação.
Requisitos continuam propostos, sem aceite implícito. A política de indexação e
sincronização das áreas protegidas exige verificação local humana.

## Histórico — diagnóstico inicial

Atualização verificada: 2026-11-10T10:22:47-03:00.
Fase: `planning`. Escopo desta sessão: diagnóstico, registros mínimos e correção documental do roteiro de três fases. Branch e commit: `unknown`; os comandos Git informaram que a pasta não é um repositório.

## Evidências e limites

- O inventário não recursivo da raiz permitida mostrou apenas `prompts/` antes desta criação de registros. Não havia código, testes, configuração de projeto RStudio ou registros de gestão na área avaliada.
- `prompts/README.md` declara que o pacote 1.0 contém somente prompts e documentação. Foram identificados 16 prompts, README, changelog e um ZIP. O ZIP não foi aberto nem atualizado.
- Foram lidos Common P01, README e changelog; os prompts P02, P03 e P06 foram consultados para planejar dependências, sem executá-los. A disponibilidade do ambiente R/RStudio, das integrações, das fontes e de documentos públicos permanece `unknown`.
- Não houve acesso a `restricted/` ou `tmp/`, instalação, configuração de ambiente, inicialização de Git, coleta, autenticação ou publicação.
- O usuário autorizou a criação destes registros e pediu expressamente a correção dos prompts que ainda descreviam duas fases. Isso não constitui aceite de requisitos, do software ou de qualquer MVP.
- As contagens abaixo correspondem apenas aos itens iniciais cadastrados; não representam cobertura completa do futuro backlog.

## Painel inicial por módulo

| module | items | implementation_status | test_status | acceptance_status | release_status | operations_status |
|---|---:|---|---|---|---|---|
| common | 10 | not_started: 10 | not_run: 10 | pending: 10 | not_released: 10 | not_started: 10 |
| collect | 2 | not_started: 2 | not_run: 2 | pending: 2 | not_released: 2 | not_started: 2 |
| data | 2 | not_started: 2 | not_run: 2 | pending: 2 | not_released: 2 | not_started: 2 |
| intelligence | 3 | not_started: 3 | not_run: 3 | pending: 3 | not_released: 3 | not_started: 3 |

Evidência de implementação dos 17 itens futuros: ausente. Testes do software: não executados. Aceites humanos: pendentes. Releases e execuções operacionais: nenhum registrado; saúde operacional `unknown`. Nenhum estado positivo foi inferido da documentação criada.

Verificação documental em 2026-11-10T10:22:47-03:00: CSVs importados com sucesso; confirmadas as contagens de 11 requisitos, 17 itens e 6 riscos, unicidade dos IDs de trabalho, referências a requisitos/dependências, arquivos de evidência e cinco estados iniciais. Confirmada a presença do roteiro de três fases nos 16 prompts. Busca complementar identificou as referências a duas fases somente como história explicitamente superada no changelog. Essas verificações não são testes do software nem aceite humano.

## Marco obrigatório: prototype_mvp

| milestone | scope | dependencies | implementation | test | acceptance | release | operations |
|---|---|---|---|---|---|---|---|
| prototype_phase_1 | Soluções de Consulta: coleta, extração, Parquet e busca Shiny local com fonte oficial | work_0001; work_0002; work_0008; work_0009; work_0010; work_0015 | not_started | not_run | pending | not_released | not_started |
| prototype_phase_2 | Notas explicativas: coleta, extração, Parquet e busca Shiny independente da fase 1 | work_0001; work_0002; work_0011; work_0012; work_0013; work_0016 | not_started | not_run | pending | not_released | not_started |
| prototype_phase_3 | Relações entre as duas bases aceitas; citações lado a lado e incerteza | work_0014; work_0015; work_0016; work_0017 | not_started | not_run | pending | not_released | not_started |

Amostra proposta da fase 1: até 100 Soluções de Consulta públicas, condicionada à disponibilidade real, regras de acesso e aprovação do escopo. Amostra da fase 2: tamanho, empresas e períodos `unknown`, a definir após verificar as fontes. Busca semântica: proposta de adiamento para além do primeiro MVP, ainda sujeita à definição do escopo. Uma única interface Shiny deve ter áreas funcionais independentes.

## Sequência e critérios de progressão

1. Common P02: configurar ambiente, exclusões e dependências; acompanhar Git/GitHub, Codex, Claude Code, Gemini CLI e GitHub Copilot separadamente. Estado instalado, autenticado, testado e aceito exige evidência própria; não presumir suporte nativo no RStudio.
2. Common P03: definir contratos por fonte, critérios mensuráveis e arquitetura mínima. Validar viabilidade pública antes de implementar aquisição.
3. Fase 1: Collect P01/P02 → Data P01/P02 → busca textual em Intelligence P02 → integração Common P06 e aceite próprio.
4. Fase 2: Collect P04 → Data P03 → busca própria → integração Common P06 e aceite próprio. Não depende da busca da fase 1.
5. Fase 3: Intelligence P03 sobre as duas bases aceitas → testes de citações/relações → aceite próprio.

Common P04 e Common P05 aplicam-se a cada fase; Common P01 deve ser revisto em cada marco. Processamento histórico em escala fica condicionado à revisão das evidências do protótipo. Trabalho antecipado entre fases exige dependências documentadas.

Gates: A, requisitos e impacto de segurança identificados; B, implementação revisada; C, testes reais registrados; D, aceite humano explícito; E, publicação autorizada com revisão do conteúdo/histórico e rollback; F, operação verificada com evidências. Nenhum gate de entrega está declarado satisfeito nesta sessão. Criar os registros de teste, aceite, release e operação quando houver eventos reais; não fabricar linhas de execução.

## Riscos, decisões e pendências

Consultar `risk_register.csv` e `decision_log.md`. Principais pendências: ambiente não verificado; fontes/cobertura não verificadas; ausência de Git e exclusões na raiz; configuração de sincronização local desconhecida; ZIP histórico sem as correções dos arquivos avulsos. Os trechos antigos com duas fases foram corrigidos; a referência operacional passa a ser o roteiro de três fases dos arquivos avulsos.

## Próximas três ações

| priority | action | owner | dependency |
|---:|---|---|---|
| 1 | Revisar o diagnóstico e detalhar Common P02 antes da configuração | codex | registros iniciais disponíveis; autorização da etapa de setup |
| 2 | Executar o setup local autorizado e registrar evidências por ferramenta | codex; developer | work_0001; autenticação humana apenas quando necessária |
| 3 | Definir arquitetura e critérios com Common P03 | codex; developer | evidências do setup; work_0002 |

Aprovações futuras: escopo e critérios das fases, aceites humanos independentes e autorização explícita antes de mudanças remotas/publicação. Autenticações devem usar os fluxos oficiais locais, sem segredos nos registros.

## Revalidação no terminal do agente — 2026-11-10T10:40:10-03:00

Comando inicial: Rscript --vanilla scripts/validate_environment.R
Resultado: código 1; 4 verificações aprovadas e 1 falha na comparação de texto
com acentos; avisos de LC_COLLATE, LC_CTYPE, LC_MONETARY e LC_TIME.

Reexecução em processo PowerShell com LANG, LC_ALL e LC_CTYPE removidas:
Remove-Item Env:LANG,Env:LC_ALL,Env:LC_CTYPE -ErrorAction SilentlyContinue
Rscript --vanilla scripts/validate_environment.R
Resultado: código 0; PASS 5, FAIL 0, WARN 0, SKIP 0 no testthat.
Ambiente: R 4.5.1; testthat 3.3.2. Permanece o aviso externo de pacote
compilado no R 4.5.3. Horário acima corresponde ao registro após as execuções;
horários individuais não capturados. Nenhum código ou configuração persistente
foi alterado. Execução no terminal do agente; abertura e terminal integrado do
RStudio continuam não verificados. Setup em andamento; aceite pending;
release not_released; operations not_started. Estados dos MVPs inalterados.
