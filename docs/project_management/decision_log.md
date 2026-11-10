# Registro de decisões

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
