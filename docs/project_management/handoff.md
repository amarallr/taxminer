# Retomada do TaxMiner

Atualizado: 2026-11-10T17:32:29-03:00. Branch `main`; último commit `b0ed621`.
Há alterações locais não commitadas (revisão de 2026-11-10; ver
`review_update_plan.md`). O histórico completo de retomadas está em
`handoff_history.md`.

## Estado atual

- **Common P02 (setup):** `work_0001` e `work_0003` implementados, testados e
  aprovados (`acc_0001`, `acc_0002`). Release `not_released`; operações
  `not_started`.
- **Assistentes (`work_0004`–`work_0007`):** testes isolados aprovados; smoke
  test integrado no terminal do RStudio ainda não executado; aceite pendente.
- **Common P03 (`work_0002`):** arquitetura, requisitos e dicionário em
  rascunho, com propostas concretas para as pendências da revisão anterior em
  `docs/architecture.md`. `req_0003` continua `proposed`.
- **MVPs (fases 1–3):** não iniciados. Nenhuma fonte foi coletada.

## Validação

```powershell
Rscript --vanilla scripts/validate_environment.R
```

Último resultado: código 0, 5 verificações aprovadas (`test_0020`). O aviso de
`testthat` compilado no R 4.5.3 permanece.

## Decisões pendentes do desenvolvedor

1. Aceitar ou rejeitar `req_0003`, os limiares de `docs/requirements.md` e as
   propostas de arquitetura.
2. Escolher a licença do repositório público.
3. Exceção `doit` (`risk_0010`): de preferência, mover `doit.txt` para fora de
   `tmp/` e restaurar `Read(./tmp/**)` em `.claude/settings.json`.
4. Autorizar o commit e o push das alterações locais.
5. R 4.5.3+, destino do `renv` e checkout fora do OneDrive (ver plano).

## Próxima ação técnica

Após a decisão 1: executar `prompts/collect_p01_official_source_discovery.txt`
apenas para verificar fontes e termos de uso, sem coleta em massa.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`, exceto a leitura de `tmp/doit.txt`
definida em `AGENTS.md`. Não inferir aceites, não fabricar evidências, não
fazer commit ou push sem autorização explícita.
