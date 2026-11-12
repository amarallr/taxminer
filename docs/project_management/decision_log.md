# Registro de decisões

## Revisão documental — 2026-11-10T15:03:27-03:00

Revistos os caminhos por usuário, as entradas de PATH, dependências locais,
pastas de preparação permitidas e evidências de validação. Corrigidas as
orientações vigentes que ainda apontavam para o antigo caminho `.local/` e
para ausência de remoto. Registrados o locale herdado que faz a validação
direta falhar, a repetição aprovada com locale limpo apenas no processo filho,
a ausência do diretório global renv configurado e a localização do checkout
sob OneDrive com sincronização ainda desconhecida. Os detalhes e limites estão
em `docs/development_environment.md`. Não houve mudança de configuração,
instalação, autenticação, publicação ou aceite. O estado do setup continua
pendente de decisão explícita do desenvolvedor.

## decision_0001 — 2026-11-10T10:19:51-03:00 — Governança mínima local

Fonte: o usuário autorizou a criação dos registros após receber o diagnóstico inicial. Criar somente project_status.md, requirements_register.csv, work_items.csv, risk_register.csv, decision_log.md e handoff.md nesta etapa. Registros de testes, aceite, release e operação serão criados quando houver eventos reais. Não iniciar setup, coleta ou implementação nesta autorização.

Consequência: preservar um ponto de retomada sem produzir evidências fictícias nem inferir aceite do produto. Requisitos são `proposed`; os itens futuros permanecem `not_started`, `not_run`, `pending`, `not_released`, `not_started`. Os IDs novos usam snake_case para cumprir a regra de nomenclatura; não havia IDs anteriores a preservar.

## decision_0002 — 2026-11-10T10:19:51-03:00 — Três fases independentes

Fonte: roteiro obrigatório de três fases do pacote e solicitação expressa do usuário para corrigir os trechos remanescentes com duas fases. Separar consulta tributária, nota explicativa e inteligência entre fontes. Corrigir Common P01, Common P06 e a atribuição de responsabilidades em Intelligence P02; manter a antiga entrada do changelog explicitamente identificada como superada e registrar a correção.

Consequência: a fase 2 deve funcionar sem busca da fase 1; a fase 3 integra as duas bases com aceites humanos explícitos. Cada fase possui cinco estados independentes e aceite próprio. O ZIP não foi aberto nem alterado; os arquivos avulsos corrigidos constituem as instruções de trabalho atuais. A correção documental não constitui aceite dos MVPs.

## decision_0003 — 2026-11-10T10:19:51-03:00 — Limites do diagnóstico

Fonte: inventário permitido da raiz, consultas de Git e leitura dos documentos do pacote. A pasta atual não é um repositório; nenhuma implementação foi encontrada na área avaliada. Não acessar áreas protegidas nem inferir configuração de sincronização, ferramentas instaladas, autenticação ou disponibilidade de fontes.

Consequência: registrar valores não verificados como `unknown`; planejar setup e arquitetura antes do MVP. Autenticação somente quando necessária e publicação somente mediante autorização explícita. Nenhuma configuração local ou remota foi alterada nesta sessão.

## decision_0004 — 2026-11-10T10:29:15-03:00 — Setup local autorizado

Fonte: o usuário solicitou a execução do próximo passo, Common P02, em blocos
para permitir retomada. A autorização cobre configurações locais seguras e
reversíveis. Criados projeto RStudio, instruções, exclusões e Git local `main`;
nenhum commit ou remoto criado. Identidade Git não foi inferida do chat.

Dependências limitadas a renv/testthat e seus requisitos transitivos, copiados de
bibliotecas existentes para o projeto. Usar init bare, hydrate com pacotes e
biblioteca explícitos e snapshot explicit; evitar descoberta de dependências na
raiz. Não adicionar here, Arrow, DuckDB, Shiny ou clientes de IA antes de uso real.
Não criar licença, CI, logging de pipeline ou checkpoints sem necessidade/decisão.

Consequência: fundação R testável com cinco verificações aprovadas, mantendo
histórico da falha inicial. Setup continua in_progress e aceite pending devido
às validações gráficas/integrações pendentes. Instalações fora do projeto exigem
autorização específica conforme Common P02; não houve tentativa de elevar
permissões. Avisos de escrita em diretórios auxiliares externos foram registrados,
sem alterar permissões globais. Copilot é suportado nativamente segundo Posit,
mas não foi ativado; nenhum editor adicional foi habilitado.

## decision_0005 — 2026-11-10T10:51:56-03:00 — Preparação Git/GitHub autorizada

Usuário solicitou concluir as configurações Git/GitHub. Instalado CLI oficial
portátil dentro do projeto após aprovação do download e verificação SHA-256.
Nenhuma instalação ou configuração global. Autenticação existente reutilizada,
validada pela rede sem exibir tokens. Nome/e-mail e destino remoto continuam
pendentes de escolha solicitada ao usuário; não foram inferidos do perfil.
Relatórios de execução excluídos do versionamento por conter caminhos locais.
Preparada revisão do primeiro commit com lista explícita e simulação, sem
acesso às áreas protegidas, staging, commit ou publicação. Testes, aceite,
release e operação permanecem separados. Evidência: docs/github_setup.md.

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

