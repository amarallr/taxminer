# TaxMiner

Projeto independente, não oficial da Receita Federal, para pesquisa sobre
Soluções de Consulta públicas e notas explicativas de demonstrações financeiras.
Esta etapa entrega a fundação local de desenvolvimento; não há pipeline ou
interface de busca implementados.

O roteiro tem três MVPs com aceites humanos independentes: consultas tributárias,
notas explicativas com busca independente e inteligência entre as duas bases.
Os módulos futuros são Collect, Data e Intelligence, com utilitários Common.
Contratos e arquitetura detalhada serão definidos no Common P03.

## Ambiente e execução

Ambiente verificado: Windows, R 4.5.1 e RStudio 2024.04.0+735. Abra
`taxminer.Rproj` no RStudio e use a raiz como diretório do terminal. O projeto
desabilita restauração/salvamento de workspace, histórico e indexação de código.
A validação no terminal integrado do RStudio passou nas cinco verificações;
o aceite humano do setup Common P02 foi registrado. O smoke test integrado dos
CLIs permanece pendente.

Dependências desta etapa: `renv` e `testthat`, declaradas em `DESCRIPTION`;
versões e dependências transitivas em `renv.lock`. O bootstrap usa somente
pacotes já instalados, sem descoberta recursiva de dependências:

```powershell
Rscript --vanilla scripts/inspect_environment.R
Rscript --vanilla scripts/setup_environment.R
Rscript --vanilla scripts/validate_environment.R
```

No Windows, o próprio validador normaliza `LC_CTYPE` para UTF-8 somente no
processo R de validação; avisos de inicialização sobre outras categorias de
locale podem continuar aparecendo. Nenhuma variável global ou de usuário é
alterada. O helper `source("scripts/validate_rstudio_terminal.R")` continua
disponível no console R do RStudio. Para restaurar em outro ambiente, inicialize
os caminhos locais definidos em `.Rprofile` e execute `renv::restore(prompt = FALSE)`;
isso pode exigir rede e acesso ao repositório CRAN. A restauração limpa em
outra máquina ainda não foi validada.

## Estrutura

- `scripts/`: diagnóstico, bootstrap e validação local.
- `tests/testthat/`: teste sintético do ambiente.
- `renv/` e `renv.lock`: infraestrutura e bloqueio de dependências.
- `docs/project_management/`: requisitos, estados, riscos e retomada.
- `docs/development_environment.md`: matriz de ferramentas e pendências.
- `prompts/`: instruções por etapa; os arquivos avulsos são a referência atual.

Não há fontes públicas verificadas, documentos coletados, Parquet ou produtos
analíticos nesta etapa. Bibliotecas de aquisição, extração e Shiny serão
adicionadas quando justificadas pelas próximas etapas. O repositório remoto
é público; o CI (`.github/workflows/validate_environment.yml`) restaura o
`renv.lock` e roda o validador no Windows. Logging e checkpoints de
pipeline aguardam operações reais.

## Segurança, Git e licença

`restricted/` e `tmp/` são áreas protegidas inacessíveis aos agentes. O atalho
`doit` lê `.claude/doit.txt`, arquivo local ignorado pelo Git.
`.gitignore` e `.renvignore` não substituem controle de acesso ou exclusão de
sincronização. O desenvolvedor deve verificar as exclusões de nuvem localmente,
sem expor conteúdos ou metadados dessas áreas.

Nunca use `git add .` ou publique a raiz sem revisão. Adicione somente arquivos
permitidos por caminhos explícitos. Commits seguem Conventional Commits;
commits, remotos e publicação exigem autorização. O código está sob licença MIT
(`LICENSE`); documentos coletados de terceiros seguem os termos de cada fonte e
não são cobertos por ela. A visibilidade
pública foi solicitada pelo usuário e registrada nos documentos de gestão.
Consulte `CHANGELOG.md` e os registros de gestão.

O GitHub CLI está instalado por usuário em `%LOCALAPPDATA%/Programs/TaxMiner/github_cli/bin/gh.exe`; esse diretório está no PATH do usuário. Consulte `docs/github_setup.md`.
Autenticação existente verificada para `amarallr`; identidade local configurada
e repositório público `amarallr/taxminer`. Consulte `docs/github_setup.md`.
