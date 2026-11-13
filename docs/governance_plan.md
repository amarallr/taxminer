# TaxMiner Governance — Fase 01 (Discovery)

**Status:** aprovado pelo desenvolvedor em 2026-11-12 (`acc_0009`, `decision_0044`): arquitetura, plano, resoluções C1–C7 e melhorias P1–P7 (prompt 1.1); Fase 02 autorizada ·
**Última atualização:** 2026-11-12 ·
**Origem:** `.claude/governance.txt` (prompt mestre do desenvolvedor, versão 1.0), cópia versionada em
`prompts/common_p08_governance_master.txt` ·
**Documentos relacionados:** [Common P01](../prompts/common_p01_lifecycle_management.txt) ·
[Estado do projeto](project_management/project_status.md) ·
[Registro de decisões](project_management/decision_log.md)

Este documento é o entregável da Fase 01: diagnóstico da arquitetura e da governança atuais,
catálogo inicial de requisitos, arquitetura proposta, plano das oito fases, riscos, estimativas,
primeiro checkpoint e relatório de melhoria do prompt. Não houve implementação: nenhum código,
módulo, hook ou tela foi criado. Tudo o que é proposta está marcado como tal.

## 1. Escopo da inspeção

Lidos: `AGENTS.md`, `CLAUDE.md`, `prompts/README.md`, `prompts/common_p01_lifecycle_management.txt`,
`prompts/CHANGELOG.md`, `docs/project_management/` (cabeçalhos e contagens dos CSVs, `handoff.md`,
`review_update_plan.md`, títulos de `decision_log.md` e `docs/architecture.md`), `.claude/settings.json`,
lista de arquivos versionados (`git ls-files`, primeiro nível), tags e contagem de commits.
Não lidos: `.restricted/`, `.tmp/` (nem nomes nem metadados), conteúdo de transcrições de assistentes,
arquivos de credenciais. Não foram executados testes nesta fase.

## 2. Architecture Assessment

### 2.1 Tecnologias e estrutura

| Item | Observado |
| --- | --- |
| Linguagem principal | R 4.5.1 (`DESCRIPTION`, `renv.lock` com snapshot explícito) |
| Interface | Shiny + bslib local (`prototype/`), porta 8765; painel estático publicado (`site/app/`, GitHub Pages) |
| Dados | Parquet (arrow) em `C:\TaxMinerData`, fora do repositório (`decision_0028`) |
| Módulos | `src/common/` (5 arquivos), `src/collect/` (7), `src/data/` (8), `src/intelligence/` (4) |
| Testes | `tests/testthat/` (testthat e dois testes Node); 110 testes R na última rodada (2026-11-12) |
| CI | `.github/workflows/validate_environment.yml` e `pages.yml` |
| Prompts | 19 prompts CO-STAR planos em `prompts/` (`group_pNN_objective.txt`) |
| Assistentes | Claude Code, Codex, Gemini CLI e Copilot aprovados como ferramentas (`acc_0004`–`acc_0007`) |
| Repositório | 47 commits (2026-11-10 a 2026-11-12); tags `v1.0` e `v1.0.2` |

### 2.2 Governança existente (Common P01)

O TaxMiner já tem uma governança em arquivos, definida por Common P01, que cobre boa parte do que o
prompt mestre pede. Ela é a base a reaproveitar, não a substituir.

| Registro (`docs/project_management/`) | Conteúdo atual (contado em 2026-11-12) |
| --- | --- |
| `requirements_register.csv` | 20 requisitos (`req_0001`–`req_0020`): 1 `accepted`, 19 `proposed` |
| `work_items.csv` | 31 itens com 5 dimensões de status: implementação (18 `implemented`, 3 `in_progress`, 9 `not_started`, 1 `blocked`); teste (19 `passed`, 10 `not_run`, 2 `not_applicable`); aceite (8 `approved`, 23 `pending`); release (31 `not_released`); operação (28 `not_started`, 3 `not_applicable`) |
| `test_register.csv` | 56 execuções (46 `passed`, 10 `failed`, falhas preservadas) |
| `acceptance_register.csv` | 8 aceites humanos (`acc_0001`–`acc_0008`) |
| `risk_register.csv` | 17 riscos (11 `open`, 5 `mitigated`, 1 `accepted`) |
| `decision_log.md` | 42 decisões (`decision_0001`–`decision_0042`) |
| `project_status.md`, `handoff.md`, `handoff_history.md` | painel textual, retomada e histórico |

Ausentes, embora previstos por Common P01 "quando justificados": `release_register.csv` e
`operations_register.csv`.

### 2.3 Integrações disponíveis com os assistentes

Nada abaixo foi testado nesta fase; é a matriz de capacidades a confirmar na Fase 04. "Documentado"
significa recurso descrito na documentação oficial da ferramenta, ainda não verificado neste
ambiente.

| Capacidade | Claude Code | Codex CLI | Gemini CLI | GitHub Copilot |
| --- | --- | --- | --- | --- |
| Captura da solicitação | hook `UserPromptSubmit` (documentado) | a verificar (`notify` só ao fim do turno) | a verificar | sem mecanismo conhecido; registro manual |
| Status da execução | hooks `Stop`, `PostToolUse` (documentado) | `notify` (documentado) | a verificar | não |
| Tokens | campos `usage` nas transcrições locais; OpenTelemetry opcional (documentado) | a verificar | telemetria local opcional (a verificar) | não |
| Cancelamento / retomada | pelo usuário (`--resume`) | pelo usuário | pelo usuário | não aplicável |
| Rastreio de artefatos | `git` + hooks de ferramenta | `git` | `git` | `git` |

