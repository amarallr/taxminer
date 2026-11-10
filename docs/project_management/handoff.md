# Retomada do TaxMiner

Atualizado: 2026-11-10T18:46:15-03:00. Branch `main`. O histórico completo de
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
- **Fase 1:** Collect P01 executado (`work_0008` em andamento): fontes em
  `docs/source_inventory.md`, estratégia em `docs/feasibility.md`. Nenhum
  documento coletado. Fases 2 e 3 não iniciadas.

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

Desenvolvedor decide os três pontos de `docs/feasibility.md` (uso da API de
busca, opção de texto integral, amostra). Depois: Collect P02 para coletar a
amostra de ementas, com nova autorização.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`. Não inferir aceites, não fabricar
evidências, não fazer commit ou push sem autorização explícita.
