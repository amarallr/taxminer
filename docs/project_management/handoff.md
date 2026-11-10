# Retomada do TaxMiner

Atualizado: 2026-11-10T17:46:38-03:00. Branch `main`. O histórico completo de
retomadas está em `handoff_history.md`; a revisão e sua execução, em
`review_update_plan.md`.

## Estado atual

- **Common P02 (setup):** `work_0001` e `work_0003` aprovados (`acc_0001`,
  `acc_0002`). Release `not_released`; operações `not_started`.
- **Common P03 (`work_0002`):** arquitetura, requisitos com limiares e
  dicionário aprovados (`acc_0003`); `req_0003` `accepted`.
- **Assistentes (`work_0004`–`work_0007`):** testes isolados aprovados; smoke
  test integrado no terminal do RStudio ainda não executado; aceite pendente.
- **Repositório:** licença MIT; CI `validate_environment` no GitHub Actions;
  commits futuros com e-mail noreply (configuração local).
- **MVPs (fases 1–3):** não iniciados. Nenhuma fonte foi coletada.

## Validação

```powershell
Rscript --vanilla scripts/validate_environment.R
```

O aviso de `testthat` compilado no R 4.5.3 permanece (R local 4.5.1, por
escolha do desenvolvedor).

## Pendências

1. Desenvolvedor pode apagar `tmp/doit.txt`; o `doit` agora usa
   `.claude/doit.txt` (ignorado pelo Git).
2. Adiados por escolha do desenvolvedor: atualização do R e checkout fora do
   OneDrive (`risk_0002`, `risk_0007`).
3. Refatoração do texto repetido dos prompts: pacote 1.1.

## Próxima ação técnica

Executar `prompts/collect_p01_official_source_discovery.txt` apenas para
verificar fontes públicas e termos de uso das Soluções de Consulta, sem coleta
em massa. Requer autorização da etapa.

## Regras permanentes

Nunca acessar `restricted/` nem `tmp/`. Não inferir aceites, não fabricar
evidências, não fazer commit ou push sem autorização explícita.
