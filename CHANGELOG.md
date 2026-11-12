# Changelog

## Cedentes, aba Ficha, filtro de FIP e negativos em vermelho — 2026-11-11

- **Aba Cedentes** (app e painel publicado), logo após FIDC: os cedentes dos FIDC como publicados na
  Tabela I do informe mensal (9 maiores de cada bloco: I.2.a.12 e I.2.b.12 desde nov/2019; I.2.b.1 até
  out/2019), por competência. Ranking por número de FIDCs, filtros por cedente ou FIDC, pessoa física ou
  jurídica e bloco; detalhe com os FIDCs, posição e participação; clique no FIDC abre a ficha na aba FIDC.
  CPF completo, como publicado (`decision_0038`). Participações acima de 100% (cerca de 10% dos valores)
  são inconsistências do próprio informe: aparecem como publicadas, marcadas com ⚠. Mesmo pacote JSON
  nos dois (`src/intelligence/cedente_data.R`, `prototype/www/cedentes.js`).
- **Aba Ficha** (app local), entre FIAGRO e Cobertura e qualidade: qualquer fundo, com Ficha e Série
  completa na largura toda (`prototype/fund_record_module.R`).
- **FIP:** filtro "Entidade de investimento" (sim, não, não informado), pelo último informe que publicou
  `ENTID_INVEST`; o detalhe do fundo mostra o valor e o mês do informe.
- **Administradores:** a lista de fundos mostra PL e % do total do administrador.
- **Valores negativos sempre em vermelho**, no app e no painel publicado (células, KPIs, barras, ficha).
- Série completa: valores no tamanho do cabeçalho das competências, CNPJ e números sem quebra.
- `TAXMINER_KEEP_FICHAS=1` na exportação mantém `data/fichas/` quando a consolidação não mudou.

## Ficha e Série completa no painel publicado — 2026-11-11

- As abas de fundos do painel publicado (Fundos, FIDC, FII, FIP, FIAGRO) ganham Ficha e Série completa,
  como no app local, para as tabelas principais de cada tipo: FIDC tab_I; FII geral, complemento e
  ativo/passivo mensais; FIP trimestral e quadrimestral; FIAGRO mensal. As demais tabelas seguem no app local.
- Um arquivo por fundo (`data/fichas/{tipo}/{CNPJ}.json`, mediana 28 KB), baixado só quando o fundo é
  aberto. Valores e rótulos são gerados pelas mesmas funções do app (formato brasileiro, máscara de
  CNPJ/CPF, descrição do dicionário da CVM) e cada coluna cita arquivo, linha e SHA-256 da origem.

## Navegação mais rápida — 2026-11-11

- Administradores (app local): índice administrador × fundo calculado uma vez na carga; trocar de
  administrador caiu de ~3,1 s para ~0,5–0,8 s e o clique num mês de ~1,0 s para ~0,2 s. As listas
  de barras são montadas como texto num só passo (mesma marcação). Resultados idênticos aos anteriores
  (conferido nos dados reais e em teste).
- Fichas (app local): cada tabela é aberta uma vez por sessão e as últimas 40 consultas de fundo ficam
  em memória; reabrir um fundo ou voltar a uma tabela já vista não lê o parquet de novo.
- Painel publicado: nomes normalizados uma vez na carga e lista filtrada/ordenada reaproveitada na troca
  de página; ordenar caiu de ~180 ms para ~40 ms e "próxima página" de ~250 ms para ~30 ms.

## Versão na aba Sobre e Panorama com 30 maiores — 2026-11-11

- Aba Sobre (app e painel publicado): versão e data/hora de geração da página logo abaixo do
  título, no formato `v.1.0.1 · aaaa-mm-dd hh:mm`. A versão vem do arquivo `VERSION` na raiz.
- Panorama: os rankings passam a mostrar os 30 maiores administradores e os 30 maiores fundos;
  a lista de fundos mostra o % de cada fundo no patrimônio filtrado (mesma base dos administradores).
- Ficha e série completa: campos de CNPJ e CPF com máscara (00.000.000/0000-00 e 000.000.000-00)
  quando os dígitos verificadores conferem; nos campos "CPF ou CNPJ" do cedente, o tipo é reconhecido
  pelo valor. Valor inválido aparece como publicado, sem máscara, para não disfarçar erro da fonte.
- Panorama: duplo clique num fundo abre a aba do tipo (FIDC, FII, FIP, FIAGRO) já filtrada pelo CNPJ
  do fundo e com o fundo aberto, no app e no painel publicado; o filtro de administrador é limpo e o
  estado do Panorama não muda.
- Série completa transposta, como um demonstrativo: uma linha por campo com os mesmos rótulos da
  Ficha (descrição do dicionário; itálico sem descrição; código CVM na dica), uma coluna por
  competência do mais recente ao mais antigo, com link e citação da fonte no cabeçalho; rótulos fixos
  à esquerda e cabeçalho fixo no alto; campos vazios em todos os períodos ocultos; colunas estreitas
  (valores em fonte 30% menor, espaçamento reduzido, texto quebrando em 52 px, números completos
  como publicados).
- Rodapé de paginação (Anterior / Página / Próxima) menor, em caixa alta, com filete acima, no app e
  no painel publicado.

## Ajustes após a 1.0 — 2026-11-11