Consequência: a captura automática só é viável, em princípio, no Claude Code. Para os demais, o
ponto central de entrada será o registro manual (formulário no app ou script), sem declarar
cobertura universal.

### 2.4 Lacunas em relação ao prompt mestre

| # | Lacuna | Evidência |
| --- | --- | --- |
| G1 | Não há registro de **solicitações** (entrada informal) separado dos requisitos | requisitos nascem já formalizados |
| G2 | Não há registro de **execuções** de agentes (início, fim, agente, modelo, tokens, desfecho) | `test_register` cobre testes, não execuções |
| G3 | Não há **trilha de transições de estado**: só `updated_at` | impossibilita tempo de ciclo e retrabalho |
| G4 | Não há **versionamento do prompt mestre** com camadas e diffs aprovados | `prompts/CHANGELOG.md` registra mudanças, sem aprovação por revisão |
| G5 | Não há **registro de revisões de planejamento** | replanejamentos ficam em `project_status.md` |
| G6 | `release_status` é `not_released` em todos os itens, mas há tags publicadas (`v1.0`, `v1.0.2`) e o painel em produção | divergência entre registro e realidade |
| G7 | Não há métrica de tokens, custo, prazo (sem datas-alvo) ou falha de agente | dados não coletados |
| G8 | Não há tela de governança; o estado é lido em Markdown/CSV | — |

### 2.5 Conflitos entre o prompt mestre e as regras do projeto

Pelo próprio prompt mestre, nenhum controle existente é substituído sem análise e autorização.
Proposta de resolução, a aprovar:

| # | Prompt mestre | Regra vigente | Proposta |
| --- | --- | --- | --- |
| C1 | IDs `REQ-2026-00001`, `RQ-…`, `TASK-…` | Common P01: IDs `lowercase_snake` (`req_0001`); revisão de 2026-11-10 já corrigiu `REQ-0001` | manter o padrão do projeto e criar prefixos novos no mesmo estilo (tabela 4.2) |
| C2 | Pastas `restricted/` e `tmp/` | renomeadas para `.restricted/` e `.tmp/` (`decision_0040`) | proteger os quatro nomes, como já fazem `AGENTS.md` e `.claude/settings.json` |
| C3 | `prompts/common_p_governance_master.txt` | nomes `group_pNN_objective.txt` | `prompts/common_p08_governance_master.txt` |
| C4 | Novo componente transversal | `AGENTS.md`: módulos lógicos `common`, `collect`, `data`, `intelligence` | código em `src/common/governance_*.R` (transversal por natureza); um módulo `src/governance/` exigiria decisão |
| C5 | Estados únicos de requisito (Captured…Cancelled) | Common P01: cinco dimensões independentes por item de trabalho | manter as dimensões nos itens e acrescentar o ciclo de vida só no requisito (`status`), com mapeamento documentado |
| C6 | Rodar Gemini CLI, Codex e Copilot via adaptadores | `AGENTS.md`: não rodar outro assistente nem delegar sem pedido explícito | adaptadores só **leem** eventos/registros; nenhum despacho automático de tarefas |
| C7 | Painel atualizado a cada 150 s | app local; o processo já foi encerrado por falta de memória várias vezes | leitura incremental de CSVs pequenos com `reactivePoll`/`invalidateLater(150000)`; nada é recomputado se os arquivos não mudarem |

## 3. Requisitos já atendidos pela governança atual

| Critério do prompt mestre (seção 18) | Situação |
| --- | --- |
| 2. IDs únicos · 3. histórico · 10. controle de estados (parcial) · 16. decisões aprovadas preservadas · 17. fronteiras de segurança · 19. sem homologação automática · 20. documentação e testes | atendidos por Common P01, `AGENTS.md` e registros atuais |
| 4. decomposição · 6. planejamento · 18. retomada | parciais (requisitos → itens de trabalho; `handoff.md`) |
| 1, 5, 7, 8, 9, 11, 12, 13, 14, 15 | não atendidos |

## 4. Arquitetura proposta (a aprovar)

### 4.1 Princípios

- **Arquivos como fonte única.** Continuar em CSV/Markdown versionados em `docs/project_management/`
  (Common P01: "evitar nova plataforma"). Novos registros seguem o mesmo padrão.
- **Somente leitura sobre os agentes.** Captura por hooks documentados ou registro manual; nada é
  despachado automaticamente.
- **Minimização.** Uma solicitação é registrada por resumo curto e classificação, sem texto integral
  do prompt, sem caminhos sensíveis e sem nada das áreas protegidas.
- **Painel local**, como área nova do app Shiny ("Governança"), sem publicação no site até decisão.

### 4.2 Modelo de dados (novos registros)

| Registro | ID | Campos principais |
| --- | --- | --- |
| `request_register.csv` | `request_0001` | received_at, channel, agent, summary (minimizado), classification, requirement_ids, status |
| `execution_register.csv` | `exec_0001` | work_item_id, agent, model, started_at, ended_at, state, input_tokens, output_tokens, cached_tokens, cost_reported, retries, outcome, evidence_path (vazio quando indisponível) |
| `state_transitions.csv` | `trn_0001` | entity_id, field, from, to, at, actor, evidence |
| `prompt_revisions.csv` | `prv_0001` | prompt_file, version, previous_version, date, reason, class (safe_operational, functional, architectural, security_sensitive), affected_requirements, approval, approver |
| `planning_revisions.csv` | `plan_0001` | date, phase, summary, changes, reason, approval |
| `release_register.csv` | `rel_0001` | já previsto por Common P01 |

Reaproveitados: `req_` (requisito), `work_` (tarefa), `test_` (teste/evidência), `acc_` (aceite),
`decision_` (ADR), `risk_`. `run_` continua reservado às rodadas operacionais de Common P01.

