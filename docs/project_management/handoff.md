# Retomada do TaxMiner

Atualizado: 2026-11-10T20:00:00-03:00. Branch `main`. O histórico completo de
retomadas está em `handoff_history.md`; a revisão e sua execução, em
`review_update_plan.md`.

## Estado atual

- **Common P02 (setup):** `work_0001` e `work_0003` aprovados (`acc_0001`,
  `acc_0002`). Release `not_released`; operações `not_started`.
- **Common P03 (`work_0002`):** arquitetura, requisitos com limiares e
  dicionário aprovados (`acc_0003`); `req_0003` `accepted`.
- **Assistentes (`work_0004`–`work_0007`):** implementados, testados e aprovados
  (`acc_0004`–`acc_0007`); revisão `work_0018` aprovada (`acc_0008`).
- **Repositório:** licença MIT; CI `validate_environment` no GitHub Actions;
  commits futuros com e-mail noreply (configuração local).
- **Fase 1: suspensa** por decisão do desenvolvedor (`decision_0020`).
  `work_0008` `blocked`; Collect P01 concluído (`docs/source_inventory.md`,
  `docs/feasibility.md`), três decisões em aberto. Nenhum documento coletado.
- **Fase 2: iniciada** (`work_0011` `in_progress`). Collect P04 etapa 00
  concluída: `docs/data_sources.md`, `config/financial_disclosure_sources.yml`,
  `scripts/probe_financial_sources.R` (`test_0032`). Notas só nos pacotes
  RAD/ENET (`risk_0012`). Pipeline em `src/collect/` (`test_0033`, `test_0034`);
  coleta de todas as 14.015 DFP em andamento em `C:\TaxMinerData`
  (`decision_0022`). Fase 3 não iniciada.

## Validação

```powershell
Rscript --vanilla scripts/validate_environment.R
```

CI no GitHub Actions aprovado (`test_0024`), com restauração limpa do lock.
O aviso de `testthat` compilado no R 4.5.3 permanece só localmente (R 4.5.1, por
escolha do desenvolvedor).

## Pendências

1. Desenvolvedor pode apagar `tmp/doit.txt`; o `doit` agora usa
   `.claude/doit.txt` (ignorado pelo Git).
2. Adiados por escolha do desenvolvedor: atualização do R e checkout fora do
   OneDrive (`risk_0002`, `risk_0007`).
3. Refatoração do texto repetido dos prompts: pacote 1.1.

## Próxima ação técnica

Acompanhar a coleta das DFP (`C:\TaxMinerData\collect_dfp.log` e
`manifest.csv`); se o processo parar, rodar de novo o comando de
`docs/data_sources.md` (retoma de onde parou). Em paralelo: Data P03
(extração das notas dos pacotes já baixados). ITR depende de mais
armazenamento. Fase 1 retoma quando o desenvolvedor decidir os
pontos de `docs/feasibility.md`.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`. Não inferir aceites, não fabricar
evidências, não fazer commit ou push sem autorização explícita.