- Série completa do fundo: tabela montada como texto, coluna a coluna, em vez de um objeto por
  célula. Num FIDC com 165 períodos e cerca de 80 campos, a montagem cai de 23,6 s para 0,45 s,
  com a mesma formatação (teste de equivalência e de tempo em `test_fund_reports_search.R`).
- Painel publicado: as abas do topo recebem o mesmo estilo do app (caixa alta pequena, sublinhado
  só na aba ativa); no HTML estático elas não têm a classe `nav-link` que o Shiny adiciona no app.

## Estilo executivo, PL nas listas e ordenação por PL — 2026-11-11

- Listas de fundos (Fundos, FIDC, FII, FIP, FIAGRO) ganham as colunas PL (mês de referência do tipo;
  fora dele, o último informe) e % (participação no PL total do tipo, mesma base do Panorama).
- Toda lista abre ordenada por PL decrescente, também após mudar filtros; sem dados de PL, ordena
  pelo nome.
- Panorama: gráficos por tipo um terço mais baixos; rankings ganham o espaço.
- Estilo executivo em todas as abas: texto sem serifa e títulos/indicadores com serifa, números
  tabulares, filtros e combos menores e sem cantos arredondados, cabeçalhos e rótulos em caixa alta
  pequena, filetes finos no lugar de caixas.
- Ficha do fundo: rótulos e valores menores e uniformes; série completa com citação em uma linha
  (texto completo ao passar o mouse) e ano/versão sem separador de milhar.

## Panorama com filtros cruzados — 2026-11-11

- Estado único de filtros no Panorama: competência (seletor ou clique no gráfico), tipo de fundo,
  administradores e fundos (clique seleciona; Ctrl+clique soma). Filtros combinam por interseção;
  cada filtro ativo aparece com botão de remover; "limpar seleções" e "limpar tudo".
- KPIs, composição, painéis por tipo e os rankings Top 20 são recalculados sobre o mesmo universo
  filtrado; cada gráfico ignora só a própria dimensão e mantém o item selecionado visível.
- Administrador de cada fundo é o informado na competência exibida (vínculo histórico).
- Pacote de dados `processed/metrics/panorama` (`src/intelligence/panorama_data.R`), em cache, usado
  pelo app e pelo painel publicado; motor em `prototype/www/panorama.js`. Página do app passa de
  1,2 MB para 51 KB.
- Testes: dados do Panorama em R e motor de filtros em Node (`tests/testthat/panorama_engine_test.js`).
- Diagnóstico e plano da plataforma de BI em `docs/bi_platform_plan.md`.

## Abas de fundos no painel publicado e Administradores em tela única — 2026-11-11

- Painel publicado (GitHub Pages) ganha as abas Fundos, FIDC, FII, FIP e FIAGRO: lista com busca por
  nome atual ou anterior, CNPJ e administrador, ordenação, paginação, Perfil (indicadores e gráficos) e
  Denominações, lidos no navegador a partir de `site/app/data/` (`prototype/static_funds.R`,
  `prototype/static/taxminer_static.js`). Ficha e série completa seguem no app local.
- Administradores: uma tela, sem rolagem do navegador (só ranking e lista de fundos rolam); fonte e
  gráfico menores; clicar em um mês do gráfico lista os fundos daquela competência.
- Desempenho: o Panorama do app local é montado uma vez na inicialização (carga da página de cerca
  de 6 s para cerca de 1 s).

## Resolução de entidades e abas por tipo de fundo — 2026-11-11

- Serviço central de resolução de entidades (`src/data/entity_resolution.R`): identidade pelo
  CNPJ canônico, denominações agrupadas só por regras do dicionário versionado
  (`config/entity_name_rules.csv`), histórico de nomes com fonte e períodos observados, fila de
  revisão para nomes parecidos mas não equivalentes, relatório de qualidade. Catálogos em
  `processed/master/`; documentação em `docs/entity_resolution.md`.
- Filtros de fundo e administrador consomem o catálogo: `CNPJ formatado — denominação`, várias
  opções por CNPJ, e qualquer uma recupera todo o histórico do CNPJ. Lista com uma linha por
  fundo; nova aba Denominações no detalhe. CNPJ com máscara no app e no painel publicado.
- Abas reordenadas (Panorama, Administradores, Fundos) e uma aba por tipo: FIDC, FII, FIP e
  FIAGRO.
- Texto justificado na página do projeto e na aba Sobre.
- Novo teste `test_entity_resolution.R` (15 casos obrigatórios); o validador roda 11 arquivos.

## Filtros no Panorama, Fundos em uma tela e texto institucional — 2026-11-11

- Panorama: 20 maiores administradores e 20 maiores fundos; clique no gráfico de uma família
  filtra os dois rankings e clique num administrador mostra os maiores fundos dele. Filtros no
  navegador, iguais no app e na versão publicada.
- Fundos: barra de filtros com autocomplete (fundo, administrador com nº de fundos, período,
  famílias), ordenação pelo cabeçalho, sem barras de rolagem da página; ficha com a descrição dos
  campos conforme os metadados da CVM (rótulo derivado em itálico quando não há descrição).
- Valores numéricos exibidos com ponto de milhar e vírgula decimal, alinhados à direita
  (identificadores ficam como publicados).
- Texto institucional (engenharia de dados, IA e engenharia de software) no README e no site.

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
