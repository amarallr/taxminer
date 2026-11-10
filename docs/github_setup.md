# Configuração Git e GitHub

Common P02: preparação local executada em 2026-11-10. Identidade Git,
primeiro commit, destino remoto e envio permanecem pendentes de decisões humanas.

## Evidências verificadas

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

## Uso no terminal integrado do RStudio

Da raiz do projeto:

```powershell
& './.local/github_cli/bin/gh.exe' --version
& './.local/github_cli/bin/gh.exe' auth status --active --hostname github.com --no-refresh --json hosts --jq '.hosts | to_entries | map({host: .key, accounts: [.value[] | {login, state, active}]})'
```

O CLI foi verificado no terminal do agente. A execução do CLI no terminal
integrado do RStudio ainda não foi verificada. O teste R no RStudio já passou;
isso não valida automaticamente Git/GitHub no IDE.

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

## Decisões pendentes

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