## decision_0006 — 2026-11-10T11:02:28-03:00 — Commit e envio privados autorizados

O usuário confirmou nome/e-mail de autoria, amarallr/taxminer privado e
commit/envio. Identidade aplicada localmente; remoto criado e visibilidade
privada confirmada antes e após o envio. Primeiro commit 48cc18973133c3fe749b9e96607fc6c86cb0a3d7
contém somente os 45 arquivos revisados. Hash confirmado no remoto.
Autorização de publicação não implica aceite do setup ou MVP; não foi criada
release. Registros documentais de resultado seguem no mesmo escopo autorizado.
Git/CLI no terminal integrado permanece não confirmado.

## decision_0007 — 2026-11-10T11:09:17-03:00 — Revisão técnica P02 e adiamentos

Usuário autorizou executar o fechamento técnico limitado do P02 antes de
reavaliar saldo para P03. Git/CLI/autenticação passaram no terminal integrado,
com evidência real em reports/execution/github_rstudio_validation.txt.
Claude/Gemini/Copilot e teste de nova sessão Codex no IDE ficam adiados;
não executar outro assistente nem tratá-los como dependências da fundação.
Itens opcionais mantêm estados reais e aceite pendente. Fundação e Git/GitHub
implementados/testados; encerramento P02 depende de aceite humano explícito
sobre limites descritos na revisão. Não houve novo commit, push ou P03.

## decision_0008 — 2026-11-10T11:14:35-03:00 — Copilot solicitado explicitamente

Solicitação do usuário revoga adiamento Copilot. Compatibilidade confirmada;
preferências globais enabled/indexing TRUE lidas sem alteração. A ativação
efetiva e teste dependem da revisão de escopo e indexação, conta/licença e
login humano sob demanda. Claude e Gemini continuam adiados. Não houve
execução de outro assistente, commit, envio ou aceite nesta revisão.

## decision_0009 — 2026-11-10T16:30:00-03:00 — Aceite do setup P02

O usuário confirmou explicitamente o aceite do Common P02. O registro foi
aplicado a work_0001 (fundação) e work_0003 (Git/GitHub); release e operações
continuam separados e pendentes. Este aceite não cobre integrações opcionais,
arquitetura P03 ou qualquer MVP. Nenhum MVP foi iniciado.

## decision_0010 — 2026-11-10T16:50:00-03:00 — Revisão técnica da arquitetura

Revisados os rascunhos de arquitetura, requisitos e dicionário de dados a
pedido do usuário. A separação dos domínios é adequada para planejamento.
Pendências recomendadas antes da implementação: fallback para IDs sem número/
ano oficial, tipagem e proveniência dos identificadores de empresas, calibração
de confiança das relações e limiares quantitativos de qualidade/desempenho.
O usuário ainda precisa revisar e aceitar o requisito req_0003. Nenhum MVP foi
iniciado e nenhum dado foi coletado.

## decision_0011 — 2026-11-10T17:00:00-03:00 — Limiares quantitativos propostos

Para responder ao pedido de executar o passo de critérios, foram incluídos em
`docs/requirements.md` limiares mensuráveis para contabilização de descoberta,
integridade, cobertura de campos, reprodutibilidade, relevância, citações,
latência e precisão de relações. São propostas para revisão do desenvolvedor,
não critérios aceitos nem resultados observados. Não autorizam coleta ou MVP.

Tentativa de iniciar o helper de smoke test pela automação da janela RStudio
não produziu marcador de despacho nem relatório; execução não confirmada. O
smoke test integrado continua pendente; usar a console RStudio manualmente.

## decision_0012 — 2026-11-10T17:07:00-03:00 — Repositório tornado público

O usuário pediu explicitamente tornar público `amarallr/taxminer`. Antes da
alteração, confirmados branch `main`, quatro commits, nenhum caminho
`restricted/` ou `tmp/` rastreado e quatro metadados de autor com endereços
não-noreply. A visibilidade foi alterada com GitHub CLI e confirmada pela API
como `public` / `private=false`. Alterações locais não commitadas não foram
enviadas. Esta autorização não cobre iniciar MVP ou incluir conteúdo protegido.

## decision_0013 — 2026-11-10T17:32:29-03:00 — Exceção `doit` e revisão geral

O desenvolvedor pediu que, ao digitar `doit`, o assistente leia e execute
`tmp/doit.txt`, e autorizou a exceção. `AGENTS.md` e `CLAUDE.md` passaram a
permitir somente a leitura desse arquivo; o desenvolvedor removeu
`Read(./tmp/**)` de `.claude/settings.json`. Risco registrado em `risk_0010`.

