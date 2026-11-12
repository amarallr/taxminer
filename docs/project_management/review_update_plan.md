# Revisão do projeto e plano de atualização — 2026-11-10

**Status:** executado (revisão de 2026-11-10) ·
**Última atualização:** 2026-11-10 ·
**Documentos relacionados:** [Retomada](handoff.md) ·
[Registro de decisões](decision_log.md) ·
[Riscos](risk_register.csv)

Pedido: instrução `doit` do desenvolvedor — revisar todo o projeto (prompts,
arquitetura, setup, requisitos), preparar um plano de atualização e executar
as recomendações. Revisão feita por Claude Code. Nenhum aceite humano foi
inferido; nada foi commitado, enviado ou instalado.

## Escopo lido

Registros de gestão (`project_status.md`, `handoff.md`, todos os CSVs,
`decision_log.md`), `docs/architecture.md`, `docs/requirements.md`,
`docs/data_dictionary.md`, todos os scripts, o teste, arquivos de configuração
da raiz e os 16 prompts. Leitura integral: Common P01, P03 e P06, além de
Collect P04. Nos demais prompts, conferi estrutura e seções repetidas (hash
por seção) e fiz buscas direcionadas. Não foram abertos: o ZIP histórico,
`restricted/` e `tmp/` (exceto `tmp/doit.txt`).

## Achados

| #   | Área        | Achado                                                                                                                                                                                 | Severidade               |
| --- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| 1   | Prompts     | Títulos internos de Common P02–P05 diziam P01–P04, divergindo do nome do arquivo.                                                                                                      | média                    |
| 2   | Prompts     | 10 prompts descreviam o TaxMiner apenas como Soluções de Consulta (texto anterior à fonte dupla).                                                                                      | média                    |
| 3   | Prompts     | Nenhum prompt era dono da busca de notas financeiras da Fase 2 no README; `collect_p03` e `intelligence_p01` não estavam em nenhuma fase.                                              | alta                     |
| 4   | Prompts     | Nomes em português (`data/raw/normas/`, entidades `ato`, `referencia_normativa`…) contrariam a regra en-US.                                                                            | baixa                    |
| 5   | Prompts     | Common P01 prescrevia IDs `REQ-0001`, mas os registros usam `req_0001`.                                                                                                                | baixa                    |
| 6   | Prompts     | Collect P04 afirmava que a coleta de Soluções de Consulta já existia.                                                                                                                  | baixa                    |
| 7   | Prompts     | Rótulos de versão concorrentes (V5, 1.0, 3.0) sem explicação; CHANGELOG com entrada antes do título.                                                                                   | baixa                    |
| 8   | Prompts     | Cabeçalho de 73 linhas idêntico em 10 prompts; roteiro final idêntico em 14; Common P02 tem 914 linhas com modelo histórico embutido.                                                  | média (manutenção)       |
| 9   | Governança  | `work_items.csv` usava `accepted`, valor fora do vocabulário de Common P01 (`approved`).                                                                                               | média                    |
| 10  | Governança  | Aceite real (decision_0009) sem `acceptance_register.csv`.                                                                                                                             | média                    |
| 11  | Governança  | `handoff.md` com 430 linhas duplicando `project_status.md`; retomada lenta.                                                                                                            | média                    |
| 12  | Governança  | `req_0009` não apontava Intelligence P02.                                                                                                                                              | baixa                    |
| 13  | Arquitetura | Três pendências da revisão anterior sem proposta concreta (fallback de IDs, identificadores de empresa, calibração de confiança); motor de armazenamento e local do Shiny indefinidos. | alta (bloqueia req_0003) |
| 14  | Setup       | Destino `RENV_PATHS_ROOT` (`%LOCALAPPDATA%/R/cache/renv`) continua inexistente.                                                                                                        | média                    |
| 15  | Setup       | R 4.5.1 com `testthat` compilado em R 4.5.3 (aviso persistente).                                                                                                                       | média                    |
| 16  | Setup       | Sem `.gitattributes`: a normalização de fim de linha dependia da configuração de cada máquina. Os avisos LF→CRLF continuam porque vêm do `core.autocrlf` local; são inofensivos.       | baixa                    |
| 17  | Setup       | `inspect_environment.R` verificava pacotes não declarados (`here`, `jsonlite`).                                                                                                        | baixa                    |
| 18  | Repositório | Repositório público sem licença: legalmente “todos os direitos reservados”.                                                                                                            | alta (decisão humana)    |
| 19  | Segurança   | Exceção `doit` e remoção do bloqueio `Read(./tmp/**)`: qualquer sessão Claude Code pode ler todo `tmp/`, e as instruções de `tmp/doit.txt` não passam por revisão no repositório.      | alta                     |
| 20  | Repositório | Projeto sob OneDrive com exclusões de sincronização não verificadas (risco já registrado).                                                                                             | alta (decisão humana)    |

