# Changelog

## Dependências da extração declaradas — 2026-11-11

- `DESCRIPTION` passa a declarar `pdftools`, `xml2` e `base64enc` (`decision_0026`).
- `renv.lock` atualizado por snapshot explícito, sem instalação nova.
- `scripts/setup_environment.R` lê os pacotes do campo `Imports`.

## Extração das notas e rotinas comuns — 2026-11-11

- Extração das notas (Fase 1.2) com seleção de conjuntos corrigida e títulos `(N)` como
  alternativa. Rodada local em 83 pacotes: 66 completos. 22 testes sintéticos
  (`tests/testthat/test_financial_notes.R`).
- Rotinas comuns em `src/common/` (`safe_io.R`, `signatures.R`, `execution_policy.R`), só com
  R base. 55 testes sintéticos (`tests/testthat/test_common_primitives.R`).
- O validador inclui os dois novos arquivos de teste.

## Fases reorganizadas — 2026-11-10

- O MVP passa a ter duas fases (`decision_0025`):
  - **Fase 1 — Coleta, estruturação e pesquisa de dados**, com as subfases 1.1 (Soluções de
    Consulta), 1.2 (notas explicativas) e 1.3 (fundos de investimento);
  - **Fase 2 — Inteligência cruzada** sobre as bases aceitas.
- Prompts, arquitetura, requisitos, registros, `AGENTS.md`, README, panorama e site atualizados.

## Fundos de investimento como nova fonte (Fase 4) — 2026-11-10

- Nova família `investment_fund_reports` (FII, FIDC, FIP e FIAGRO) com aceite próprio
  (`decision_0024`). Requisitos `req_0012`–`req_0014`; work items `work_0020`–`work_0023`.
- Listagens da CVM verificadas: `docs/data_sources.md`, `docs/source_inventory.md` e
  `config/investment_fund_report_sources.yml`.
- Novos prompts `collect_p05_investment_fund_report_acquisition.txt` e
  `data_p04_investment_fund_report_consolidation.txt`. O roteiro de todos os prompts passa a ter
  quatro fases.
- Arquitetura, requisitos, dicionário de dados, `AGENTS.md`, README, panorama e site
  atualizados.
- Análise de novas fontes de dados (`docs/integration/new_data_sources_gap_analysis.md`,
  `decision_0023`).

## Collect P01 e GitHub Pages — 2026-11-10

- Fontes verificadas: `docs/source_inventory.md`, `docs/feasibility.md`,
  `scripts/probe_sources.R` e fixture pública `tests/fixtures/normas_search_sample.json`.
- Aceites `acc_0004`–`acc_0008` registrados.
- Panorama publicado no GitHub Pages e linkado no README.

## Assistentes no RStudio — 2026-11-10

- Smoke test sintético corrigido e ampliado ao Claude Code; Codex, Claude Code e
  Gemini aprovados no terminal integrado do RStudio.
- Copilot com login ativo e sugestão aceita, confirmados pelo desenvolvedor.
- `work_0004`–`work_0007` implementados; aceite humano pendente.

## Recomendações da revisão aplicadas — 2026-11-10

- Aceitos `req_0003`, limiares e arquitetura (`acc_0003`).
- Licença MIT; CI mínimo de validação no Windows.
- `doit` passa a usar `.claude/doit.txt`; bloqueio de leitura de `tmp/` restaurado.
- Diretório renv por usuário criado; e-mail noreply para commits futuros.

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
