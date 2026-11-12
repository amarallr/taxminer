# Configuração Git e GitHub

**Status:** vigente; registros por data ·
**Última atualização:** 2026-11-10 ·
**Documentos relacionados:** [Ambiente de desenvolvimento](development_environment.md) ·
[README](../README.md) ·
[Registro de decisões](project_management/decision_log.md)

## Visibilidade atual — 2026-11-10

O repositório `amarallr/taxminer` está público por solicitação explícita do
usuário. A API confirmou `private=false`; `main` é a branch padrão. A alteração
de visibilidade torna públicos o conteúdo atual, o histórico Git, os metadados
de autoria e os logs/artefatos acessíveis pelo repositório. Nenhum caminho
`restricted/` ou `tmp/` estava versionado na revisão. Os metadados de autoria
usam endereços que não são `noreply`, e a configuração Git local atual também
pode usar esse endereço em commits futuros. A licença de distribuição continua
indefinida; visibilidade pública não concede uma licença explícita.

## Estado vigente dos caminhos

O GitHub CLI atual está em `%LOCALAPPDATA%/Programs/TaxMiner/github_cli/bin/gh.exe`;
essa pasta consta no PATH do usuário. No terminal integrado do RStudio, reinicie
o terminal para herdar alterações recentes do PATH e use `gh` diretamente.
Autenticação no terminal integrado foi validada anteriormente; esta revisão de
caminhos não repetiu a consulta autenticada.

```powershell
gh --version
gh auth status --active --hostname github.com --no-refresh
```

O remoto `amarallr/taxminer` e o branch `main` estão configurados. Referências
abaixo à visibilidade privada descrevem o estado histórico anterior.

## Revisão técnica do Common P02 — 2026-11-10T11:09:17-03:00

Fundação local implementada e testes do ambiente R aprovados: 5 verificações
no RStudio, com aviso conhecido de testthat compilado no R 4.5.3 versus R 4.5.1.
Git/GitHub agora também verificados no terminal integrado da janela original:
Git 2.55.0.windows.4; CLI portátil 2.103.3; conta amarallr ativa, estado success.
Execução real: 2026-11-10T11:08:34-03:00 a 2026-11-10T11:08:35-03:00.
Evidência: reports/execution/github_rstudio_validation.txt.
A ausência anterior de relatório foi causada por um parêntese extra no helper R
local; sintaxe corrigida e conferida antes da repetição. Sem nova instância IDE.

Git local main e remoto privado https://github.com/amarallr/taxminer já
configurados; último commit publicado verificado antes desta revisão:
a259a1e35088bb2a497b4775031d5782bf76611d.
Os registros desta revisão são alterações locais ainda não commitadas/enviadas.
Não houve instalação global, novo login, acesso protegido ou coleta.

Escopo desta revisão: manter Claude Code, Gemini CLI e Copilot adiados como
assistentes opcionais, sem instalar/ativar. Seus itens conservam estados
blocked/blocked e aceite pending, com adiamento explícito; não representam
bloqueio da fundação R/Git. Codex está funcional nesta sessão; smoke test de
outra sessão de assistente no RStudio não executado e adiado. Nenhum outro
assistente foi iniciado. Nenhum estado VERIFIED foi atribuído a essas opções.

work_0001 e work_0003: implemented / passed / pending / not_released /
not_started. Setup tecnicamente apresentado para aceite, sem homologação
inferida. Common: implementação implemented 2, in_progress 1, blocked 3,
not_started 4; testes passed 2, blocked 3, not_run 5; aceite pending 10;
release not_released 10; operations not_started 10. Demais módulos inalterados.

Limites para revisão humana: exclusões de sincronização e controles de acesso
locais precisam de verificação humana; restauração limpa em outra máquina não
foi validada; aviso de versão do testthat permanece; checagem global de espaços
finais tem ocorrência conhecida no bootstrap gerado do renv. Nenhum release,
MVP ou operação de pipeline aprovado/executado; saúde operacional unknown.

Próximas ações: (1) developer aceitar ou rejeitar explicitamente o setup com
estes limites e adiamentos; (2) após esse aceite e autorização de etapa,
executar Common P03; (3) reavaliar integrações opcionais quando necessárias.
Common P03 não foi iniciado. Regra de aceite: AGENTS.md exige Never infer
approval; Common P01, Gate D, exige aprovação explícita de reviewer humano.
Os checkpoints anteriores abaixo são históricos.

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