## Plano e execução

### Executado nesta sessão

- Prompts: achados 1, 2, 4, 5, 6 e 7 corrigidos; achado 3 resolvido no README
  (Intelligence P02 → Fase 2; Collect P03 e Intelligence P01 → pós-MVP).
  Entrada registrada em `prompts/CHANGELOG.md`.
- Governança: `accepted` → `approved`; criado `acceptance_register.csv`
  (acc_0001, acc_0002); `req_0009` corrigido; `risk_0010` criado; `handoff.md`
  reescrito de forma curta, com o histórico integral preservado em
  `handoff_history.md`; `decision_0013` e checkpoint em `project_status.md`.
- Arquitetura: seção “Proposed resolutions” em `docs/architecture.md`
  (fallback de ID, identificadores de empresa, nível de evidência das relações,
  armazenamento Parquet + DuckDB proposto, Shiny em `prototype/`). Continua
  como proposta.
- Setup: `.gitattributes` criado; `inspect_environment.R` alinhado ao
  `DESCRIPTION`. Validação repetida (ver `test_0020`).

### Não executado — exige decisão ou autorização do desenvolvedor

| Prioridade | Ação                                                                                                          | Motivo de não executar                                                                                                                              |
| ---------: | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1          | Revisar e aceitar ou rejeitar `req_0003`, os limiares de `docs/requirements.md` e as propostas de arquitetura | Gate D: aceite só humano.                                                                                                                           |
| 2          | Escolher uma licença (por exemplo MIT para código; dados seguem os termos das fontes)                         | Decisão de titularidade.                                                                                                                            |
| 3          | Mover `doit.txt` para fora de `tmp/` e restaurar `Read(./tmp/**)`                                             | Reverte uma permissão que o próprio desenvolvedor alterou.                                                                                          |
| 4          | Commit e push destas mudanças                                                                                 | AGENTS.md exige autorização explícita.                                                                                                              |
| 5          | Atualizar R para 4.5.3+ (ou reinstalar `testthat` compilado para 4.5.1)                                       | Instalação fora do projeto.                                                                                                                         |
| 6          | Criar `%LOCALAPPDATA%/R/cache/renv` ou remover `RENV_PATHS_ROOT` do `.Rprofile`/setup                         | Mudança de estado fora do projeto; escolher uma das opções.                                                                                         |
| 7          | Mover o checkout para fora do OneDrive                                                                        | Migração por allowlist, com verificação humana.                                                                                                     |
| 8          | Extrair o cabeçalho e o roteiro repetidos para um arquivo comum e enxugar Common P02                          | Refatoração grande: os prompts hoje são autocontidos para colar em qualquer assistente. Recomendo fazer junto com a próxima versão do pacote (1.1). |
| 9          | CI mínimo no GitHub Actions rodando `validate_environment.R`                                                  | decision_0004 adiou CI até haver código real.                                                                                                       |
| 10         | Usar endereço noreply em commits futuros (risk_0009)                                                          | Escolha de identidade.                                                                                                                              |

## Próxima etapa técnica recomendada

Depois do item 1, iniciar a Fase 1 com `collect_p01_official_source_discovery.txt`:
verificar fontes públicas e termos de uso das Soluções de Consulta, sem baixar
documentos em massa, e registrar o resultado antes da coleta da amostra.

## Execução após autorização — 2026-11-10T17:46:38-03:00

O desenvolvedor autorizou todas as recomendações (`decision_0014`).

| Prioridade | Resultado                                                                                                               |
| ---------: | ----------------------------------------------------------------------------------------------------------------------- |
| 1          | Aceito: `req_0003`, limiares e arquitetura (`acc_0003`).                                                                |
| 2          | Licença MIT adicionada.                                                                                                 |
| 3          | `doit` lê `.claude/doit.txt`; `Read(./tmp/**)` restaurado. `tmp/doit.txt` ficou intacto: o desenvolvedor pode apagá-lo. |
| 4          | Commit e push executados.                                                                                               |
| 5          | Não executado por escolha do desenvolvedor (R continua 4.5.1).                                                          |
| 6          | Diretório `%LOCALAPPDATA%/R/cache/renv` criado.                                                                         |
| 7          | Não executado por escolha do desenvolvedor (checkout continua no OneDrive).                                             |
| 8          | Mantido adiado para o pacote 1.1, conforme a própria recomendação.                                                      |
| 9          | CI mínimo criado; resultado da primeira execução em `project_status.md`.                                                |
| 10         | E-mail noreply configurado no Git local; histórico não reescrito.                                                       |
