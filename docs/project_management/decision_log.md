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

## decision_0015 — 2026-11-10T18:00:00-03:00 — Correção do CI

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

## decision_0023 — 2026-11-10T21:50:00-03:00 — Gate 01 do Common P07: novas fontes de dados

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

## decision_0024 — 2026-11-10T22:30:00-03:00 — Fundos de investimento como nova família de fontes

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

**Fontes.** Listagens da CVM verificadas em 2026-11-10T22:20-03:00; os detalhes estão em
`docs/data_sources.md` e `config/investment_fund_report_sources.yml`.

**Limites.** Nenhuma coleta, código ou dependência foi autorizado por esta decisão.

## decision_0025 — 2026-11-10T23:00:00-03:00 — Fases reorganizadas: coleta (Fase 1) e inteligência cruzada (Fase 2)

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
