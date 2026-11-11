# Retomada do TaxMiner

Atualizado: 2026-11-11T00:10:00-03:00. Branch `main`. O histórico completo de
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
- **Fases (`decision_0025`):** a Fase 1 tem as subfases 1.1 (Soluções de
  Consulta), 1.2 (notas) e 1.3 (fundos); a Fase 2 é a inteligência cruzada.
- **Fase 1.1: suspensa** por decisão do desenvolvedor (`decision_0020`).
  `work_0008` `blocked`; Collect P01 concluído (`docs/source_inventory.md`,
  `docs/feasibility.md`), três decisões em aberto. Nenhum documento coletado.
- **Fase 1.2: iniciada** (`work_0011` `in_progress`). Collect P04 etapa 00
  concluída: `docs/data_sources.md`, `config/financial_disclosure_sources.yml`,
  `scripts/probe_financial_sources.R` (`test_0032`). Notas só nos pacotes
  RAD/ENET (`risk_0012`). Pipeline em `src/collect/` (`test_0033`, `test_0034`);
  coleta de todas as 14.015 DFP em andamento em `C:\TaxMinerData`
  (`decision_0022`). Fase 2 (inteligência cruzada) não iniciada.
- **Fase 1.3: fundos de investimento** (`decision_0024`): família
  `investment_fund_reports` (FII, FIDC, FIP, FIAGRO), independente das outras
  subfases.
  - Listagens da CVM verificadas (`docs/data_sources.md`,
    `config/investment_fund_report_sources.yml`).
  - Prompts `collect_p05_investment_fund_report_acquisition.txt` e
    `data_p04_investment_fund_report_consolidation.txt`.
  - `work_0020`–`work_0023` não iniciados. A coleta só começa depois que as DFP
    estiverem estáveis e houver nova autorização.
- **Novas fontes de dados (Common P07, `work_0019`):** rotinas comuns para as fontes novas.
  - Etapa 00 concluída (`docs/integration/new_data_sources_gap_analysis.md`).
  - Gate 01 decidido (`decision_0023`): primeiro as rotinas comuns em `src/common/`; a
    família `investment_fund_reports` só depois que a coleta da Fase 1.2 estiver estável.
  - Etapa 02 implementada (`work_0024`, `test_0036`): `src/common/safe_io.R`,
    `signatures.R` e `execution_policy.R`. Adoção por `src/collect/` fica para
    um item posterior, depois da coleta das DFP.
  - Riscos `risk_0014` e `risk_0015`.
- **Data P03 (`work_0012`):** extração validada em 83 pacotes (66 completos;
  `test_0035`, `test_0037`). Faltam tabelas e Parquet (`arrow` ainda não
  declarado). `pdftools`, `xml2` e `base64enc` declarados (`decision_0026`).

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
armazenamento. Fase 1.1 retoma quando o desenvolvedor decidir os
pontos de `docs/feasibility.md`.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`. Não inferir aceites, não fabricar
evidências, não fazer commit ou push sem autorização explícita.
