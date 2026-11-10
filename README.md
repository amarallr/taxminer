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
o aceite humano do setup permanece pendente.

Dependências desta etapa: `renv` e `testthat`, declaradas em `DESCRIPTION`;
versões e dependências transitivas em `renv.lock`. O bootstrap usa somente
pacotes já instalados, sem descoberta recursiva de dependências:

```powershell
Rscript --vanilla scripts/inspect_environment.R
Rscript --vanilla scripts/setup_environment.R
Rscript --vanilla scripts/validate_environment.R
```

Se houver erro de locale no terminal Windows, o helper
`source("scripts/validate_rstudio_terminal.R")`, executado no console R do
RStudio, inicia a validação com limpeza das categorias regionais explicitadas
em `scripts/validate_rstudio_terminal.ps1`, somente no processo filho.
Não altere variáveis globais. Para restaurar em outro ambiente, inicialize os caminhos
locais definidos em `.Rprofile` e execute `renv::restore(prompt = FALSE)`;
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
adicionadas quando justificadas pelas próximas etapas. CI aguarda repositório
remoto autorizado. Logging e checkpoints de pipeline aguardam operações reais.

## Segurança, Git e licença

`restricted/` e `tmp/` são áreas protegidas inacessíveis aos agentes.
`.gitignore` e `.renvignore` não substituem controle de acesso ou exclusão de
sincronização. O desenvolvedor deve verificar as exclusões de nuvem localmente,
sem expor conteúdos ou metadados dessas áreas.

Nunca use `git add .` ou publique a raiz sem revisão. Adicione somente arquivos
permitidos por caminhos explícitos. Commits seguem Conventional Commits;
commits, remotos e publicação exigem autorização. Não há licença de distribuição
definida; titularidade, visibilidade e eventual licença precisam de decisão
humana antes de publicação. Consulte `CHANGELOG.md` e os registros de gestão.

O GitHub CLI portátil fica em `.local/github_cli/bin/gh.exe`, ignorado pelo Git.
Autenticação existente verificada para `amarallr`; identidade local configurada
e primeiro commit enviado ao repositório privado `amarallr/taxminer`. Consulte `docs/github_setup.md`.