A primeira instrução `doit` pediu revisão completa e execução das
recomendações. Executadas apenas correções locais e reversíveis de
consistência em prompts, registros, arquitetura (como proposta) e setup; ver
`review_update_plan.md`. Valores `accepted` normalizados para `approved` e o
aceite de decision_0009 registrado em `acceptance_register.csv`. Licença,
aceite de `req_0003`, instalação, mudança fora do projeto, commit e push
continuam pendentes de decisão humana.

## decision_0014 — 2026-11-10T17:46:38-03:00 — Recomendações da revisão autorizadas

O desenvolvedor autorizou todas as recomendações de `review_update_plan.md` e
respondeu explicitamente: aceita `req_0003`, os limiares de
`docs/requirements.md` e as propostas de arquitetura (`acc_0003`); licença
MIT; não mover o checkout do OneDrive agora; não atualizar o R agora.

Executado: `LICENSE` MIT e campo em `DESCRIPTION`; `doit` passou a ler
`.claude/doit.txt` (ignorado pelo Git) e `Read(./tmp/**)` foi restaurado,
encerrando a exceção de `tmp/` (`risk_0010` mitigado; `tmp/doit.txt` não foi
alterado e pode ser apagado pelo desenvolvedor); criado o diretório
`%LOCALAPPDATA%/R/cache/renv`; e-mail noreply do GitHub configurado apenas no
Git local para commits futuros (`risk_0009` mitigado; histórico não reescrito);
CI mínimo em `.github/workflows/validate_environment.yml`, com permissão
somente leitura, que revoga o adiamento de CI de decision_0004. Refatoração
dos prompts segue adiada para o pacote 1.1, como recomendado.

## decision_0015 — 2026-11-10T17:59:13-03:00 — Correção do CI

A primeira execução do CI falhou: `renv::restore()` acusou falso ciclo de
dependência `magrittr` <-> `testthat` ao compilar `magrittr` 2.0.3 do código
fonte (`test_0022`), também com o repositório CRAN (`test_0023`). O workflow
passou a instalar antes o `magrittr` 2.0.3 travado, a partir do arquivo oficial
do CRAN, e então restaura o lock. Resultado: restauração limpa e 5 verificações
aprovadas em Windows com R 4.5.1, sem o aviso de `testthat` compilado em versão
mais nova (`test_0024`). As tentativas foram feitas no branch temporário
`ci_restore_fix`, integrado ao `main` por fast-forward e removido.

## decision_0016 — 2026-11-10T18:28:17-03:00 — Assistentes concluídos (work_0004–work_0007)

Instrução `doit`: finalizar a implementação de `work_0004` a `work_0007`.
Constatado que a sessão do Claude Code roda no terminal integrado do RStudio;
o smoke test sintético corrigido passou ali para Codex, Claude Code e Gemini
(`test_0027`–`test_0029`), com as falhas intermediárias preservadas. O
Copilot foi confirmado pelo desenvolvedor (login ativo e sugestão aceita com
Tab; `test_0030`). Os quatro itens passam a `implemented`/`passed`; aceite
humano continua `pending`. `risk_0003` e `risk_0008` mitigados.

## decision_0017 — 2026-11-10T18:34:30-03:00 — Aceite dos assistentes e autorização do Collect P01

O desenvolvedor aceitou explicitamente `work_0004`–`work_0007` e `work_0018`
(`acc_0004`–`acc_0008`) e autorizou a execução de Collect P01
(`work_0008`, descoberta de fontes oficiais). A autorização cobre
investigação de fontes, termos de uso e cobertura, sem coleta em massa nem
download de acervo; a coleta da amostra (Collect P02) exige nova autorização.

## decision_0018 — 2026-11-10T18:46:15-03:00 — Resultado do Collect P01

Fontes verificadas com requisições pequenas e espaçadas
(`scripts/probe_sources.R`, `test_0031`). A busca do portal Normas fornece
metadados e ementa de SC, SCI e SD por uma API interna não documentada (totais
informados: SC 15.880; SCI 259; SD 374). O texto integral, servido pelo
visualizador `normasinternet2`, recusou acesso automatizado (HTTP 403); não
houve nova tentativa com outros cabeçalhos. Nenhum conjunto aberto de Soluções
de Consulta foi localizado. CVM DFP/ITR disponíveis em ZIP anual sob ODbL.
Estratégia proposta em `docs/feasibility.md`; Collect P02 aguarda decisões do
desenvolvedor (uso da API de busca, opção de texto integral e amostra).
`risk_0011` aberto.

## decision_0019 — 2026-11-10T18:47:38-03:00 — Panorama no GitHub Pages

A pedido do desenvolvedor, a página de panorama passa a ser publicada no
GitHub Pages (`site/index.html`, workflow `.github/workflows/pages.yml`, com
permissões mínimas `pages: write` e `id-token: write`) e o README aponta para
https://amarallr.github.io/taxminer/. A página contém só dados de gestão já
públicos no repositório; nenhum conteúdo de `restricted/` ou `tmp/`.