Relações: request 1→N req; req 1→N work; work 1→N exec; exec 1→N test/evidence. A integridade é
verificada por um teste que confere que todo ID citado existe.

### 4.3 Componentes

1. `src/common/governance_registry.R`: leitura validada dos registros, verificação de integridade,
   gravação atômica com `safe_io.R` (já existente) e registro de transições.
2. `src/common/governance_metrics.R`: KPIs com definição formal; indicador ausente vira `NA`
   ("indisponível"), nunca zero.
3. `scripts/governance_capture.R`: entrada manual de solicitações e execuções (qualquer agente).
4. Hook opcional do Claude Code (`UserPromptSubmit`/`Stop`) que chama o script acima com resumo
   minimizado; desligado por padrão, ligado só com aprovação.
5. `prototype/governance_module.R`: área "Governança — Executive Command Center" no app.

### 4.4 Definições dos KPIs (rascunho)

| KPI | Definição | Disponível hoje? |
| --- | --- | --- |
| Total de solicitações | linhas de `request_register` | não (registro novo) |
| Total de requisitos / por estado | linhas de `requirements_register` por `status` | sim (20) |
| Implementados, testados, aceitos | itens com `implementation_status = implemented`, `test_status = passed`, `acceptance_status = approved` | sim (18, 19, 8) |
| Bloqueados | itens `blocked` em qualquer dimensão | sim (1) |
| Atrasados | itens com data-alvo vencida e não concluídos | não (sem datas-alvo) |
| Taxa de retrabalho | transições de volta (ex.: `passed`→`failed`, `implemented`→`in_progress`) ÷ itens | não (sem trilha) |
| Cobertura de testes | só se medida por ferramenta; caso contrário, "itens com teste ÷ itens implementados" rotulado como tal | parcial |
| Consumo de tokens / custo por requisito aceito | soma de `execution_register` ÷ aceites | não |
| Tempo médio de ciclo | da transição para `in_progress` até `approved` | não |
| Taxa de falha de agente | execuções `failed` ÷ execuções | não |
| Decisões humanas pendentes | aceites `pending` com implementação concluída e teste aprovado | sim |

## 5. Catálogo inicial de requisitos (proposto)

Um requisito guarda-chuva novo, `req_0021` (governança), com sub-requisitos rastreados como itens
de trabalho. Nada está aprovado.

| ID proposto | Título | Prioridade (MoSCoW) | Critério de aceite resumido |
| --- | --- | --- | --- |
| req_0021 | TaxMiner Governance: registro, planejamento, execução, evidências e painel executivo sobre a governança de Common P01 | Should | os 20 critérios da seção 18 do prompt mestre, cada um com evidência ou limitação declarada |
| work_0032 | Fase 01 — Discovery (este documento) | Must | relatório aprovado pelo desenvolvedor |
| work_0033 | Fase 02 — registros de solicitações, transições e integridade | Must | teste de integridade referencial e de transições passa |
| work_0034 | Fase 03 — planejamento, deduplicação e otimização de contexto | Should | deduplicação sugerida e nunca automática em caso ambíguo |
| work_0035 | Fase 04 — captura (hook Claude Code opcional + entrada manual) e registro de execuções | Should | matriz de capacidades verificada; sem conteúdo protegido nos registros |
| work_0036 | Fase 05 — painel executivo no app | Should | dados reais, filtros, atualização a cada 150 s, indicador de dados desatualizados |
| work_0037 | Fase 06 — versionamento do prompt mestre e relatórios de melhoria | Should | camada imutável protegida por teste |
| work_0038 | Fase 07 — qualidade e segurança | Must | testes unitários, integração, recuperação e segurança executados |
| work_0039 | Fase 08 — documentação e pacote de entrega | Must | homologação humana |

Deduplicação: `req_0002` (prontidão dos assistentes) e `work_0004`–`work_0007` tratam da
instalação dos agentes, não de governança das execuções; sem sobreposição. `req_0011` (gates
independentes) é reutilizado como regra, não duplicado.

## 6. Plano incremental das oito fases

| Fase | Entregável | Depende de | Gate | Esforço estimado* |
| --- | --- | --- | --- | --- |
| 01 Discovery | este documento | — | aprovação da arquitetura e do plano | concluída nesta sessão |
| 02 Requirements Registry | registros novos, validação e testes | 01 | integridade e rastreabilidade | 1 sessão |
| 03 Planning & Token Optimization | planejamento, deduplicação, replanejamento | 02 | validação funcional | 1–2 sessões |
| 04 Agent Integration | captura manual, hook opcional, execuções | 02 | integração e segurança | 1–2 sessões |
| 05 Executive Dashboard | área Governança no app | 02 (03 e 04 enriquecem) | dados, filtros, 150 s | 2 sessões |
| 06 Prompt Evolution | versões, diffs, aprovações | 02 | regras imutáveis protegidas | 1 sessão |
| 07 Quality & Security | relatório de qualidade e segurança | 02–06 | evidências e aceite técnico | 1 sessão |
| 08 Documentation & Delivery | pacote de entrega | 07 | homologação e autorização de publicação | 1 sessão |

\* Estimativa qualitativa em sessões de trabalho assistido, não medida. Consumo de tokens:
**indisponível**. Esta sessão não expõe a contagem de tokens ao agente, e a leitura das
transcrições locais (que a contém) depende de aprovação (risco R3).

Prioridade sugerida: 02 → 06 → 04 → 05 → 03 → 07 → 08. O versionamento do prompt (06) protege as
regras imutáveis antes de qualquer automação. O painel (05) só faz sentido com dados reais de 02 e
04.

