# TaxMiner — panorama do projeto

Projeto independente, não oficial da Receita Federal. Situação em 10/11/2026
(após a conclusão dos assistentes). Repositório público `amarallr/taxminer`, licença MIT,
CI aprovado. Fonte: registros em `docs/project_management/`.

## Escopo

O TaxMiner pesquisa Soluções de Consulta públicas e notas explicativas de
demonstrações financeiras. Relações entre as duas fontes são sempre hipóteses
citadas, nunca conclusão de infração.

| Família | O que é | Regras principais |
|---|---|---|
| `tax_consultation_decisions` | Soluções de Consulta da RFB | Texto original em português, tipo de documento preservado, ID estável por autoridade, tipo, número e ano. |
| `financial_disclosures` | Notas explicativas | Relatório → nota → tabela; CNPJ só quando verificado; escopo consolidado ou individual; unidades e página de origem. |
| `document_relationships` | Relações entre fontes | Só sobre as duas bases aceitas; citações dos dois lados, nível de evidência e revisão humana. |

## Roteiro

| Etapa | Conteúdo | Situação |
|---|---|---|
| Common P02 — Fundação | Ambiente R, renv, Git, GitHub e exclusões das áreas protegidas | ✅ aprovado |
| Common P03 — Arquitetura | Contratos por fonte, limiares de qualidade e dicionário de dados | ✅ aprovado |
| Fase 1 — Soluções de Consulta | Fontes, amostra de até 100 atos, Parquet e busca no Shiny | ▶️ próxima |
| Fase 2 — Notas explicativas | Coleta, extração e busca próprias, sem depender da Fase 1 | ⏸️ não iniciada |
| Fase 3 — Inteligência cruzada | Relações citadas entre as duas bases já aceitas | ⏸️ não iniciada |

## Itens de trabalho

18 registrados: 8 implementados e 10 não iniciados; 3 com aceite
humano. Nenhum foi liberado em release nem está em operação.

| ID | Item | Implementação | Teste | Aceite |
|---|---|---|---|---|
| **Common** | | | | |
| work_0001 | Fundação local e exclusões protegidas | implementado | aprovado | aprovado |
| work_0002 | Arquitetura por fonte e critérios das fases | implementado | não executado | aprovado |
| work_0003 | Git e GitHub | implementado | aprovado | aprovado |
| work_0004 | Codex | implementado | aprovado | pendente |
| work_0005 | Claude Code | implementado | aprovado | pendente |
| work_0006 | Gemini CLI | implementado | aprovado | pendente |
| work_0007 | GitHub Copilot | implementado | aprovado | pendente |
| work_0018 | Revisão de consistência do projeto | implementado | aprovado | pendente |
| **Fase 1** | | | | |
| work_0008 | Descobrir fontes e coletar a amostra | não iniciado | não executado | pendente |
| work_0009 | Extrair e consolidar | não iniciado | não executado | pendente |
| work_0010 | Busca independente | não iniciado | não executado | pendente |
| work_0015 | Aceite humano da Fase 1 | não iniciado | não executado | pendente |
| **Fase 2** | | | | |
| work_0011 | Descobrir fontes e coletar relatórios | não iniciado | não executado | pendente |
| work_0012 | Extrair notas e tabelas | não iniciado | não executado | pendente |
| work_0013 | Busca independente de notas | não iniciado | não executado | pendente |
| work_0016 | Aceite humano da Fase 2 | não iniciado | não executado | pendente |
| **Fase 3** | | | | |
| work_0014 | Relações citadas entre as fontes | não iniciado | não executado | pendente |
| work_0017 | Aceite humano da Fase 3 | não iniciado | não executado | pendente |

## Riscos abertos (5 de 10)

| Impacto | Risco | Detalhe |
|---|---|---|
| alto | Fontes públicas não verificadas | Disponibilidade, termos de uso e cobertura histórica desconhecidos (risk_0001). |
| alto | Sincronização do OneDrive | Exclusões das áreas protegidas não verificadas; checkout mantido no OneDrive por escolha (risk_0002). |
| alto | Identificação de empresas | CNPJ ambíguo e relações inferidas podem ser incertos (risk_0005). |
| médio | testthat compilado no R 4.5.3 | Aviso só local; o CI usa binário compatível (risk_0007). |
| médio | ZIP histórico dos prompts | Não tem as correções; os arquivos avulsos valem (risk_0006). |

## Próximos passos

1. **Collect P01:** verificar onde estão as Soluções de Consulta e os termos de
   uso, sem coleta em massa. Precisa de autorização da etapa.
2. **Amostra da Fase 1:** até 100 atos públicos com manifesto, hash SHA-256 e
   resultado documento a documento.
3. **Extração, Parquet e busca:** Data P01/P02 e Intelligence P02, com Shiny
   local e citação da fonte oficial.

Adiados por escolha do desenvolvedor: atualizar o R e tirar o projeto do
OneDrive. A refatoração dos prompts fica para a versão 1.1.

## Critérios de aceite das fases (aprovados)

| Medida | Limiar |
|---|---|
| Contabilização da descoberta | 100% com resultado final |
| Integridade dos downloads | 100% com SHA-256 e URL |
| Cobertura dos campos extraídos | ≥ 99% |
| Reprodutibilidade | 100% idêntico em duas execuções |
| Relevância da busca (30 consultas por base) | Precision@10 ≥ 0,90 · Recall@10 ≥ 0,80 |
| Citações corretas | 100% |
| Latência da busca local | p95 ≤ 2 s |
| Precisão das relações (≥ 50 vínculos revisados) | ≥ 0,90 |

Detalhes em `docs/requirements.md`.

## Ambiente

R 4.5.1 · RStudio 2024.04.0 · renv com snapshot explícito · testthat 3.3.2 ·
validação local 5/5 · GitHub Actions com restauração limpa aprovada ·
Git 2.55 · gh 2.103 · Codex, Claude Code, Gemini CLI e Copilot testados no RStudio.

As pastas `restricted/` e `tmp/` são locais e nunca são lidas nem publicadas.
Este panorama é um retrato do momento; o estado vigente está em
`docs/project_management/project_status.md`.
