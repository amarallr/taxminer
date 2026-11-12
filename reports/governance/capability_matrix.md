# Matriz de capacidades dos agentes

Gerada em 2026-11-12T18:01:29-03:00 por `scripts/governance_registry.R capability-report`.

Níveis: `implemented` (adaptador neste repositório, com testes); `documented` (documentado pelo
fornecedor, não exercitado aqui); `manual` (só por registro manual); `not_used` (existe, mas não é
usado: despacho de tarefas, vedado pelo `AGENTS.md`); `unavailable` (sem mecanismo documentado
conhecido); `to_verify` (não confirmado).

| Capacidade | claude_code | codex | github_copilot | gemini_cli |
| --- | --- | --- | --- | --- |
| request_capture | implemented | manual | manual | manual |
| task_dispatch | not_used | not_used | not_used | not_used |
| execution_status | implemented | documented | manual | to_verify |
| logs | documented | to_verify | unavailable | to_verify |
| metrics | implemented | to_verify | unavailable | to_verify |
| cancellation | unavailable | unavailable | unavailable | unavailable |
| resume | documented | to_verify | unavailable | to_verify |
| artifact_tracking | manual | manual | manual | manual |

## Comandos no PATH

Só a presença do comando é verificada; nenhum agente é executado.

| Agente | Comando | No PATH |
| --- | --- | --- |
| claude_code | `claude` | sim |
| codex | `codex` | sim |
| github_copilot | `gh` | sim |
| gemini_cli | `gemini` | sim |