## 7. Riscos e dependências

| # | Risco | Probabilidade | Impacto | Mitigação |
| --- | --- | --- | --- | --- |
| R1 | Registro de solicitações capturar texto sensível (nomes de arquivos protegidos, dados pessoais) | possível | alto | só resumo minimizado; filtro de termos protegidos; revisão humana antes de commit |
| R2 | Hook de captura executar a cada prompt e falhar ou atrasar a sessão | possível | médio | hook assíncrono, desligado por padrão, falha não bloqueante |
| R3 | Métricas de tokens exigirem leitura de transcrições do perfil do usuário | provável | médio | ler só campos numéricos de `usage`; precisa de autorização explícita |
| R4 | Concorrência por memória: painel com polling junto da exportação e da coleta DFP | possível | médio | CSVs pequenos, `reactivePoll` por data de modificação |
| R5 | Burocracia excessiva: perguntas simples virarem requisitos | provável | médio | classificação `question`/`operational_command` não gera requisito (seção 6.1) |
| R6 | Divergência entre `release_status` e as tags publicadas (G6) | observado | baixo | reconciliar na Fase 02 com `release_register.csv` |
| R7 | Afirmar cobertura dos agentes sem verificação | possível | alto | matriz da seção 2.3 marcada "a verificar" até a Fase 04 |

Dependências externas: nenhuma instalação nova prevista (R, shiny, arrow e testthat já declarados).

## 8. Checkpoint 1 (chk_0001)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 01 — Discovery, concluída e aguardando aprovação |
| Requisitos | `req_0021` (proposto) |
| Tarefas concluídas | inspeção autorizada; diagnóstico; catálogo; arquitetura; plano; riscos |
| Tarefas pendentes | Fases 02–08 (não autorizadas) |
| Agente | Claude Code (Opus 5.5) |
| Estado da execução | Completed (Fase 01) |
| Arquivos modificados | `docs/governance_plan.md` (novo); `prompts/common_p08_governance_master.txt` (novo, cópia v1.0); `prompts/README.md`; `prompts/CHANGELOG.md`; registros em `docs/project_management/` |
| Testes | nenhum executado (fase documental) |
| Evidências | este documento; contagens da seção 2.2 lidas dos CSVs em 2026-11-12 |
| Problemas conhecidos | lacunas G1–G8; conflitos C1–C7 aguardam decisão |
| Próxima ação autorizada | nenhuma; aguarda aprovação da Fase 01 e das resoluções C1–C7 |

## 9. Relatório de melhoria do prompt (Prompt Improvement Report, PRV proposto)

Versão atual: 1.0 (`prompts/common_p08_governance_master.txt`). Nova versão candidata: 1.1, **não
aplicada**. As alterações dependem de aprovação humana, salvo as marcadas *safe operational*,
que também foram deixadas apenas propostas.

| # | Problema | Melhoria proposta | Classe |
| --- | --- | --- | --- |
| P1 | Pastas protegidas citadas pelos nomes antigos (`restricted/`, `tmp/`) | citar `.restricted/`, `.tmp/` e os nomes antigos | security_sensitive |
| P2 | IDs `REQ-2026-00001` conflitam com Common P01 | adotar `lowercase_snake` e a tabela da seção 4.2 | functional |
| P3 | Nome sugerido `common_p_governance_master.txt` fora do padrão | `common_p08_governance_master.txt` | safe_operational |
| P4 | "Criar adaptadores" sugere despacho de tarefas, o que conflita com `AGENTS.md` | adaptadores somente leitura; despacho fora do escopo | architectural |
| P5 | Estados únicos de requisito ignoram as cinco dimensões de Common P01 | declarar o mapeamento | functional |
| P6 | Camadas A/B/C descritas, mas sem dizer onde a camada imutável fica | camada A = `AGENTS.md` + seção 12 do prompt; alterá-la exige decisão registrada | security_sensitive |
| P7 | Fase 01 pede "estimar tokens", mas o agente não tem acesso à contagem | aceitar "indisponível" como resposta válida | safe_operational |

Diff candidato: será gerado como diff entre `common_p08_governance_master.txt` v1.0 e v1.1 depois
da aprovação das linhas acima.

## 10. Aprovações necessárias

1. Aprovar (ou ajustar) a arquitetura e o plano desta Fase 01.
2. Decidir os conflitos C1–C7, em especial C4 (onde fica o código) e C6 (somente leitura).
3. Autorizar ou não o hook de captura do Claude Code e a leitura dos campos de `usage` das
   transcrições locais (R3).
4. Aprovar ou rejeitar as melhorias P1–P7 do prompt mestre.
5. Autorizar a Fase 02.

## 11. Fase 02 — Requirements Registry (executada em 2026-11-12)

Autorizada em `decision_0044`. Item `work_0033` (`req_0021`).

### Entregas

- `src/common/governance_registry.R`: especificação dos nove registros (colunas, prefixo de ID,
  referências e vocabulários); leitura; checagem de integridade; geração de IDs; registro de
  solicitações com resumo minimizado; mudança de campo com trilha de transições; rastreio de um
  ID; contagens.
- `scripts/governance_registry.R`: linha de comando (`check`, `summary`, `trace`,
  `add-request`, `set`).
- `docs/project_management/request_register.csv` (novo) e `state_transitions.csv` (trilha de
  auditoria; nada é apagado).
- `tests/testthat/test_governance_registry.R`: 11 testes.

### Regras implementadas