## decision_0020 — 2026-11-10T18:55:00-03:00 — Fase 1 suspensa; Fase 2 iniciada

O desenvolvedor suspendeu por enquanto a Fase 1 e pediu o início da Fase 2.
`work_0008` passa a `blocked` (suspensão por decisão do desenvolvedor; as três
decisões de `docs/feasibility.md` continuam em aberto e nada foi descartado).
`work_0011` passa a `in_progress` com Collect P04, etapa 00 (verificação de
fontes). A Fase 2 não depende da Fase 1 (`docs/architecture.md`). A
autorização foi tratada como equivalente à do Collect P01: verificação de
fontes com requisições pequenas, sem download em massa; a coleta da amostra
(etapa 02) exige nova autorização.

## decision_0021 — 2026-11-10T19:10:00-03:00 — Resultado da verificação de fontes da Fase 2

Fontes verificadas com `scripts/probe_financial_sources.R` (`test_0032`). Os
ZIPs de dados abertos da CVM (DFP/ITR, ODbL) trazem índice de entregas e
demonstrativos estruturados, mas não notas explicativas. As notas estão no
pacote de cada entrega no RAD/ENET (`LINK_DOC`): um ZIP com XML que embute os
PDFs anexados pela companhia, entre eles as demonstrações com notas, com
camada de texto. Hashes estáveis por membro do pacote, não pelo ZIP. O RAD não
tem robots.txt nem licença declarada; o PDF gerado pelo ENET vem preenchido
com zeros até 16 MiB. Detalhes em `docs/data_sources.md` e
`config/financial_disclosure_sources.yml`; amostra proposta de até 20 entregas
aguarda autorização. `risk_0012` aberto.

## decision_0022 — 2026-11-10T20:00:00-03:00 — Coleta completa das DFP da CVM

O desenvolvedor aceitou a amostra, o uso do RAD/ENET e o commit, e pediu para
baixar tudo o que estiver disponível. Com o catálogo completo (49.908 pacotes,
cerca de 450 GB) maior que o espaço livre (163 GB), o desenvolvedor escolheu
baixar primeiro todas as DFP de 2010 a 2026 (14.015 pacotes, cerca de 110 GB),
das mais recentes para as mais antigas, em `C:\TaxMinerData`, fora do OneDrive
e do repositório. ITR fica para quando houver mais armazenamento. Pipeline em
`src/collect/` e `scripts/collect_financial_reports.R`, retomável, com
manifesto e SHA-256 por membro (`test_0033`, `test_0034`). A coleta roda em
processo próprio na estação de trabalho. `risk_0013` aberto.

## decision_0023 — 2026-11-10T20:56:40-03:00 — Gate 01 do Common P07: novas fontes de dados

O desenvolvedor aceitou as seis recomendações do gate 01
(`docs/integration/new_data_sources_gap_analysis.md`) e autorizou o commit da etapa 00.
A incorporação passa a ser tratada só como **adição de novas fontes de dados ao TaxMiner**,
sem citar o nome do projeto de origem. O prompt foi salvo como
`prompts/common_p07_new_data_sources.txt`.

1. **Escopo.**
   - Agora: opção A, rotinas comuns de confiabilidade em `src/common/`, como base para as
     novas fontes.
   - Depois que a coleta da Fase 2 estiver estável: opção B, família opcional
     `investment_fund_reports` (FIDC/FII), fora das três fases do MVP.
2. **Licença:** nenhum código é copiado. A implementação será refeita a partir dos
   requisitos.
3. **Histórico:** sem importar o histórico Git; a proveniência fica registrada por SHA da
   implementação de referência (`595991b`).
4. **Dependências:** nenhum pacote novo; as rotinas usam só R base.
5. **Nomes e IDs:** aprovados os mapeamentos das seções c e d.
6. **Momento:** `src/collect/` não muda enquanto a coleta das DFP estiver rodando.

Por ora, nada além deste registro: a etapa 02 não começou.

## decision_0024 — 2026-11-10T21:24:00-03:00 — Fundos de investimento como nova família de fontes

O desenvolvedor decidiu que os relatórios de fundos de investimento da CVM entram no TaxMiner
como fonte de dados, no mesmo nível das Soluções de Consulta e das notas explicativas.

**Escopo da nova família.**

- **Nome técnico:** família `investment_fund_reports`.
- **Subfamílias:** `fii`, `fidc`, `fip` e `fiagro`.
- **Esquema e governança próprios:** esquema, proveniência, cobertura e qualidade são
  independentes das demais famílias.
- **Nova fase do MVP:** a Fase 4 tem aceite humano próprio e não depende das Fases 1 a 3.
  - Requisitos: `req_0012` (coleta), `req_0013` (consolidação) e `req_0014` (busca).
  - Work items: `work_0020` a `work_0023`.
  - `req_0011` passa a valer para quatro fases.

**O que não muda.**

- A Fase 3 continua restrita às duas bases das Fases 1 e 2. Estender as relações entre fontes
  aos fundos exigirá decisão própria.