Histórico: antes da decisão humana posterior, identidade Git, primeiro commit,
destino remoto e envio ainda estavam pendentes.

## Histórico — evidências antes do primeiro commit

- Git 2.55.0.windows.4 disponível; branch `main`, sem commit HEAD ou remoto.
- Nenhum `user.name` ou `user.email` efetivo/local encontrado na consulta.
- Perfil conectado ao plugin GitHub: `amarallr`. Isso é independente da
  autenticação do terminal.
- GitHub CLI portátil 2.103.3 instalado em `.local/github_cli/bin/gh.exe`;
  nenhuma instalação global ou alteração do PATH.
- Origem: release oficial `cli/cli`, tag `v2.103.3`, arquivo
  `gh_2.103.3_windows_amd64.zip`. SHA-256 conferido contra o digest da API:
  `98d0cfa794721665d7973dd728c78aff7bd836d58f10f6d7a03568eccb0a22e0`.
- Autenticação já existente do CLI validada pela rede: conta `amarallr`,
  estado `success`. Não houve novo login nem exposição de credenciais.
  A primeira consulta no sandbox retornou `error`; a consulta autorizada
  pela rede retornou `success`, sem exigir troca de credenciais.
- Busca pelo plugin por `user:amarallr taxminer` não retornou repositórios.
  Esse resultado não garante disponibilidade do nome ou visibilidade de todos
  os repositórios privados.
- Simulação de `git add --dry-run` aprovada para a lista explícita inicial
  de 44 arquivos. A primeira tentativa recebeu negação de escrita no índice
  pelo sandbox; a repetição autorizada passou. Nenhum arquivo foi adicionado
  ao índice por essa simulação.

## Configuração vigente do GitHub CLI — 2026-11-10

O executável está em `%LOCALAPPDATA%/Programs/TaxMiner/github_cli/bin/gh.exe`, e esse diretório consta no PATH do usuário. `gh --version` foi conferido e retornou 2.103.3. No terminal do RStudio, reinicie o terminal se ele foi aberto antes da alteração do PATH; depois use `gh --version` e `gh auth status`. Os comandos e caminhos absolutos no checkpoint histórico abaixo descrevem a localização anterior e não são instruções atuais; use `gh` pelo PATH do usuário.

## Uso no terminal integrado do RStudio

Da raiz do projeto:

Use os comandos atuais por `gh` no bloco “Estado vigente dos caminhos”. Os
comandos `.local/github_cli/` pertencem ao checkpoint histórico e não são
instruções de uso atuais.

O CLI também foi verificado no terminal integrado do RStudio; consulte
`reports/execution/github_rstudio_validation.txt`. A autenticação e a validação
R têm evidências separadas.

## Revisão do primeiro commit

A lista explícita fica em `reports/execution/initial_commit_files.txt`, e os
hashes dos candidatos em `reports/execution/initial_commit_review.csv`.
A revisão é local: não houve commit ou envio. A busca por padrões de tokens,
chaves privadas e caminhos pessoais não encontrou ocorrências nos 44 arquivos
iniciais. Essa busca é uma verificação limitada, não garantia universal.
A lista será atualizada após as alterações documentais desta etapa.

Relatórios de execução, binários locais, bibliotecas R, arquivos de credenciais
e o ZIP histórico ficam fora do primeiro commit. As regras de exclusão das
áreas protegidas foram verificadas como texto, sem acessar essas áreas.
Os registros mantêm as evidências locais por caminho relativo.

## Histórico — decisões que estavam pendentes

1. Confirmar nome/e-mail de autoria; não deduzir identidade de commit a partir
   do perfil conectado sem escolha do desenvolvedor. A configuração será local.
2. Confirmar proprietário, nome e visibilidade do repositório de destino.
3. Revisar a lista final e autorizar o primeiro commit e eventual publicação
   conforme o escopo confirmado. Não há licença de distribuição definida.

Setup e aceite humano permanecem pendentes. Nenhum MVP, release ou operação
de pipeline foi iniciado por esta configuração.

## Referências oficiais

- [Instalação Windows e binários oficiais](https://github.com/cli/cli/blob/trunk/docs/install_windows.md)
- [Release utilizada](https://github.com/cli/cli/releases/tag/v2.103.3)
- [Verificação de autenticação](https://cli.github.com/manual/gh_auth_status)

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