| Regra | Como |
| --- | --- |
| IDs únicos, no padrão e imutáveis | `id outside the pattern`, `duplicated id`; `governance_set_field` recusa mudar o ID; `governance_next_id` nunca reaproveita número |
| Integridade referencial | requisito → itens; item → dependências; teste, aceite → item; solicitação → requisitos; transição → qualquer entidade; revisão de prompt → requisitos |
| Estados | vocabulários de Common P01 nas cinco dimensões; ciclo de vida do requisito (com `proposed` e `accepted` legados); estados da solicitação |
| Aceite exige registro | item `approved` sem linha aprovada em `acceptance_register.csv` é erro |
| Toda transição registrada | `governance_set_field` grava o registro e acrescenta a linha em `state_transitions.csv` |
| Minimização (`risk_0018`) | resumo de uma linha, até 200 caracteres, sem caminho de área protegida e sem e-mail |
| Formato preservado | cada registro é regravado no próprio formato (todas as colunas entre aspas em `work_items.csv`; sem aspas nos demais, que recusam vírgula) e conferido por releitura antes da troca atômica |

### Evidências

- Checagem nos registros reais: 0 problemas; os nove registros são regravados idênticos byte a
  byte (`test_0058`).
- Suíte completa: 121 testes, 0 falhas (110 anteriores + 11 novos) (`test_0057`, `test_0058`).
  A suíte roda com `Rscript -e` (sem `--vanilla`), porque `test_environment.R` exige o renv
  ativado pelo `.Rprofile`. Com `--vanilla` esse teste falha (3 verificações), como já
  acontecia antes.
- A fase foi registrada com o próprio registro: `request_0001`, `request_0002`, `work_0033`,
  `test_0057`, `test_0058` e as transições `trn_0005`–`trn_0011`.

### Correção registrada

Na Fase 01 e na aprovação, gravei horários estimados (18:00 e 18:30) que estavam no futuro em
relação ao relógio. Eles foram substituídos pelos horários dos commits `c9fcb03` (17:26:24) e
`b7c392f` (17:28:09). A partir da Fase 02, todos os horários vêm do relógio do sistema
(`governance_now()`).

### Limitações

- Solicitações anteriores a 2026-11-12 não foram reconstruídas. `request_0001` foi registrada em
  retrospecto, com o horário do registro.
- `release_status` continua `not_released` em todos os itens, apesar das tags publicadas (G6).
  Fica para quando houver `release_register.csv`.
- Não há trava contra duas sessões gravando o mesmo registro ao mesmo tempo. A troca atômica evita
  arquivo corrompido, não uma perda de atualização concorrente.

## 12. Checkpoint 2 (chk_0002)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 02 implementada e testada; aguarda aceite humano (`work_0033` `pending`) |
| Requisitos | `req_0021` `in_progress` |
| Tarefas concluídas | Fases 01 (aceita) e 02 (implementada, testada) |
| Tarefas pendentes | Fases 06, 04, 05, 03, 07 e 08, nessa ordem (`plan_0001`) |
| Agente | Claude Code (Opus 5.5) |
| Estado da execução | Completed (Fase 02) |
| Arquivos | `src/common/governance_registry.R`, `scripts/governance_registry.R`, `tests/testthat/test_governance_registry.R`, registros em `docs/project_management/` |
| Testes | 121 passam (`test_0057`, `test_0058`) |
| Problemas conhecidos | G6; ausência de trava de concorrência |
| Próxima ação autorizada | nenhuma; aguarda aceite da Fase 02 e autorização da Fase 06 |

## 13. Revisão da Fase 02 e melhorias propostas do prompt (não aplicadas)

1. O prompt foi compreendido? Sim. A Fase 02 coube no modelo de arquivos do Common P01, sem
   plataforma nova.
2. Retrabalho: dois casos. As âncoras de edição falharam por fim de linha CRLF, e houve a correção
   dos horários estimados.
3. Leituras desnecessárias: nenhuma relevante. Os registros foram lidos por contagem e cabeçalho.
4. Tokens: indisponível.

| # | Problema | Melhoria proposta | Classe |
| --- | --- | --- | --- |
| P8 | Horários estimados pelo agente entraram nos registros | "Horários de registros vêm do relógio do sistema ou do commit; nunca estimados" (seção 10) | safe_operational |
| P9 | Uma aprovação genérica ("aprovo") cobre itens de naturezas diferentes | itens sensíveis à segurança (hooks, leitura de transcrições) exigem confirmação própria, item a item (seção 19) | security_sensitive |
| P10 | O comando de testes varia (`--vanilla` quebra `test_environment.R`) | nomear o comando canônico da suíte no prompt (seção 16, Fase 07) | safe_operational |

## 14. Fase 06 — Prompt Evolution (executada em 2026-11-12)

Autorizada em `decision_0046`; decisão `decision_0047`. Item `work_0034` (`req_0021`). No
catálogo da seção 5, esta fase tinha o número provisório `work_0037`. Como as fases seguem a
ordem do plano, e não a numérica, os IDs passaram a ser dados na ordem de execução.

### Entregas

- `src/common/governance_prompts.R`: impressões SHA-256 da camada imutável e checagem contra a
  linha de base; nova linha de base só com uma decisão existente; proposta de revisão (versão
  candidata e diff unificado guardados em `reports/governance/`); decisão humana que aplica ou
  rejeita; replanejamento; relatório de evolução.
- `docs/project_management/immutable_rules.csv`: linha de base inicial (`imm_0001`–`imm_0004`,
  `decision_0047`), cobrindo `AGENTS.md`, `CLAUDE.md`, Common P01 e a seção 12 de Common P08.
- `scripts/governance_registry.R`: comandos `baseline`, `propose-prompt`, `decide-prompt`,
  `add-plan` e `prompt-report`. Agora `check` também confere a camada imutável.
