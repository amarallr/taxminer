# TaxMiner — panorama do projeto

**Status:** retrato do momento (situação em 12/11/2026) ·
**Última atualização:** 2026-11-12 ·
**Documentos relacionados:** [README](../README.md) ·
[Estado atual](project_management/project_status.md) ·
[Requisitos](requirements.md) ·
[Arquitetura](architecture.md)

> [!IMPORTANT]
> Projeto independente, não oficial da Receita Federal nem da CVM.

> [!NOTE]
> Este panorama é um retrato do momento; o estado vigente está em
> [`docs/project_management/project_status.md`](project_management/project_status.md).

- **Fases** (`decision_0025`): subfase 1.1 suspensa; 1.2 em andamento; 1.3 implementada e
  testada, com aceite humano pendente; Fase 2 não iniciada.
- **Repositório:** público, `amarallr/taxminer`, licença MIT, CI aprovado.
- **Painel publicado:** [amarallr.github.io/taxminer/app](https://amarallr.github.io/taxminer/app/).
- **Fonte:** registros em [`docs/project_management/`](project_management/).

## Escopo

O TaxMiner pesquisa Soluções de Consulta públicas, notas explicativas de demonstrações
financeiras e informes de fundos de investimento da CVM (FII, FIDC, FIP e FIAGRO). Relações
entre fontes são sempre hipóteses citadas, nunca conclusão de infração.

| Família                      | O que é                                     | Regras principais                                                                                                                                                                    |
| ---------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `tax_consultation_decisions` | Soluções de Consulta da RFB                 | Texto original em português, tipo de documento preservado, ID estável por autoridade, tipo, número e ano.                                                                            |
| `financial_disclosures`      | Notas explicativas                          | Relatório → nota → tabela; CNPJ só quando verificado; escopo consolidado ou individual; unidades e página de origem.                                                                 |
| `investment_fund_reports`    | Informes de fundos (FII, FIDC, FIP, FIAGRO) | Dados abertos da CVM; subfamília, tabela e layout preservados; valores originais como texto; linhagem por arquivo, hash e linha; chaves repetidas diagnosticadas, nunca descartadas. |
| `document_relationships`     | Relações entre fontes                       | Fase 2: só sobre as bases da Fase 1 já aceitas; citações dos dois lados, nível de evidência e revisão humana.                                                                        |

## Roteiro

| Etapa                             | Conteúdo                                                                                                                                                                                                                                                | Situação                         |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Common P02 — Fundação             | Ambiente R, `renv`, Git, GitHub e exclusões das áreas protegidas                                                                                                                                                                                        | ✅ aprovado                       |
| Common P03 — Arquitetura          | Contratos por fonte, limiares de qualidade e dicionário de dados                                                                                                                                                                                        | ✅ aprovado                       |
| Fase 1.1 — Soluções de Consulta   | Fontes verificadas; decisões de coleta em aberto                                                                                                                                                                                                        | ⏸️ suspensa                      |
| Fase 1.2 — Notas explicativas     | Coleta das DFP da CVM em andamento (2.774 de 14.010 entregas em 12/11); extração das notas incremental (885 pacotes processados); tabelas das notas ainda não extraídas; ITR depois                                                                     | ▶️ em andamento                  |
| Fase 1.3 — Fundos de investimento | 102 arquivos da CVM coletados; 12,16 milhões de linhas em Parquet; busca e painel no app local (Panorama, Administradores, Fundos, FIDC, Cedentes, FII, FIP, FIAGRO, Ficha); painel publicado com 11.879 fundos e todas as tabelas do FIDC (`req_0020`) | ✅ implementada · aceite pendente |
| Fase 2 — Inteligência cruzada     | Relações entre as bases da Fase 1 já aceitas, como hipóteses com evidências e revisão humana                                                                                                                                                            | ⏸️ não iniciada                  |

## Itens de trabalho

31 registrados: 18 implementados, 3 em andamento, 1 bloqueado (suspenso) e 9 não iniciados;
8 com aceite humano.

> [!IMPORTANT]
> Nenhum item foi liberado em release nem está em operação.

| ID                                    | Item                                                       | Implementação | Teste         | Aceite   |
| ------------------------------------- | ---------------------------------------------------------- | ------------- | ------------- | -------- |
| **Common**                            |                                                            |               |               |          |
| `work_0001`                           | Fundação local e exclusões protegidas                      | implementado  | aprovado      | aprovado |
| `work_0002`                           | Arquitetura por fonte e critérios das fases                | implementado  | não executado | aprovado |
| `work_0003`                           | Git e GitHub                                               | implementado  | aprovado      | aprovado |
| `work_0004`                           | Codex                                                      | implementado  | aprovado      | aprovado |
| `work_0005`                           | Claude Code                                                | implementado  | aprovado      | aprovado |
| `work_0006`                           | Gemini CLI                                                 | implementado  | aprovado      | aprovado |
| `work_0007`                           | GitHub Copilot                                             | implementado  | aprovado      | aprovado |
| `work_0018`                           | Revisão de consistência do projeto                         | implementado  | aprovado      | aprovado |
| `work_0019`                           | Novas fontes: inventário e lacunas (Common P07)            | implementado  | não se aplica | pendente |
| `work_0024`                           | Rotinas comuns em `src/common/`                            | implementado  | aprovado      | pendente |
| `work_0025`                           | Dados locais organizados por família (`TAXMINER_DATA_DIR`) | em andamento  | aprovado      | pendente |
| **Fase 1.1 — Soluções de Consulta**   |                                                            |               |               |          |
| `work_0008`                           | Descobrir fontes e coletar a amostra                       | bloqueado     | aprovado      | pendente |
| `work_0009`                           | Extrair e consolidar                                       | não iniciado  | não executado | pendente |
| `work_0010`                           | Busca independente                                         | não iniciado  | não executado | pendente |
| `work_0015`                           | Aceite humano da Fase 1.1                                  | não iniciado  | não executado | pendente |
| **Fase 1.2 — Notas explicativas**     |                                                            |               |               |          |
| `work_0011`                           | Descobrir fontes e coletar relatórios                      | em andamento  | aprovado      | pendente |
| `work_0012`                           | Extrair notas e tabelas                                    | em andamento  | aprovado      | pendente |
| `work_0026`                           | Plano de processamento híbrido de documentos               | não iniciado  | não executado | pendente |
| `work_0013`                           | Busca independente de notas                                | não iniciado  | não executado | pendente |
| `work_0016`                           | Aceite humano da Fase 1.2                                  | não iniciado  | não executado | pendente |
| **Fase 1.3 — Fundos de investimento** |                                                            |               |               |          |
| `work_0020`                           | Verificar fontes e coletar os informes                     | implementado  | aprovado      | pendente |
| `work_0021`                           | Consolidar informes por família e layout                   | implementado  | aprovado      | pendente |
| `work_0022`                           | Busca independente de fundos                               | implementado  | aprovado      | pendente |
| `work_0027`                           | Painel analítico dos fundos                                | implementado  | aprovado      | pendente |
| `work_0028`                           | Resolução central de entidades e denominações              | implementado  | aprovado      | pendente |
| `work_0029`                           | Diagnóstico e plano da plataforma de BI                    | implementado  | não se aplica | pendente |
| `work_0030`                           | Panorama com filtros cruzados                              | implementado  | aprovado      | pendente |
| `work_0031`                           | Painel de fundos e site publicado (Cedentes, Ficha, FIDC)  | implementado  | aprovado      | pendente |
| `work_0023`                           | Aceite humano da Fase 1.3                                  | não iniciado  | não executado | pendente |
| **Fase 2 — Inteligência cruzada**     |                                                            |               |               |          |
| `work_0014`                           | Relações citadas entre as fontes                           | não iniciado  | não executado | pendente |
| `work_0017`                           | Aceite humano da Fase 2                                    | não iniciado  | não executado | pendente |

## Riscos (11 abertos e 1 aceito, de 17)

| Impacto | Risco                                  | Detalhe                                                                                                                          |
| ------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| alto    | Áreas protegidas no OneDrive           | **Aceito** pelo desenvolvedor: `.restricted/` e `.tmp/` seguem sincronizadas; agentes sem acesso (`risk_0017`, `decision_0040`). |
| alto    | Sincronização do OneDrive              | Exclusões das áreas protegidas não verificadas; checkout mantido no OneDrive por escolha (`risk_0002`).                          |
| alto    | Notas só nos pacotes RAD/ENET          | Fora dos dados abertos ODbL; RAD sem `robots.txt` nem licença declarada; PDF gerado com preenchimento (`risk_0012`).             |
| alto    | Texto integral recusado à automação    | O visualizador oficial respondeu 403; a API de busca não é documentada (`risk_0011`).                                            |
| alto    | Cobertura das fontes                   | Ementas acessíveis; termos de uso e completude histórica em aberto (`risk_0001`).                                                |
| alto    | Identificação de empresas              | CNPJ ambíguo e relações inferidas podem ser incertos (`risk_0005`).                                                              |
| médio   | Catálogo das DFP em Latin-1            | O catálogo grava nomes de empresas truncados; a consolidação das notas corrige as linhas e lê o nome do índice (`risk_0016`).    |
| médio   | Escopo das novas fontes                | Fundos (Fase 1.3) disputam atenção com a Fase 1.2; nada muda em `src/collect/` durante a coleta (`risk_0015`).                   |
| médio   | Licença da implementação de referência | Sem LICENSE; nenhum código copiado, só reimplementação (`risk_0014`).                                                            |
| médio   | Volume da coleta                       | Acervo completo (~450 GB) maior que o disco; DFP primeiro, ITR depois (`risk_0013`).                                             |
| médio   | `testthat` compilado no R 4.5.3        | Aviso só local; o CI usa binário compatível (`risk_0007`).                                                                       |
| médio   | ZIP histórico dos prompts              | Não tem as correções; os arquivos avulsos valem (`risk_0006`).                                                                   |

## Próximos passos

1. **Aceite humano da Fase 1.3:** roteiro de conferência
   (`docs/project_management/acceptance_phase_1_3.md`, a preparar) com os critérios do
   `acc_0003`; o desenvolvedor decide aprovado, aprovado com ressalvas ou rejeitado.
2. **Fase 1.2:** concluir a coleta das DFP (retomável, em execução) e a extração das notas,
   que roda de forma incremental junto com a coleta; depois, as tabelas das notas.
3. **Busca de notas:** Parquet e área própria no Shiny.
4. **Plano de BI** ([`docs/bi_platform_plan.md`](bi_platform_plan.md)): comparador de fundos e
   sinais de anomalia nas séries, quando o desenvolvedor priorizar.

Adiados por escolha do desenvolvedor: atualizar o R, tirar o projeto do OneDrive e retomar a
Fase 1.1. A refatoração dos prompts fica para a versão 1.1.

## Critérios de aceite das fases (aprovados)

| Medida                                          | Limiar                                 |
| ----------------------------------------------- | -------------------------------------- |
| Contabilização da descoberta                    | 100% com resultado final               |
| Integridade dos downloads                       | 100% com SHA-256 e URL                 |
| Cobertura dos campos extraídos                  | ≥ 99%                                  |
| Reprodutibilidade                               | 100% idêntico em duas execuções        |
| Relevância da busca (30 consultas por base)     | Precision@10 ≥ 0,90 · Recall@10 ≥ 0,80 |
| Citações corretas                               | 100%                                   |
| Latência da busca local                         | p95 ≤ 2 s                              |
| Precisão das relações (≥ 50 vínculos revisados) | ≥ 0,90                                 |

Detalhes em [`docs/requirements.md`](requirements.md).

## Ambiente

- **R e IDE:** R 4.5.1 · RStudio 2024.04.0.
- **Dependências e testes:** `renv` com snapshot explícito · `testthat` 3.3.2 · validação
  local 5/5 · GitHub Actions com restauração limpa aprovada.
- **Ferramentas:** Git 2.55 · `gh` 2.103 · Codex, Claude Code, Gemini CLI e Copilot testados no
  RStudio.

> [!WARNING]
> As pastas `.restricted/` e `.tmp/` são locais, sigilosas e nunca são lidas, compartilhadas
> nem publicadas.
