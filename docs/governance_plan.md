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