- `reports/governance/prompt_evolution.md`: histórico gerado (3 versões aprovadas, 0 pendentes,
  3 revisões de planejamento).
- `tests/testthat/test_governance_prompts.R`: 8 testes.

### Controles do gate (regras imutáveis e controle de alterações)

| Controle | Teste |
| --- | --- |
| Mudança na camada imutável sem decisão é acusada; fim de linha e linhas em branco finais não contam | baseline / detecção |
| Nova linha de base exige decisão existente; regras inalteradas mantêm a data e a decisão originais | re-baseline |
| Proposta guarda a versão candidata e o diff e não altera o prompt | proposta |
| Só pessoa aprova (agente é recusado); aprovação aplica, rejeição não; decisão não se repete | aprovação |
| Prompt alterado depois da proposta: aplicação recusada | proposta desatualizada |
| Revisão que toca a seção 12 exige a classe `security_sensitive` e uma decisão, e refaz a linha de base | camada imutável |
| Relatório lista versões, propostas pendentes e replanejamentos, e denuncia camada alterada | relatório |

### Evidências

- 129 testes, 0 falhas (121 anteriores + 8 novos) (`test_0059`, `test_0060`).
- `check` nos registros reais: integridade ok e camada imutável intacta.
- Registrados `request_0003`–`request_0005` (inclusive o pedido de formatação da nota e o de
  religar o app), `work_0034`, `plan_0003` e as transições `trn_0014`–`trn_0024`.

### Limitações

- As versões 1.0 a 1.2 foram feitas antes deste mecanismo. Seus diffs estão no Git
  (`c9fcb03`, `b7c392f`, `dc733fc`), não em `reports/governance/`.
- A linha de base protege contra mudança silenciosa, mas não impede quem edita o arquivo: a proteção
  é a detecção pelo `check` (e pelo teste da suíte), não um bloqueio de escrita.

## 15. Checkpoint 3 (chk_0003)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 06 implementada e testada; aguarda aceite (`work_0034` `pending`) |
| Requisitos | `req_0021` `in_progress` |
| Fases | 01 e 02 aceitas; 06 implementada; pendentes 04, 05, 03, 07 e 08 (`plan_0003`, proposto) |
| Testes | 129 passam |
| Próxima ação autorizada | nenhuma; a Fase 04 envolve o hook de captura e a leitura de tokens, que pelo P9 exigem confirmação própria |

## 16. Revisão da Fase 06 e melhorias propostas do prompt (não aplicadas)

1. O mecanismo da seção 5 do prompt (versões, diffs, aprovação, camadas) ficou implementado.
2. Retrabalho: um teste com expectativa errada (versão 1.0 → 1.0), corrigido; um script com
   `\n` desfeito pelo heredoc do shell, corrigido.
3. Tokens: indisponível.

| # | Problema | Melhoria proposta | Classe |
| --- | --- | --- | --- |
| P11 | O prompt não diz como propor e aplicar uma revisão | citar `propose-prompt` e `decide-prompt` na seção 5 e exigir que revisões futuras passem por eles | safe_operational |
| P12 | A seção 16 não diz que os IDs dos itens seguem a ordem de execução | registrar a regra na seção 6 | safe_operational |

## 17. Fase 04 — Agent Integration (executada em 2026-11-12)

Autorizada em `decision_0048`; decisão `decision_0049`. Item `work_0035` (`req_0021`).

### Entregas

- `src/common/governance_agents.R`:
  - registro de execuções (`execution_register.csv`, IDs `exec_`) com a máquina de estados da
    seção 10 do prompt; cada mudança de estado vira uma transição;
  - tokens e custo copiados do que o agente informa, nunca estimados; vazio significa
    "indisponível", e `check` recusa qualquer valor que não seja inteiro;
  - reconciliação: execução aberta há mais de 12 h sem evento de fim passa a `unknown`;
  - matriz de capacidades declarada (oito capacidades × quatro agentes) e verificação de presença
    no PATH, sem executar nenhum agente;
  - adaptador do hook do Claude Code (`UserPromptSubmit` registra a solicitação com resumo
    minimizado e abre a execução; `Stop`/`SessionEnd` a encerram); nunca falha a sessão;
  - leitor de tokens das transcrições: exige uma decisão registrada (P9) e uma pasta permitida, lê
    só os campos numéricos de `usage`, deduplica por `requestId` e não guarda texto.
- `scripts/governance_hook.R`: ponto de entrada do hook, **não instalado**. Não escreve nada na
  saída padrão e sai sempre com status 0.
- `scripts/governance_registry.R`: comandos `add-execution`, `update-execution`, `reconcile` e
  `capability-report` (gera `reports/governance/capability_matrix.md`).
- `tests/testthat/test_governance_agents.R`: 10 testes, todos com dados sintéticos.

### Controles do gate (integração e segurança)

| Controle | Teste |
| --- | --- |
| Estados fora da máquina, estado terminal reaberto, agente ou item inexistente: recusados | máquina de estados |
| Contagem estimada ou negativa recusada; vazio permanece indisponível no resumo | tokens |
| Execução sem fim vira `unknown`, não `completed` | reconciliação |
| Resumo da solicitação: uma linha, até 160 caracteres, sem e-mail e sem caminho protegido | minimização |
| Hook registra e encerra só a sessão certa; ignora outros eventos; entrada inválida não gera erro | adaptador |
| Script do hook em subprocesso: status 0 e nada na saída padrão, mesmo com entrada inválida | integração |
| Leitura de tokens sem decisão ou fora da pasta permitida: recusada; nenhum texto retorna | leitor de tokens |
| Tokens por turno = acumulado da sessão menos o já registrado | hook com tokens |
| Despacho de tarefas `not_used` para todos os agentes | matriz |

