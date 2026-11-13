# Planejamento — TaxMiner Governance

Gerado em 2026-11-13T08:24:30-03:00 por `scripts/governance_registry.R plan-report`. Não editar à mão.

Motor determinístico sobre os registros (Fase 03). Nada aqui altera prioridades ou status:
as propostas de status só valem depois de aprovadas, uma a uma, pelo desenvolvedor.

## Prioridade dos requisitos abertos

Pontuação = peso da prioridade registrada (high 3, medium 2, low 1) + itens de outros requisitos que
dependem deste + 1 se já iniciado − penalidade de complexidade (alta 2, média 1).

| rank | requirement_id | module | priority | priority_weight | unblocks | started | complexity | penalty | score | open_items | effort_days |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  1 | req_0014 | intelligence | high | 3 | 5 | 1 | alta | 2 | 7 | 2 | indisponível |
|  2 | req_0018 | data | high | 3 | 2 | 1 | média | 1 | 5 | 1 | indisponível |
|  3 | req_0003 | common | high | 3 | 1 | 1 | média | 1 | 4 | 1 | 0,00 |
|  4 | req_0007 | collect | high | 3 | 1 | 1 | média | 1 | 4 | 1 | indisponível |
|  5 | req_0008 | data | high | 3 | 1 | 1 | média | 1 | 4 | 2 | indisponível |
|  6 | req_0012 | collect | high | 3 | 1 | 1 | média | 1 | 4 | 1 | indisponível |
|  7 | req_0013 | data | high | 3 | 1 | 1 | média | 1 | 4 | 1 | indisponível |
|  8 | req_0004 | collect | high | 3 | 1 | 0 | média | 1 | 3 | 1 | indisponível |
|  9 | req_0005 | data | high | 3 | 1 | 0 | média | 1 | 3 | 1 | indisponível |
| 10 | req_0006 | intelligence | high | 3 | 1 | 0 | média | 1 | 3 | 1 | indisponível |
| 11 | req_0009 | intelligence | high | 3 | 1 | 0 | média | 1 | 3 | 1 | indisponível |
| 12 | req_0010 | intelligence | high | 3 | 1 | 0 | média | 1 | 3 | 1 | indisponível |
| 13 | req_0019 | intelligence | high | 3 | 1 | 1 | alta | 2 | 3 | 2 | indisponível |
| 14 | req_0011 | common | high | 3 | 1 | 0 | alta | 2 | 2 | 4 | 0,01 |
| 15 | req_0015 | common | medium | 2 | 0 | 1 | média | 1 | 2 | 1 | 0,01 |
| 16 | req_0016 | common | medium | 2 | 0 | 0 | não decomposto | 0 | 2 | 0 | indisponível |
| 17 | req_0017 | common | medium | 2 | 0 | 0 | não decomposto | 0 | 2 | 0 | indisponível |
| 18 | req_0020 | intelligence | high | 3 | 0 | 1 | alta | 2 | 2 | 1 | indisponível |
| 19 | req_0021 | common | medium | 2 | 0 | 1 | alta | 2 | 1 | 3 | 0,02 |

## Plano dos cinco primeiros

### req_0014 — Independent investment_fund_reports search

- Status registrado: `proposed`; status que os itens sustentam: `awaiting_acceptance`.
- Complexidade: alta (pontuação 6,70 = 2 itens abertos + 1 dependências externas + 11 arquivos de evidência / 3).
- Esforço estimado: indisponível (amostra de 0 itens; mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos).
- Tokens estimados: indisponível (amostra de 0 execuções).
- Agente recomendado: `claude_code` (responsável pelos itens do requisito (sem execuções registradas)).
- Dependências: work_0021.
- Riscos: depende de itens ainda não aceitos: work_0021.
- Estratégia de testes: manter os níveis já usados (4 testes registrados) e cobrir cada item aberto.
- Tarefas abertas:

| work_item_id | title | implementation_status | test_status | acceptance_status |
| --- | --- | --- | --- | --- |
| work_0022 | Build independent investment fund report search | implemented | passed | pending |
| work_0027 | Build phase 1.3 fund analytics dashboard (derived metrics, market overview, administrator concentration, fund profile) | implemented | passed | pending |

### req_0018 — Central entity resolution and name normalization (identity by CNPJ; denomination history)

- Status registrado: `proposed`; status que os itens sustentam: `awaiting_acceptance`.
- Complexidade: média (pontuação 4,30 = 1 itens abertos + 2 dependências externas + 4 arquivos de evidência / 3).
- Esforço estimado: indisponível (amostra de 0 itens; mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos).
- Tokens estimados: indisponível (amostra de 0 execuções).
- Agente recomendado: `claude_code` (responsável pelos itens do requisito (sem execuções registradas)).
- Dependências: work_0022, work_0027.
- Riscos: depende de itens ainda não aceitos: work_0022, work_0027.
- Estratégia de testes: manter os níveis já usados (2 testes registrados) e cobrir cada item aberto.
- Tarefas abertas:

| work_item_id | title | implementation_status | test_status | acceptance_status |
| --- | --- | --- | --- | --- |
| work_0028 | Implement central entity resolution (entity, denomination and name history catalogs; versioned equivalence dictionary) and integrate it into fund search, filters, dashboards and export | implemented | passed | pending |

### req_0003 — Source-specific architecture and measurable acceptance