- `decision_0023` continua valendo para as rotinas comuns, com estes ajustes:
  - item 1: a família de fundos deixa de ser opcional e fora do MVP e passa a ser a Fase 4.
    O momento de início continua o mesmo: só depois que a coleta da Fase 2 estiver estável,
    com nova autorização;
  - item 5: os IDs `req_0012`–`req_0014` passam para os requisitos dos fundos. Os requisitos
    das rotinas comuns receberão os próximos IDs livres na etapa 02.

**Fontes.** Listagens da CVM verificadas em 2026-11-10T21:24-03:00; os detalhes estão em
`docs/data_sources.md` e `config/investment_fund_report_sources.yml`.

**Limites.** Nenhuma coleta, código ou dependência foi autorizado por esta decisão.

## decision_0025 — 2026-11-10T21:35:26-03:00 — Fases reorganizadas: coleta (Fase 1) e inteligência cruzada (Fase 2)

O desenvolvedor reorganizou as fases do MVP em duas.

- **Fase 1 — Coleta, estruturação e pesquisa de dados.** Tem três subfases independentes,
  cada uma com aceite humano próprio e sem depender das outras:
  - 1.1 Soluções de Consulta;
  - 1.2 Notas explicativas;
  - 1.3 Fundos de investimento (FII, FIDC, FIP, FIAGRO).
- **Fase 2 — Inteligência cruzada.** Relações entre as bases, sempre como hipóteses com
  evidências e revisão humana, depois que as bases forem aceitas.
  - Uma relação só pode usar bases com aceite humano explícito.
  - Ao contrário da antiga Fase 3, a Fase 2 também alcança os fundos.

| Antes | Agora |
|---|---|
| Fase 1 — Soluções de Consulta | Fase 1.1 |
| Fase 2 — Notas explicativas | Fase 1.2 |
| Fase 4 — Fundos de investimento (`decision_0024`) | Fase 1.3 |
| Fase 3 — Inteligência cruzada | Fase 2 |

**Registros.** Os IDs não mudam; só títulos e textos foram ajustados.

- Os marcos de aceite passam a ser:
  - `work_0015` (1.1), `work_0016` (1.2) e `work_0023` (1.3);
  - `work_0017` (Fase 2).
- `work_0014` passa a depender dos três aceites da Fase 1.
- `req_0010` e `req_0011` foram atualizados.

**O que não muda.** Os registros anteriores (`decision_0001`–`decision_0024`, histórico de
status e changelogs) mantêm a numeração da época. A suspensão da antiga Fase 1
(`decision_0020`) vale agora para a subfase 1.1. A coleta da antiga Fase 2 vale para a
subfase 1.2.

## decision_0026 — 2026-11-10T23:00:48-03:00 — Dependências da extração das notas declaradas

O desenvolvedor autorizou declarar no `DESCRIPTION` as dependências usadas pela extração das
notas (Fase 1.2, `work_0012`):

| Pacote | Versão | Uso |
|---|---|---|
| `pdftools` | 3.9.0 | texto do PDF |
| `xml2` | 1.5.1 | XML do pacote ENET |
| `base64enc` | 0.1-6 | anexo PDF em base64 |

Detalhes:

- **`renv.lock`:** os pacotes e suas dependências (`qpdf`, `Rcpp`, `curl`, `askpass`, `sys`)
  foram registrados por snapshot explícito, sem instalação nova. As cópias vieram da
  biblioteca local já existente, pelo `scripts/setup_environment.R`.
- **`scripts/setup_environment.R`:** agora lê a lista de pacotes do campo `Imports` do
  `DESCRIPTION`.
- **`arrow`:** continua não declarado. Entra quando o primeiro código de Parquet for escrito,
  conforme `docs/architecture.md`.

## decision_0027 — 2026-11-10T23:23:55-03:00 — Notas consolidadas em Parquet

O desenvolvedor pediu para seguir com o Parquet das notas (Fase 1.2, `work_0012`). Ficou
decidido:

- **`arrow` declarado.** `arrow` 25.0.1 entra no `DESCRIPTION`, como previa a
  `decision_0026`. O `renv.lock` recebeu o pacote e suas dependências (`assertthat`, `bit`,
  `bit64`, `cpp11`, `purrr`, `tidyselect`, `vctrs`) por snapshot explícito da biblioteca local,
  sem download.
- **Uma parte por pacote.** Cada pacote baixado gera `financial_reports/part-{id}.parquet` e,
  se houver notas, `financial_notes/part-{id}.parquet` (zstd), com esquema fixo. A gravação
  passa por arquivo temporário vizinho, releitura e troca com rollback.
- **Rodada incremental.** O índice `extraction_index.rds` (gravado com
  `write_validated_atomic`) guarda o SHA-256 do pacote e a assinatura da extração. Pacotes
  iguais são pulados; mudança no pacote ou na lógica da extração força o reprocessamento.
  Por isso a consolidação pode rodar junto com a coleta.