### Evidências

- 139 testes, 0 falhas (129 anteriores + 10 novos) (`test_0061`, `test_0062`).
- `check` nos registros reais: integridade ok; camada imutável intacta.
- Registros: `request_0007`, `work_0035`, `plan_0004`, transições até `trn_0031`.

### Limitações

- Nenhuma execução real foi capturada: o hook não está instalado e `execution_register.csv` está
  vazio. Execuções de outros agentes entram por `add-execution` (manual).
- A matriz é declarada. `documented` e `to_verify` não foram exercitados aqui. Só a presença
  dos comandos no PATH foi verificada (os quatro estão presentes).
- O hook não recebe o modelo. O leitor de tokens o obtém da transcrição, se habilitado.

## 18. Checkpoint 4 (chk_0004)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 04 implementada e testada; aguarda aceite (`work_0035` `pending`) |
| Requisitos | `req_0021` `in_progress` |
| Fases | 01, 02 e 06 aceitas; 04 implementada; pendentes 05, 03, 07 e 08 (`plan_0004`, proposto) |
| Testes | 139 passam |
| Confirmações pendentes (P9) | (a) instalar o hook em `.claude/settings.local.json`; (b) habilitar a leitura de tokens das transcrições locais |

## 19. Revisão da Fase 04

1. A seção 9 do prompt (adaptadores somente leitura, matriz de capacidades) e a Fase 04 ficaram
   implementadas, exceto a captura real, que depende do P9.
2. Retrabalho: a função de atualização não gravava o novo estado (o teste acusou, corrigido); um
   `expect_match` avaliava a chamada duas vezes, trocado por atribuição.
3. Tokens: indisponível.
4. Sem melhorias de prompt propostas nesta fase.

## 20. Fase 05 — Executive Dashboard (executada em 2026-11-12)

Fase 04 aceita (`acc_0012`); Fase 05 autorizada em `decision_0050`. Item `work_0036` (`req_0021`).

### Entregas

- `src/common/governance_metrics.R`: 17 KPIs da seção 11.1 com definição formal; filtros;
  funil; etapas de entrega; desempenho por agente; grafo de rastreabilidade; trilha; frescor dos
  dados; relatório exportável. KPI sem dado é `NA` com o motivo, nunca zero.
- `prototype/governance_module.R`: aba **Governança** do app local, com os painéis Executive
  Overview, Requirements Pipeline, Risks & Blockers, Execution Timeline, Agent Performance, Token
  Efficiency, Prompt Evolution, Traceability Graph (com detalhamento do registro e histórico de
  transições), Delivery Roadmap e Audit Trail.
- Filtros por período, agente, módulo, prioridade e status. Todos os indicadores seguem os filtros,
  exceto riscos e histórico do prompt, que não se ligam a requisitos. Pesquisa por ID; clique em
  nó, linha ou barra para detalhar; "Voltar" desfaz.
- Atualização a cada 150 s (ou 60 s, 300 s, manual). Os registros só são relidos quando os arquivos
  mudam. Mostra a última sincronização e o último progresso real (transição mais recente); indica
  dados desatualizados (mais de dois intervalos sem leitura) e falha de leitura, mantendo os últimos
  dados. Botão "Atualizar agora". A página só lê: não inicia execuções nem grava registros.
- Exportação: relatório em Markdown (KPIs com definições, funil, etapas, filtros vigentes) e trilha
  em CSV.
- A aba fica só no app local; os registros de governança não vão para o painel publicado.

### Gate (dados, filtros e atualização a cada 150 s)

| Controle | Teste |
| --- | --- |
| Cada KPI confere com o cálculo manual em registros sintéticos; indisponível vira `NA` | KPIs |
| Sem execuções: tokens, custo e falha de agente indisponíveis | KPIs indisponíveis |
| Módulo, agente, período e status filtram requisitos, itens, testes, solicitações, execuções e trilha | filtros |
| Funil, etapas, desempenho, trilha e grafo (sem nó solto; commit sem "+uncommitted") | dados dos painéis |
| Desatualizado após dois intervalos; nunca no modo manual | frescor |
| Intervalo padrão de 150 s; sem mudança não relê; arquivo novo é relido; filtros mantidos; falha mantém os dados | módulo (testServer) |
| Detalhar, pesquisar ID (inexistente é recusado) e voltar | módulo (testServer) |

### Evidências

- 147 testes, 0 falhas (139 anteriores + 8 novos) (`test_0063`, `test_0064`). O único aviso da
  suíte é anterior a esta fase (`test_fund_analytics.R`).
- Página conferida no app com os registros reais (captura de tela): 21 requisitos, 22 itens
  implementados, 12 aceitos, camada imutável intacta.

### Limitações

- Sem execuções registradas, os painéis de execuções, desempenho e tokens mostram "indisponível".
  Isso persiste até a captura (P9) ou o registro manual.
- "Atrasados" fica indisponível porque o registro não tem datas-alvo.
- A maior parte dos requisitos antigos está em `proposed`. O funil mostra o registro como ele é.

## 21. Checkpoint 5 (chk_0005)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 05 implementada e testada; aguarda aceite (`work_0036` `pending`) |
| Fases | 01, 02, 06 e 04 aceitas; 05 implementada; pendentes 03, 07 e 08 (`plan_0005`, proposto) |
| Testes | 147 passam |
| Confirmações pendentes (P9) | hook de captura; leitura de tokens das transcrições |

## 22. Revisão da Fase 05

