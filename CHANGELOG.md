# Changelog

## Revisão geral do projeto — 2026-11-10

- Prompts alinhados (títulos, fonte dupla, nomes en-US, fases e pós-MVP);
  detalhes em `prompts/CHANGELOG.md`.
- Registros: vocabulário `approved`, `acceptance_register.csv`, handoff enxuto
  com `handoff_history.md`, `risk_0010`, `decision_0013`, `work_0018`, `test_0020`.
- Arquitetura: propostas para fallback de IDs, identificadores de empresa,
  nível de evidência das relações, armazenamento e local do Shiny.
- Setup: `.gitattributes`; diagnóstico restrito às dependências declaradas.
- Exceção `doit` documentada em `AGENTS.md`/`CLAUDE.md`.

## Repositório público — 2026-11-10

- Tornada pública, por solicitação do usuário, a visibilidade de
  `amarallr/taxminer`; GitHub confirmou `private=false` e branch `main`.
- Registrado que metadados de autoria do histórico ficaram públicos e que a
  licença de distribuição continua indefinida.

## Correção do validador Windows — 2026-11-10

- O validador ajusta `LC_CTYPE` para UTF-8 dentro do processo R quando o locale
  herdado não é aceito pelo R do Windows; o comando direto passou com 5 checks.
- O helper do terminal RStudio deixou de limpar variáveis de ambiente externas.
- Permanecem visíveis avisos de inicialização de outras categorias de locale e
  do `testthat` compilado em uma versão mais nova de R.

## Revisão do ambiente — 2026-11-10

- Conferidos os caminhos por usuário de R, Git, GitHub CLI, Codex, Gemini CLI,
  Node.js e npm; corrigidas instruções vigentes que ainda apontavam para `.local/`.
- Registrada a falha do comando R com o locale herdado e a aprovação das cinco
  verificações após limpar variáveis regionais somente no processo filho.
- Registrada a ausência atual do destino de estado global renv configurado e a
  necessidade de o desenvolvedor verificar a sincronização da pasta OneDrive.
- Atualizados guias de ambiente, GitHub, retomada e painel. Nenhuma instalação,
  configuração persistente, autenticação, commit ou publicação ocorreu nesta revisão.

## Histórico — baseline do setup local (2026-11-10)

Os itens a seguir registram o estado inicial do setup e foram superados pelos
registros posteriores de aceite P02 e visibilidade pública.

- Criados os registros mínimos de governança e alinhados os prompts às três fases.
- Preparada a fundação local RStudio com dependências explícitas, bootstrap
  offline, teste sintético e regras de exclusão das áreas protegidas.
- Nenhum MVP, aceite humano do MVP ou release realizado naquele momento.
- Validado o ambiente R no terminal integrado do RStudio; registrada a limpeza
  regional apenas no processo de validação e preservadas as falhas anteriores.
- Preparado GitHub CLI portátil local com digest verificado e autenticação
  existente validada; revisada lista explícita para o primeiro commit.
  Naquele momento, identidade Git, commit e destino remoto permaneciam pendentes.