- **Fora do repositório.** Os dados ficam em `<TAXMINER_DATA_DIR>/processed/financial_disclosures/`;
  o script recusa diretórios dentro do OneDrive.
- **Defeito do catálogo contornado, sem mexer na coleta.** O catálogo da coleta tem nomes de
  companhias cortados no primeiro caractere acentuado (`risk_0016`). A consolidação repara as
  linhas e lê `company_name` dos ZIPs de índice da CVM com decodificação Latin-1. A correção
  em `src/collect/` fica para depois do fim da coleta das DFP.
- **CI.** O workflow pré-instala `curl`, `qpdf` e `pdftools` nas versões travadas, porque o
  `renv::restore` acusa um ciclo falso entre eles (mesmo caso do `magrittr`).

## decision_0028 — 2026-11-11T00:18:31-03:00 — Dados locais organizados por fonte

O desenvolvedor pediu: "organize a pasta C:\TaxMinerData de acordo com a fonte dos dados".
Ficou decidido:

- **Uma pasta por família** sob `TAXMINER_DATA_DIR`: `tax_consultation_decisions/`,
  `financial_disclosures/` e `investment_fund_reports/`. O layout está em
  `src/common/data_layout.R` e em `docs/architecture.md`.
- **Movidos agora** (`scripts/organize_data_dir.R`): os arquivos brutos e os manifestos dos
  fundos, com `raw_path` relativo à pasta da família, e a saída Parquet e o log da extração
  das notas.
- **Coleta das DFP preservada.** O catálogo, o manifesto, o índice, os pacotes, a quarentena
  e os logs da coleta em execução ficam onde estão até ela terminar. O passo `dfp` do script
  recusa rodar enquanto a coleta estiver ativa. Até a migração, o código lê as DFP no local
  antigo, e uma coleta retomada não baixa nada de novo.
- **Nada é apagado.** O script nunca sobrescreve um destino existente; só remove pastas
  antigas vazias.

## decision_0029 — 2026-11-11T00:18:31-03:00 — Fase 1.3 iniciada: coleta dos fundos

O desenvolvedor disse: "pode iniciar também a fase 1.3". Depois disse: "vc tem autorização
para continuar e executar as próximas etapas necessárias para a implementação do projeto".
Isso foi lido como autorização para as etapas 00 a 03 da Collect P05, incluindo a amostra
pública e o backfill histórico dos arquivos da CVM. Não foi lido como autorização para
commit ou push, que o `AGENTS.md` exige explícitos.

- **Etapa 00:** `robots.txt`, licença ODbL nas páginas dos conjuntos e dicionários `META/`
  verificados (`docs/data_sources.md`).
- **Etapas 01 e 02:** `src/collect/discover_fund_reports.R` e
  `src/collect/download_fund_reports.R`, com 10 s entre requisições, parada em 403/429,
  verificação de ZIP e CSV e armazenamento imutável endereçado por conteúdo. São arquivos
  novos; o código da coleta das DFP não foi alterado.
- **Etapa 03:** backfill histórico de todos os períodos listados, fora o `DFIN`. Cada nova
  rodada confere de novo o período mais recente de cada conjunto.
- **Fora do escopo:** o `DFIN` do FII e as outras pastas de fundos do portal.

## decision_0030 — 2026-11-11T07:44:45-03:00 — Busca dos fundos e primeira área do Shiny

O desenvolvedor disse: "sim, pode fazer commit e push e seguir com a busca" e depois "pode
fechar a busca dos fundos e fazer commit e push". Ficou decidido:

- **Lógica em `src/intelligence/search_fund_reports.R`**, só com R base e `arrow`; nenhum LLM.
  Um diretório de fundos (uma entrada por fundo, nome e administrador como publicados) vem das
  tabelas que trazem esses campos: `inf_mensal_fii_geral`, `inf_mensal_fidc_tab_I`,
  `inf_trimestral_fip`, `inf_quadrimestral_fip` e `inf_mensal_fiagro`. Fica em cache em
  `processed/search/` e é refeito quando essas partes ou o código mudam.
- **Filtros:** família, CNPJ (prefixo, sem pontuação), nome e administrador (sem caixa nem
  acento; administrador também pelo CNPJ) e período por sobreposição de intervalos.
- **Linhas do informe** com valores originais e citação: dataset, arquivo, linha, hash do
  arquivo e link oficial do manifesto.
- **Interface em `prototype/`** (arquitetura, item 5), só de apresentação, uma área por
  família habilitada só quando os dados existem. `shiny` declarado no `DESCRIPTION` e copiado
  das bibliotecas já instaladas pelo `scripts/setup_environment.R` (sem download).
- **Limitação:** o FIP não publica o administrador.

## decision_0031 — 2026-11-11T07:44:45-03:00 — Python autorizado para o processamento documental