1. As seções 11.1 a 11.4 do prompt foram implementadas. Os KPIs sem base aparecem como indisponíveis.
2. Retrabalho: com a pasta dos registros ausente, a leitura devolvia tabelas vazias em vez de
   falhar. O teste acusou, e a página passou a exigir o registro de requisitos e a manter os dados
   anteriores. Avisos de separador decimal corrigidos.
3. Tokens: indisponível.

| # | Problema | Melhoria proposta | Classe |
| --- | --- | --- | --- |
| P13 | O status `proposed` dos requisitos antigos não acompanha a entrega dos itens | reconciliar o status dos requisitos na Fase 03, com aprovação humana item a item | functional |

## 23. Aceite da Fase 05

Fase 05 aceita em 2026-11-12T21:19:53-03:00 (`acc_0013`, `decision_0051`); `plan_0005` aprovado. Fases aceitas: 01, 02,
06, 04 e 05. Pendentes: 03, 07 e 08, cada uma com autorização própria. Itens P9 seguem pendentes.

## 24. Fase 03 — Planning & Token Optimization (executada em 2026-11-13)

Autorizada pelo desenvolvedor ("Sim. Autorizado. Pode seguir.", `decision_0052`). Item `work_0037`.
A autorização genérica não cobre os itens P9 nem uma nova versão.

### Entregas (`src/common/governance_planning.R`)

- **Deduplicação** (seção 6.3): compara o texto de um pedido novo com requisitos e itens
  (similaridade de termos). Só sugere ("provável duplicata" ou "relacionado"), marca outro módulo e
  nunca funde. Também aponta solicitações quase iguais no registro.
- **Planejamento e decomposição** (seção 7): plano por requisito com tarefas abertas,
  dependências (itens e requisitos), riscos, critérios de aceite, agente recomendado (com a base da
  recomendação), complexidade (pontuação explicada), checkpoints e estratégia de testes.
- **Estimativas**: esforço pela mediana do ciclo de itens aceitos **do mesmo módulo**, com o tamanho
  da amostra. Abaixo de três itens fica indisponível. Tokens só com execuções informadas; hoje,
  indisponível.
- **Priorização transparente**: pontuação = peso da prioridade registrada + itens que o requisito
  desbloqueia + 1 se já iniciado − penalidade de complexidade. Lê as prioridades; nunca as altera.
- **Otimização de contexto** (seção 8): pacote por camadas (1 metadados dos registros; 2 resumos
  validados de `handoff.md` e `project_status.md`; 3 arquivos de evidência como trechos; 4
  arquivos completos só sob demanda), dentro de um orçamento em caracteres. Caminhos protegidos,
  absolutos ou com `..` ficam fora.
- **Replanejamento** (seção 14): o que mudou desde a última revisão aprovada (solicitações,
  falhas, bloqueios, riscos, execuções, tokens, revisões pendentes).
- **Reconciliação do status dos requisitos (P13)**: propõe o status que os itens sustentam e marca
  os casos ambíguos. Só aplica os aprovados pelo desenvolvedor, um a um, com a decisão como
  evidência (`reconcile-requirements --apply=... --decision_id=...`).
- Comandos novos: `plan-report` (gera `reports/governance/planning_report.md`), `plan`, `dedup`,
  `context`, `reconcile-requirements`.
- Decomposição de `req_0021`: itens `work_0038` (Fase 07) e `work_0039` (Fase 08) registrados
  como não iniciados.
- Correção da Fase 05: no funil, `accepted` passa a ser o estado final, como na seção 10 do prompt.

### Gate (validação funcional e de qualidade)

| Controle | Teste |
| --- | --- |
| Deduplicação sugere, marca outro módulo e não altera nenhum registro | deduplicação |
| Propostas de status pela evidência dos itens; sem itens, nenhuma proposta; ambiguidade marcada | reconciliação |
| Aplica só com `decision_NNNN`, só propostas vigentes, com transição registrada | aplicação |
| Plano com tarefas, dependências e riscos; esforço só com amostra comparável; tokens nunca estimados sem dado | plano |
| Pontuação confere com seus componentes; prioridades intactas | priorização |
| Camadas em ordem, orçamento respeitado, caminhos protegidos excluídos | contexto |
| Replanejamento desde a última revisão aprovada; relatório gerado | replanejamento |

### Evidências

- 155 testes, 0 falhas (147 anteriores + 8 novos) (`test_0065`, `test_0066`). O único aviso é
  anterior (`test_fund_analytics.R`).
- `reports/governance/planning_report.md` gerado com os registros reais; verificação de integridade ok.

### Limitações

- Sem execuções registradas, tokens e agente recomendado por histórico continuam indisponíveis.
- O ciclo medido vem das transições registradas, não do tempo de trabalho. O histórico importado
  (aceite como primeira transição) fica fora da amostra.

## 25. Checkpoint 6 (chk_0006)

| Campo | Valor |
| --- | --- |
| Etapa | Fase 03 implementada e testada; aguarda aceite (`work_0037` `pending`) |
| Fases | 01, 02, 06, 04 e 05 aceitas; 03 implementada; pendentes 07 e 08 (`plan_0006`, proposto) |
| Testes | 155 passam |
| Decisões pendentes | 18 propostas de status de requisitos (P13), item a item; itens P9 |
| Novo pedido | instalador por versão (`request_0012`), a planejar à parte |

## 26. Revisão da Fase 03

1. As seis partes da fase foram implementadas sem LLM e sem rede.
2. Retrabalho: a primeira versão estimava esforço com itens de outros módulos e com o histórico
   importado (ciclo zero). Passou a usar só itens comparáveis e a mostrar "indisponível".
3. Tokens: indisponível.
