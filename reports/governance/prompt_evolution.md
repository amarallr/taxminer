# Evolução do prompt mestre

Gerado em 2026-11-12T17:52:07-03:00 por `scripts/governance_registry.R prompt-report`. Não editar à mão.

## Camada imutável

Intacta: as impressões SHA-256 conferem com `immutable_rules.csv`.

## Revisões do prompt

| Revisão | Arquivo | Versão | Classe | Melhorias | Situação | Aprovador |
| --- | --- | --- | --- | --- | --- | --- |
| prv_0001 | prompts/common_p08_governance_master.txt | — → 1.0 | baseline |  | approved | developer |
| prv_0002 | prompts/common_p08_governance_master.txt | 1.0 → 1.1 | security_sensitive;functional;architectural;safe_operational | P1 protected names;P2 lowercase_snake IDs;P3 file name;P4 read-only adapters;P5 state mapping;P6 location of the immutable layer;P7 tokens may be unavailable | approved | developer |
| prv_0003 | prompts/common_p08_governance_master.txt | 1.1 → 1.2 | safe_operational;security_sensitive | P8 timestamps from the clock or commit;P9 item-level confirmation for security-sensitive items;P10 canonical test command | approved | developer |
| prv_0004 | prompts/common_p08_governance_master.txt | 1.2 → 1.3 | safe_operational | P11 revisions only through propose-prompt and decide-prompt;P12 work item IDs follow execution order | approved | developer |

Propostas pendentes: 0. Aprovadas: 4. Rejeitadas: 0.

## Revisões do planejamento

| Revisão | Fase | Resumo | Situação |
| --- | --- | --- | --- |
| plan_0001 | governance_phase_01 | Eight phases in the order 02 06 04 05 03 07 08; phase 02 authorized; phases 03 to 08 each need their own authorization | approved |
| plan_0002 | governance_phase_02 | Phase 02 implemented and tested; order unchanged (next 06 then 04 05 03 07 08); phase 06 awaits authorization | approved |
| plan_0003 | governance_phase_06 | Phase 06 implemented and tested; next 04 (agent integration) then 05 03 07 08; the capture hook and transcript token reading need item-level confirmation (P9) | approved |
