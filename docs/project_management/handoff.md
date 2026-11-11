# Retomada do TaxMiner

Atualizado: 2026-11-11T08:04:21-03:00. Branch `main`. O histórico completo de
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
  - Iniciada pelo desenvolvedor (`decision_0029`).
  - **Collect P05 (`work_0020`):** implementado. Fontes verificadas
    (`docs/data_sources.md`); 102 de 102 arquivos coletados
    (`test_0042`, `test_0043`).
  - **Data P04 (`work_0021`):** consolidação implementada e testada
    (`test_0044`). Rodada completa feita (`test_0047`): 12,16 milhões de
    linhas; inventário de layouts em `docs/data_dictionary.md`. A primeira
    tentativa (`test_0045`) revelou um bug, já corrigido.
  - **Busca (`work_0022`, `decision_0030`):** implementada e testada (`test_0049`,
    `test_0050`). Primeira área do Shiny em `prototype/`; rodar com
    `TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla scripts/run_prototype.R` e abrir
    `http://127.0.0.1:8765`.
  - `work_0023` (aceite humano da Fase 1.3) não iniciado.
- **Processamento documental híbrido (`work_0026`):** diagnóstico e plano em
  `docs/integration/hybrid_document_processing_plan.md`. Python 3.12 com `.venv` e
  MarkItDown fixado autorizados (`decision_0031`); LLM e envio de texto ainda sem decisão.
- **Layout dos dados (`work_0025`, `decision_0028`):** uma pasta por família em
  `C:\TaxMinerData`. Fundos e notas já movidos; as DFP serão movidas depois da
  coleta, com `scripts/organize_data_dir.R dfp`.
- **Novas fontes de dados (Common P07, `work_0019`):** rotinas comuns para as fontes novas.
  - Etapa 00 concluída (`docs/integration/new_data_sources_gap_analysis.md`).
  - Gate 01 decidido (`decision_0023`): primeiro as rotinas comuns em `src/common/`; a
    família `investment_fund_reports` só depois que a coleta da Fase 1.2 estiver estável.
  - Etapa 02 implementada (`work_0024`, `test_0036`): `src/common/safe_io.R`,
    `signatures.R` e `execution_policy.R`. Adoção por `src/collect/` fica para
    um item posterior, depois da coleta das DFP.
  - Riscos `risk_0014` e `risk_0015`.
- **Data P03 (`work_0012`):** extração e consolidação em Parquet implementadas
  (`decision_0026`, `decision_0027`; `test_0035`, `test_0037`–`test_0039`).
  - Rodada local: 250 pacotes, 205 completos, 6.365 notas, em
    `C:\TaxMinerData\financial_disclosures\processed\`.
  - Faltam as tabelas das notas.
  - O catálogo da coleta tem nomes cortados (`risk_0016`), contornado na
    consolidação.

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
`docs/data_sources.md` (retoma de onde parou). Em paralelo, atualizar o Parquet
das notas com `TAXMINER_DATA_DIR=C:/TaxMinerData Rscript --vanilla
scripts/extract_financial_notes.R` (só processa pacotes novos). Com
autorização: aceite da Fase 1.3 pelo desenvolvedor (`work_0023`), depois de usar a
busca; incrementos do `work_0026`. Para atualizar os fundos: coleta
`scripts/collect_fund_reports.R history` e consolidação por família
(`scripts/consolidate_fund_reports.R fidc`; o FIDC usa menos memória em lotes).
Depois da coleta das DFP: `scripts/organize_data_dir.R
dfp`, corrigir a decodificação do índice em `src/collect/` (`risk_0016`) e
rodar a extração com `force`. ITR depende de mais
armazenamento. Fase 1.1 retoma quando o desenvolvedor decidir os
pontos de `docs/feasibility.md`.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`. Não inferir aceites, não fabricar
evidências, não fazer commit ou push sem autorização explícita.