Perguntado se autorizava "instalar Python 3.12 só para o usuário, com .venv no projeto e
MarkItDown fixado", o desenvolvedor respondeu "SIM!". Escopo: Python 3.12 instalado só para o
usuário, ambiente `.venv` dentro do projeto e `markitdown` 0.1.9 fixado com hashes, conforme
`docs/integration/hybrid_document_processing_plan.md` (`work_0026`). Plugins, OCR e
conversores do Azure ficam desligados. Não autoriza chamar LLM nem enviar documentos a
serviços externos; o provedor ainda será decidido.

## decision_0032 — 2026-11-11T08:04:21-03:00 — Horários dos registros corrigidos

O desenvolvedor autorizou: "sim, pode atualizar as notas e corrigir os horários". Vários
registros de 10 e 11/11 tinham horários estimados, à frente do relógio (até 4 horas). Regra
aplicada: um registro não pode ser posterior ao commit que o introduziu. Cada horário
posterior foi trocado pelo horário desse commit (`git log -S`), que é um limite superior
verificável; 46 ocorrências em `data_sources.md`, `decision_log.md`, `handoff.md`,
`project_status.md`, `requirements_register.csv`, `test_register.csv` e `work_items.csv`.
O `test_0048` recebeu o horário real de término do CI (07:36:18). Daqui em diante os
horários vêm do relógio do sistema no momento do registro.

## decision_0033 — 2026-11-11T08:04:21-03:00 — Leiaute da interface

Pedidos do desenvolvedor: autocomplete nos filtros, "estilo de pagina padrão profissional,
semelhante aos utilizados pela mackinsey", leiaute melhor e "leiaute paisagem". Ficou
decidido: estilo próprio sóbrio (azul-marinho, títulos serifados, linhas finas), sem nome,
marca ou identidade de terceiros; fontes do sistema, para funcionar sem internet; leiaute
mestre-detalhe em telas de 1200 px ou mais. Sem pacote novo: o `DT` foi descartado porque
traria `rmarkdown`, `knitr` e `xfun` atrás do CRAN, com risco para o CI; a lista usa tabela
HTML própria com clique por JavaScript.

## decision_0034 — 2026-11-11T08:26:24-03:00 — Painel analítico dos fundos

Pedido do desenvolvedor: um app "condizente" com um especialista em engenharia de dados, BI,
dashboards, comunicação visual e fundos, porque "o app ainda está muito simples". Ficou
decidido:

- Tabela derivada `processed/metrics/fund_period_metrics.parquet` (`src/data/build_fund_metrics.R`):
  uma linha por fundo e período com patrimônio líquido, ativo e cotistas convertidos dos
  valores publicados, citação da linha de origem e reapresentações resolvidas pela maior
  versão. Número inválido vira vazio, nunca zero. Refeita só quando a consolidação muda.
- Regras analíticas (`src/intelligence/fund_analytics.R`, sem LLM): períodos futuros
  descartados; último mês completo = fundos que reportaram ≥ 90% da mediana dos seis meses
  anteriores; totais do mercado contam cada CNPJ uma vez por mês; variação contra o mesmo
  mês do ano anterior; o saldo do FIP (informe trimestral/quadrimestral) vale até o próximo
  informe, no máximo três meses; HHI sobre participações em %; administradores agrupados
  pelo CNPJ. Nomes de fundo no campo de administrador (informes FIAGRO) são trocados pelo
  nome mais frequente do mesmo CNPJ.
- Interface: abas Panorama, Fundos (com aba Perfil), Administradores, Cobertura e Sobre.
  Gráficos em SVG próprios, sem pacote novo; cores categóricas fixas por família, um eixo
  por gráfico, eixo de valor a partir de zero, dica ao passar o mouse, variação com seta e
  texto (nunca só cor). Rentabilidade e dividendos ficam fora até a unidade dos campos ser
  confirmada.

## decision_0035 — 2026-11-11T09:02:13-03:00 — Publicação do painel e Panorama em uma tela

Pedidos do desenvolvedor: "quero que publique também o app, e adicione um link no readme e na
pagina do projeto"; "a página inicial do app (panorama) não pode apresentar barra de rolagem";
nos gráficos por família, "uma nova linha tracejada" com o número de fundos "no eixo Y à
direita". Ficou decidido:

- Publicação estática no GitHub Pages já existente (`site/app/`, mesmo `pages.yml`), gerada por
  `scripts/export_static_dashboard.R`: Panorama, Administradores (40 maiores com detalhe) e
  Sobre, só com dados públicos agregados da CVM (ODbL), sem servidor, sem conta nova e sem
  pacote novo. A busca nos informes de cada fundo fica no app local. A página informa que não é
  serviço oficial da Receita Federal nem da CVM.
- Panorama em uma tela paisagem (grade de altura fixa, rankings com os 6 maiores, metodologia
  na aba Sobre); conferido sem barras de rolagem em 1366×768, 1440×900 e 1920×1080.
- Eixo duplo por pedido explícito: patrimônio em linha cheia na cor da família (eixo esquerdo)
  e número de fundos em linha tracejada neutra (eixo direito, marcas alinhadas à grade), com
  legenda em cada painel.