- Status registrado: `accepted`; status que os itens sustentam: `implemented`.
- Complexidade: média (pontuação 4,70 = 1 itens abertos + 1 dependências externas + 8 arquivos de evidência / 3).
- Esforço estimado: 0,00 dias (amostra de 5 itens; mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos).
- Tokens estimados: indisponível (amostra de 0 execuções).
- Agente recomendado: `claude_code` (responsável pelos itens do requisito (sem execuções registradas)).
- Dependências: work_0001.
- Riscos: nenhum identificado nos registros.
- Estratégia de testes: manter os níveis já usados (1 testes registrados) e cobrir cada item aberto.
- Tarefas abertas:

| work_item_id | title | implementation_status | test_status | acceptance_status |
| --- | --- | --- | --- | --- |
| work_0019 | New data sources: inventory and gap analysis for CVM fund reports (Common P07 stage 00) | implemented | not_applicable | pending |

### req_0007 — Acquire public financial_disclosures independently

- Status registrado: `proposed`; status que os itens sustentam: `in_progress`.
- Complexidade: média (pontuação 4,00 = 1 itens abertos + 2 dependências externas + 3 arquivos de evidência / 3).
- Esforço estimado: indisponível (amostra de 0 itens; mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos).
- Tokens estimados: indisponível (amostra de 0 execuções).
- Agente recomendado: `codex` (responsável pelos itens do requisito (sem execuções registradas)).
- Dependências: work_0001, work_0002.
- Riscos: nenhum identificado nos registros.
- Estratégia de testes: manter os níveis já usados (3 testes registrados) e cobrir cada item aberto.
- Tarefas abertas:

| work_item_id | title | implementation_status | test_status | acceptance_status |
| --- | --- | --- | --- | --- |
| work_0011 | Discover and acquire public financial report sample | in_progress | passed | pending |

### req_0008 — Process financial_notes independently

- Status registrado: `proposed`; status que os itens sustentam: `in_progress`.
- Complexidade: média (pontuação 5,00 = 2 itens abertos + 1 dependências externas + 6 arquivos de evidência / 3).
- Esforço estimado: indisponível (amostra de 0 itens; mediana do ciclo (primeira transição até o aceite) de itens aceitos do mesmo módulo x itens abertos).
- Tokens estimados: indisponível (amostra de 0 execuções).
- Agente recomendado: `claude` (responsável pelos itens do requisito (sem execuções registradas)).
- Dependências: work_0011.
- Riscos: depende de itens ainda não aceitos: work_0011.
- Estratégia de testes: manter os níveis já usados (4 testes registrados) e cobrir cada item aberto.
- Tarefas abertas:

| work_item_id | title | implementation_status | test_status | acceptance_status |
| --- | --- | --- | --- | --- |
| work_0012 | Extract and consolidate financial notes and tables | in_progress | passed | pending |
| work_0026 | Plan hybrid document processing (MarkItDown, Markdown + Parquet + metadata, token budget) | not_started | not_run | pending |

## Reconciliação do status dos requisitos (P13, propostas)

Cada linha precisa de aprovação humana própria. `ambiguous = TRUE` pede atenção especial.

| requirement_id | current | proposed | items | implemented | tested | accepted | ambiguous | note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| req_0001 | proposed | accepted | 1 | 1 | 1 | 1 | FALSE |  |
| req_0002 | proposed | accepted | 5 | 5 | 5 | 5 | FALSE |  |
| req_0003 | accepted | implemented | 3 | 3 | 1 | 2 | TRUE | "accepted" registrado no sentido de requisito aprovado; confirmar o sentido |
| req_0004 | proposed | blocked | 1 | 0 | 1 | 0 | FALSE |  |
| req_0005 | proposed | planned | 1 | 0 | 0 | 0 | FALSE |  |
| req_0006 | proposed | planned | 1 | 0 | 0 | 0 | FALSE |  |
| req_0007 | proposed | in_progress | 1 | 0 | 1 | 0 | FALSE |  |
| req_0008 | proposed | in_progress | 2 | 0 | 1 | 0 | FALSE |  |
| req_0009 | proposed | planned | 1 | 0 | 0 | 0 | FALSE |  |
| req_0010 | proposed | planned | 1 | 0 | 0 | 0 | FALSE |  |
| req_0011 | proposed | planned | 4 | 0 | 0 | 0 | FALSE |  |
| req_0012 | proposed | awaiting_acceptance | 1 | 1 | 1 | 0 | FALSE |  |
| req_0013 | proposed | awaiting_acceptance | 1 | 1 | 1 | 0 | FALSE |  |
| req_0014 | proposed | awaiting_acceptance | 2 | 2 | 2 | 0 | FALSE |  |
| req_0015 | proposed | in_progress | 1 | 0 | 1 | 0 | FALSE |  |
| req_0018 | proposed | awaiting_acceptance | 1 | 1 | 1 | 0 | FALSE |  |
| req_0019 | proposed | awaiting_acceptance | 2 | 2 | 1 | 0 | FALSE |  |
| req_0020 | proposed | awaiting_acceptance | 1 | 1 | 1 | 0 | FALSE |  |

## Entradas do replanejamento

Desde a última revisão aprovada (2026-11-12T18:23:35-03:00):

- Solicitações novas: 3.
- Testes com falha: 0.
- Itens bloqueados: work_0008.
- Riscos abertos: 13.
- Execuções com falha: 0.
- Tokens informados: indisponível.
- Revisões de planejamento pendentes: plan_0006.

## Solicitações possivelmente duplicadas

| request_a | request_b | similarity |
| --- | --- | --- |
| request_0002 | request_0003 | 0.67 |
| request_0002 | request_0006 | 0.67 |
| request_0002 | request_0009 | 0.60 |
| request_0002 | request_0010 | 0.80 |
| request_0003 | request_0006 | 1.00 |
