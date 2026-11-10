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
