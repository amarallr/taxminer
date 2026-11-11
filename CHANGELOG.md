# Changelog

## Painel publicado e Panorama em uma tela — 2026-11-11

- Painel de fundos publicado em https://amarallr.github.io/taxminer/app/ (versão estática gerada
  por `scripts/export_static_dashboard.R`); links no README e na página do projeto.
- Panorama cabe em uma tela, sem barras de rolagem; séries por família com o número de fundos
  (linha tracejada, eixo direito). Fontes menores e página mais larga em todo o app.

## Painel analítico dos fundos — 2026-11-11

- Tabela derivada de métricas por fundo e período (`src/data/build_fund_metrics.R`): patrimônio
  líquido, ativo e cotistas, com citação e reapresentações resolvidas.
- Analítica sem LLM (`src/intelligence/fund_analytics.R`): mês completo, variação em 12 meses,
  totais sem duplicar CNPJ, saldo do FIP entre informes, HHI e ranking de administradores.
- Novas abas Panorama (indicadores, composição por família, séries, maiores administradores e
  fundos, metodologia) e Administradores (ranking, concentração, série e fundos de cada um);
  aba Perfil na ficha do fundo. Gráficos SVG próprios (`prototype/charts.R`), sem pacote novo.
- Novo teste `test_fund_analytics.R` (78). O validador roda 10 arquivos.

## Interface dos fundos e horários corrigidos — 2026-11-11

- Interface em paisagem: filtros com autocomplete (fundo por CNPJ ou nome, administrador,
  períodos), lista paginada e ordenável com seleção por clique, ficha do fundo lado a lado com
  campos na vertical e citação em link, série completa em aba. Estilo próprio sóbrio
  (`prototype/www/taxminer.css`), só com fontes do sistema.
- `bslib` declarado no `DESCRIPTION` (já estava no `renv.lock`).
- Nomes publicados sem letras ("NA", ",", "0") aparecem como "(sem nome publicado)" e vão
  para o fim da lista; o dado guardado não muda.
- Testes da busca: 68.
- Horários dos registros de 10 e 11/11 corrigidos (`decision_0032`).

## Busca dos fundos e plano de processamento documental — 2026-11-11

- Busca dos fundos (`work_0022`): `src/intelligence/search_fund_reports.R`, com diretório de
  fundos em cache, filtros e linhas citadas do informe.
- Primeira área do Shiny em `prototype/` (`app.R`, `fund_search_module.R`) e
  `scripts/run_prototype.R`.
- `shiny` declarado no `DESCRIPTION`; `renv.lock` atualizado pelo setup offline. CI pré-instala
  `otel`, `bslib` e `shiny`.
- Novo teste `test_fund_reports_search.R` (49).
- Plano do processamento documental híbrido (MarkItDown, Markdown + Parquet + metadados):
  `docs/integration/hybrid_document_processing_plan.md`.

## Fundos consolidados e inventário de layouts — 2026-11-11

- Rodada completa da consolidação dos fundos: 102 arquivos, 12,16 milhões de linhas.
  Inventário de layouts e resumo de qualidade em `docs/data_dictionary.md`.
- CI: `scripts/ci_preinstall_locked.R` passa a usar o binário quando a versão travada ainda
  está no CRAN e inclui `cpp11` e `arrow`; limite do job em 60 minutos.

## Fase 1.3 iniciada e dados organizados por fonte — 2026-11-11

- Coleta dos fundos (FII, FIDC, FIP, FIAGRO; `decision_0029`):
  `src/collect/discover_fund_reports.R`, `src/collect/download_fund_reports.R` e
  `scripts/collect_fund_reports.R`. Fontes verificadas; 102 arquivos coletados.
- Consolidação dos fundos em Parquet com linhagem, CNPJ validado e registros de qualidade:
  `src/data/consolidate_fund_reports.R` e `scripts/consolidate_fund_reports.R`.
- Dados locais em uma pasta por família (`decision_0028`): `src/common/data_layout.R` e
  `scripts/organize_data_dir.R`.
- `write_parquet_validated` passou para `src/common/parquet_io.R`.
- CI: `scripts/ci_preinstall_locked.R` instala os pacotes travados sem binário de Windows a
  partir dos tarballs.
- Novos testes: `test_fund_reports_collection.R` (34), `test_data_layout.R` (27) e
  `test_fund_reports_consolidation.R` (29).

## Notas consolidadas em Parquet — 2026-11-11

- `src/data/consolidate_financial_notes.R` e `scripts/extract_financial_notes.R` gravam
  `financial_reports` e `financial_notes` em Parquet, uma parte por pacote, de forma
  incremental (`decision_0027`). 28 testes sintéticos
  (`tests/testthat/test_financial_notes_parquet.R`).
- `arrow` declarado no `DESCRIPTION`; `renv.lock` atualizado.
- Nomes de companhias cortados no catálogo da coleta contornados com o índice da CVM em
  Latin-1 (`risk_0016`).
- CI: pré-instalação de `curl`, `qpdf` e `pdftools` antes do `renv::restore`.
- O escritor de ZIP dos testes passou para `tests/testthat/helper_stored_zip.R`.

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