## decision_0036 — 2026-11-11T10:08:45-03:00 — Resolução de entidades e denominações

Pedido do desenvolvedor (`.claude/Tratamento de nomes.txt`): um serviço central de Entity
Resolution, determinístico e auditável, em que "identidade cadastral, denominação histórica e
representação textual" fiquem separadas, e em que "ao selecionar qualquer uma das duas opções, o
sistema deve recuperar todos os registros associados ao CNPJ". Ficou decidido (`work_0028`,
`docs/entity_resolution.md`):

- Catálogos em `processed/master/` (entidades, denominações, histórico, revisão, homônimos e
  qualidade), construídos a partir do diretório de fundos e guardados em cache por assinatura;
  os dados RAW e as tabelas consolidadas não mudam.
- Identidade pelo CNPJ canônico (`normalize_cnpj`, já existente, única implementação); CNPJ
  inválido no dado publicado vira entidade própria sinalizada, sem correção por palpite. Fundo e
  administrador são tipos distintos mesmo com o mesmo CNPJ.
- Equivalência só por regras do dicionário versionado `config/entity_name_rules.csv` (dobra de
  caixa, acento e pontuação, siglas regulatórias, ordem das palavras). Nomes parecidos mas não
  equivalentes (ex.: sufixo RL, erro de grafia) ficam separados e entram na fila de revisão.
  Nenhuma IA decide equivalência.
- Filtros com uma opção por denominação (`CNPJ formatado — nome`); o valor é resolvido para a
  entidade antes da consulta; lista com uma linha por fundo e família; aba Denominações como
  consulta temporal separada. Datas são de observação nos informes, nunca de vigência jurídica.
- Ordem das abas pedida pelo desenvolvedor: Panorama, Administradores, Fundos e uma aba por
  tipo (FIDC, FII, FIP, FIAGRO), todas sobre os mesmos dados carregados uma vez.
- Pendências: tela de decisão da fila de revisão; uso nas demonstrações financeiras (Fase 1.2)
  quando forem consolidadas; granularidade fundo/classe da Resolução CVM 175 limitada ao CNPJ
  publicado.

## decision_0037 — 2026-11-11 — Fichas dos fundos: aba própria e painel publicado

Pedido do desenvolvedor: Ficha e Série completa no painel publicado e uma aba FICHA, entre
FIAGRO e Cobertura e qualidade, com as fichas e a série completa.

- App local: aba Ficha (`prototype/fund_record_module.R`) com busca de qualquer fundo (CNPJ ou
  nome, maiores primeiro), tabela e período; Ficha e Série completa na largura toda, com as
  mesmas funções das abas de fundos (`report_card`, `wide_table`, cache `fund_rows_cache`).
- Painel publicado: Ficha e Série completa nas abas de fundos para as tabelas principais de cada
  tipo (FIDC tab_I; FII geral, complemento e ativo/passivo mensais; FIP trimestral e
  quadrimestral; FIAGRO mensal). Um arquivo JSON por fundo (`site/app/data/fichas/`), baixado
  só quando o fundo é aberto; valores e rótulos gerados em R pelas funções do app, para que as
  duas versões mostrem o mesmo texto; cada coluna cita arquivo, linha e SHA-256 da CVM.
- Alternativa descartada: carregar todos os informes na abertura da página (513 MB no painel
  publicado; ~520 MB de Parquet em memória no app, que já sofre falta de memória).
- Limites: as demais tabelas seguem só no app local; a aba Ficha ainda não está no painel
  publicado.

## decision_0038 — 2026-11-11 — Cedentes dos FIDC com CPF completo

Pedido do desenvolvedor: aba CEDENTES após FIDC com os cedentes dos FIDC. Decisão do
desenvolvedor (pendência 3 de `docs/bi_platform_plan.md`): mostrar o CPF dos cedentes pessoa
física completo, como publicado pela CVM (dado público), no app e no painel publicado.

- Fonte: Tabela I do informe mensal do FIDC, 9 maiores cedentes por bloco (I.2.a.12 e I.2.b.12
  desde nov/2019; I.2.b.1 até out/2019), com CPF ou CNPJ e percentual; o informe não traz o nome
  (nome mostrado só quando o CNPJ está no catálogo de entidades).
- Regras: posições preenchidas com zeros não são cedentes; fundo informado duas vezes na mesma
  competência fica com a última linha publicada; percentuais como publicados, inclusive acima de
  100% (inconsistências marcadas, não corrigidas).
- Um único pacote JSON por competência (`write_cedente_data`) e um único código de exibição
  (`prototype/www/cedentes.js`) para o app (cache em `processed/metrics/cedentes`, refeito quando a
  Tabela I ou o catálogo mudam) e o painel publicado (`site/app/data/cedentes/`, 7,2 MB).
- Também nesta data: filtro de FIP por `ENTID_INVEST`, % na lista de fundos dos Administradores e
  valores negativos em vermelho em todas as telas.
