# TaxMiner — Mineração e Inteligência de Documentos Tributários e Financeiros

**Transformando documentos públicos em conhecimento estruturado, pesquisável e verificável.**

[Página do projeto](https://amarallr.github.io/taxminer/) ·
[Arquitetura](docs/architecture.md) ·
[Requisitos](docs/requirements.md) ·
[Estado atual](docs/project_management/project_status.md) ·
[Licença MIT](LICENSE)

> Projeto independente e de código aberto. **Não é um serviço oficial da
> Receita Federal do Brasil** nem tem vinculação institucional com o órgão
> ou com a CVM.

## 1. Apresentação

O TaxMiner é um projeto independente e de código aberto para coletar,
organizar, processar e analisar documentos públicos de natureza tributária,
contábil e financeira.

Órgãos públicos e empresas divulgam um grande volume de informações
relevantes, mas esse conhecimento fica espalhado por plataformas, documentos,
formatos e períodos diferentes. O TaxMiner combina engenharia de dados,
processamento de documentos, mecanismos de pesquisa e técnicas de
inteligência artificial para transformar esses documentos, em geral não
estruturados ou semiestruturados, em bases de conhecimento organizadas,
rastreáveis e acessíveis.

## 2. Visão geral

| | |
|---|---|
| **O que é** | Um conjunto de pipelines em R e uma interface local de pesquisa (prevista) sobre documentos públicos. |
| **Para quem** | Desenvolvedores, profissionais de dados, pesquisadores, contadores, auditores, tributaristas e analistas financeiros e de riscos. |
| **Escopo** | Soluções de Consulta da Receita Federal, notas explicativas das demonstrações financeiras entregues à CVM e informes de fundos de investimento da CVM (FII, FIDC, FIP e FIAGRO). |
| **Princípio central** | Toda informação mantém o vínculo com o documento oficial de origem: URL, data de obtenção, hash e página. |
| **Estágio** | Em desenvolvimento. Nenhum MVP foi concluído ou liberado; veja a [seção 11](#11-estado-atual-do-desenvolvimento). |

## 3. Problema que o projeto pretende resolver

- **Dispersão.** Interpretações tributárias e divulgações contábeis ficam em
  portais diferentes, cada um com sua forma de busca, seus formatos e sua
  própria cobertura histórica.
- **Formatos difíceis.** Boa parte do conteúdo está em PDF ou em pacotes
  XML/ZIP, com tabelas, cabeçalhos e numeração que dificultam a extração
  automática.
- **Pesquisa histórica limitada.** Comparar um assunto ao longo de vários
  anos, empresas ou unidades emissoras exige trabalho manual e repetitivo.
- **Cruzamento trabalhoso.** Relacionar o que uma empresa divulga com a
  interpretação oficial da legislação exige localizar e ler os dois lados com
  as citações corretas.

## 4. Objetivos

1. Adquirir documentos públicos de forma controlada, legal e reprodutível,
   com registro de proveniência e integridade.
2. Estruturar o conteúdo, preservando o texto original e as classificações
   oficiais, em formatos analíticos abertos (Parquet).
3. Oferecer pesquisa textual e, depois, semântica, com citação da fonte e da
   página em cada resultado.
4. Apoiar análises que relacionem as fontes, sempre como hipóteses com
   evidências e sujeitas a revisão humana.
5. Medir qualidade com critérios explícitos (cobertura, reprodutibilidade,
   relevância e citações) antes de declarar qualquer fase concluída.

## 5. Fontes documentais

### 5.1 Soluções de Consulta tributárias (`tax_consultation_decisions`)

**O que são.** A Solução de Consulta é a resposta formal da Receita Federal a
uma dúvida de um contribuinte sobre como aplicar a legislação tributária a
uma situação concreta. A Solução de Consulta emitida pela Coordenação-Geral
de Tributação (Cosit) vincula a administração tributária e orienta casos
semelhantes, por isso é uma fonte importante para entender a interpretação
oficial da lei.

**Como são publicadas e identificadas.** Cada ato tem tipo (Solução de
Consulta, Solução de Consulta Interna, Solução de Divergência…), unidade
emissora, número, ano, data de publicação e uma ementa que resume o assunto,
a conclusão e os dispositivos legais. A publicação é feita no Diário Oficial e
no sistema Normas da Receita Federal.

**Dificuldades.** A busca oficial é feita ato a ato. A verificação de fontes
(Collect P01) mostrou que ementas e metadados são acessíveis, mas o texto
integral **recusa acesso automatizado (HTTP 403)**, e o projeto não contorna
controles de acesso. Detalhes em [`docs/source_inventory.md`](docs/source_inventory.md)
e [`docs/feasibility.md`](docs/feasibility.md).

**Potencial (previsto).** Classificação por tributo, assunto, dispositivo
legal, unidade emissora e período, com pesquisa histórica.

**O que se preserva.** Autoridade emissora, tipo documental original (sem
equiparar tipos diferentes), número, ano e texto original em português. O
identificador é estável e derivado desses campos.

### 5.2 Demonstrações financeiras e notas explicativas (`financial_disclosures`)

**O que são.** As demonstrações financeiras (balanço patrimonial, resultado,
fluxo de caixa, mutações do patrimônio líquido e valor adicionado) mostram a
posição e o desempenho de uma empresa. As **notas explicativas** detalham
esses números: políticas contábeis, composição de saldos, tributos,
contingências, partes relacionadas, eventos subsequentes e outros fatos
relevantes.

**Por que a CVM.** Companhias abertas entregam à CVM as Demonstrações
Financeiras Padronizadas (DFP, anuais) e as Informações Trimestrais (ITR). A
verificação de fontes (Collect P04) mostrou que:

- os **dados abertos da CVM** (licença ODbL) trazem o índice das entregas e
  os demonstrativos em CSV, **mas não as notas explicativas**;
- as notas estão no **pacote de cada entrega** no sistema RAD/ENET, como PDF
  anexado pela própria companhia dentro de um XML.

**Dificuldades.** O formato dos pacotes muda ao longo dos anos; alguns PDFs
não têm camada de texto; um mesmo PDF pode trazer mais de um conjunto de
notas (individual e consolidado); a escala monetária costuma aparecer só no
cabeçalho; tabelas são difíceis de extrair com fidelidade.

**O que se preserva.** Empresa (CNPJ e código CVM verificados), período de
referência, versão da entrega, escopo contábil (individual ou consolidado,
quando declarado), unidade de medida, página de origem e hash do documento.

**Potencial (previsto).** Análises históricas, financeiras, contábeis e
tributárias sobre o que as empresas divulgam.

Detalhes em [`docs/data_sources.md`](docs/data_sources.md).

### 5.3 Informes de fundos de investimento (`investment_fund_reports`)

**O que são.** Informes periódicos que os fundos entregam à CVM, divididos em
quatro subfamílias:

- **FII**, fundos imobiliários: informes mensal, trimestral e anual, mais o
  índice de demonstrações financeiras;
- **FIDC**, fundos de direitos creditórios: informe mensal;
- **FIP**, fundos de participações: informe trimestral até 2023 e
  quadrimestral desde 2024;
- **FIAGRO**, fundos das cadeias agroindustriais: informe mensal desde 2025.

**Por que a CVM.** Os informes são publicados como arquivos ZIP e CSV no portal
de dados abertos da CVM. As listagens das quatro subfamílias foram verificadas
em 10/11/2026 (`decision_0024`). Licenças, dicionários e conteúdo ainda serão
verificados na Collect P05.

**Dificuldades.** Os layouts das tabelas mudam ao longo do tempo. Os arquivos
recentes são republicados. Há chaves repetidas e reenvios, e no FIP a
periodicidade mudou.

**O que se preserva.** Subfamília, conjunto e tabela oficiais, versão do layout,
período de referência, CNPJ do fundo (original e normalizado), valores
originais como texto e a linhagem até o arquivo, o hash e a linha.

**Potencial (previsto).** Pesquisa e análise histórica dos fundos, como fonte
independente: não depende das Soluções de Consulta nem das notas explicativas.

## 6. Arquitetura e módulos

O código fica em um único repositório, com módulos lógicos em `src/`. Cada
família documental tem esquema, proveniência, cobertura e qualidade
próprios; a pesquisa de notas explicativas funciona sem depender das
Soluções de Consulta.

| Módulo | Responsabilidade | Situação |
|---|---|---|
| **TaxMiner Collect** (`src/collect/`) | Descoberta de fontes, identificação dos documentos, download controlado com espera entre requisições, hash SHA-256, manifesto de proveniência, tratamento de falhas, retomada e controle de cobertura. | Implementado para as entregas da CVM; coleta das DFP em andamento. |
| **TaxMiner Data** (`src/data/`) | Extração de texto e metadados, segmentação das notas, tabelas, padronização de campos, preservação do original, identificação de entidades, consolidação histórica em Parquet, qualidade e reprodutibilidade. | Extração das notas em desenvolvimento; tabelas e Parquet ainda não implementados. |
| **TaxMiner Intelligence** (`src/intelligence/`) | Pesquisa textual e semântica, recuperação de trechos, apoio de modelos de linguagem, relações entre documentos, evidências e citações, revisão humana e controle de respostas sem fundamento. | Não iniciado. |
| **TaxMiner Common** | Configuração, validação do ambiente, logging, governança, testes e segurança compartilhados. | Fundação implementada (validador, CI, registros de gestão); `src/common/` será criado quando houver código compartilhado. |

Decisões aceitas (`acc_0003`): Parquet gravado com `arrow` e consultado com
`duckdb`; uma única aplicação Shiny local, com uma área independente por fase;
identificadores estáveis com regra de fallback; identificação de empresas
tipada por esquema (CNPJ, código CVM ou apenas nome, sem forçar
correspondências). Veja [`docs/architecture.md`](docs/architecture.md) e o
[dicionário de dados](docs/data_dictionary.md).

## 7. Fluxo de processamento

```text
Fontes documentais
  Soluções de Consulta (RFB)  |  Demonstrações financeiras e notas (CVM)
        │
        ▼
TaxMiner Collect   descoberta → aquisição → integridade → proveniência
        │          (manifesto, SHA-256, retomada; originais imutáveis)
        ▼
TaxMiner Data      extração → tratamento → estruturação → consolidação
        │          (texto original + metadados; Parquet versionado)
        ▼
TaxMiner Intelligence  pesquisa textual → pesquisa semântica →
        │              relações documentais → análise assistida
        ▼
Conhecimento verificável: resultados com fonte, página, evidência e revisão humana
```

O projeto está organizado em duas fases (`decision_0025`). Cada subfase e
cada fase tem seu próprio aceite humano:

1. **Fase 1 — Coleta, estruturação e pesquisa de dados.** Tem três subfases
   independentes; nenhuma depende das outras.
   - **1.1 Soluções de Consulta:** coleta, processamento e pesquisa própria.
   - **1.2 Notas explicativas:** coleta, processamento e pesquisa própria.
   - **1.3 Fundos de investimento:** coleta, consolidação e pesquisa própria
     dos informes de FII, FIDC, FIP e FIAGRO.
2. **Fase 2 — Inteligência cruzada:** relações entre as bases, sempre como
   hipóteses com evidências e revisão humana, depois que elas forem aceitas.

## 8. Funcionalidades previstas

Itens marcados ✅ já existem; os demais estão **previstos** e ainda não
foram implementados.

- ✅ Verificação documentada das fontes oficiais, com termos, limites e cobertura.
- ✅ Catálogo das entregas DFP/ITR da CVM e download retomável com manifesto
  e SHA-256 por arquivo do pacote.
- 🔧 Extração das notas explicativas com número, título, páginas e escala
  monetária (em desenvolvimento: 66 de 83 pacotes completos numa rodada local,
  ainda sem Parquet).
- ✅ Rotinas comuns de confiabilidade em `src/common/` (gravação validada com
  rollback, caminhos contidos, assinaturas e política de execução).
- Extração de tabelas das notas, com unidade e período.
- Bases Parquet de relatórios, notas e tabelas, com linhagem até o documento.
- Pesquisa textual por empresa, CNPJ, período, tipo de relatório e nota.
- Pesquisa de Soluções de Consulta por tributo, assunto e dispositivo legal.
- Pesquisa semântica e recuperação de trechos com citação.
- Relações entre as bases como hipóteses com evidências e revisão humana (Fase 2).
- Bases de informes de fundos (FII, FIDC, FIP, FIAGRO) consolidadas por tabela e layout, com linhagem até o arquivo e a linha.
- Pesquisa de fundos por família, CNPJ do fundo, administrador e período.
- Interface Shiny local com uma área por subfase e pela inteligência cruzada.

## 9. Aplicações práticas

Aplicações **possíveis** quando as funcionalidades previstas existirem:

- **Pesquisa tributária:** localizar Soluções de Consulta sobre um tributo,
  uma operação ou um dispositivo legal.
- **Análise contábil e financeira:** pesquisar o que as empresas divulgam em
  notas explicativas (por exemplo, contingências tributárias ou partes
  relacionadas).
- **Estudos históricos:** comparar assuntos e divulgações ao longo de
  diferentes exercícios.
- **Análise exploratória de riscos:** identificar padrões e inconsistências
  aparentes que mereçam investigação adicional por um profissional.
- **Pesquisa acadêmica:** usar dados estruturados, documentados e rastreáveis.
- **Inteligência documental:** relacionar informações de fontes diferentes
  com evidências explícitas dos dois lados.

## 10. Inteligência artificial com rastreabilidade e responsabilidade

Processamento de linguagem natural, pesquisa semântica e modelos de
linguagem **poderão** ajudar a localizar trechos relevantes, agrupar assuntos
e resumir documentos. A coleta, a extração e a pesquisa determinística não
dependem de modelos de IA; o uso de serviços externos de IA exige revisão de
privacidade e autorização própria.

Princípios:

1. Toda informação relevante mantém vínculo com a fonte original.
2. Respostas de IA não substituem documentos oficiais.
3. Relações identificadas entre documentos são hipóteses analíticas.
4. Semelhança entre documentos não comprova infração.
5. Os resultados devem permitir revisão humana.
6. O sistema não produz conclusões jurídicas ou fiscais automáticas sem
   fundamento verificável.
7. Incertezas e limitações são explicitadas.

## 11. Estado atual do desenvolvimento

Fonte: [`docs/project_management/`](docs/project_management/) (situação em
10/11/2026). Implementação, teste, aceite humano, release e operação são
acompanhados separadamente.

| Etapa | Situação |
|---|---|
| Fundação (ambiente R, renv, Git, GitHub, CI, áreas protegidas) | Implementada, testada e aceita. |
| Arquitetura, requisitos e critérios de aceite | Aceitos (`acc_0003`). |
| Assistentes (Codex, Claude Code, Gemini CLI, GitHub Copilot) | Testados no RStudio e aceitos. |
| Fase 1.1 — Soluções de Consulta | **Suspensa** por decisão do desenvolvedor, com as fontes já verificadas. |
| Fase 1.2 — Notas explicativas | **Em andamento:** fontes verificadas; pipeline de coleta implementado e testado; coleta das 14.015 entregas DFP (2010–2026) em execução; extração das notas em desenvolvimento. |
| Fase 1.3 — Fundos de investimento | **Planejada** (`decision_0024`): listagens da CVM verificadas; coleta não autorizada. |
| Fase 2 — Inteligência cruzada | Não iniciada. |

Itens de trabalho: 24 registrados, sendo 10 implementados, 2 em andamento,
1 suspenso e 11 não iniciados. Há 8 aceites humanos. **Nenhum MVP foi
concluído, liberado em release ou colocado em operação.** Riscos e próximos
passos estão em [`project_status.md`](docs/project_management/project_status.md),
[`handoff.md`](docs/project_management/handoff.md) e no
[panorama](docs/project_overview.md).

## 12. Tecnologias e ambiente

- **Linguagem:** R 4.5.1 (ambiente verificado: Windows e RStudio
  2024.04.0+735).
- **Dependências:** `renv` (snapshot explícito) e `testthat`, declaradas em
  `DESCRIPTION`; versões e dependências transitivas em `renv.lock`.
  Bibliotecas de PDF, XML, Parquet e Shiny entram no `DESCRIPTION` somente
  quando o código que as usa for aceito.
- **Ferramentas de sistema:** `curl` (incluído no Windows 10 ou superior).
- **Integração contínua:** GitHub Actions restaura o `renv.lock` e roda o
  validador no Windows (`.github/workflows/validate_environment.yml`).
- **Página do projeto:** GitHub Pages publicado a partir de `site/`
  (`.github/workflows/pages.yml`).

## 13. Instalação e configuração

Abra `taxminer.Rproj` no RStudio e use a raiz do projeto como diretório do
terminal. O projeto desativa a restauração e o salvamento do workspace, o
histórico e a indexação de código.

O bootstrap usa somente pacotes já instalados, sem descoberta recursiva de
dependências:

```powershell
Rscript --vanilla scripts/inspect_environment.R
Rscript --vanilla scripts/setup_environment.R
```

Para restaurar em outro ambiente, inicialize os caminhos locais definidos em
`.Rprofile` e execute `renv::restore(prompt = FALSE)`. Isso exige rede e
acesso ao CRAN. A restauração limpa foi validada no GitHub Actions.

O GitHub CLI está instalado por usuário em
`%LOCALAPPDATA%/Programs/TaxMiner/github_cli/bin/gh.exe` (no PATH do
usuário). Veja [`docs/github_setup.md`](docs/github_setup.md) e
[`docs/development_environment.md`](docs/development_environment.md).

## 14. Execução e validação

Validação do ambiente e dos testes (ambiente e coleta financeira, com
fixtures públicas e sintéticas):

```powershell
Rscript --vanilla scripts/validate_environment.R
```

No Windows, o validador normaliza `LC_CTYPE` para UTF-8 somente no próprio
processo R; avisos de inicialização sobre outras categorias de locale podem
continuar aparecendo. Nenhuma variável global ou de usuário é alterada. O
helper `source("scripts/validate_rstudio_terminal.R")` continua disponível no
console R do RStudio.

Coleta das entregas da CVM (retomável; os dados ficam em uma pasta local
**fora do OneDrive e do repositório**):

```powershell
$env:TAXMINER_DATA_DIR = 'C:\TaxMinerData'
Rscript --vanilla scripts/collect_financial_reports.R dfp 2010-2026 Inf
```

Verificação das fontes (requisições pequenas e espaçadas):

```powershell
Rscript --vanilla scripts/probe_sources.R            # Soluções de Consulta
Rscript --vanilla scripts/probe_financial_sources.R  # CVM
```

## 15. Estrutura de diretórios

| Caminho | Conteúdo |
|---|---|
| `src/collect/` | Descoberta e download das entregas da CVM. |
| `src/data/` | Extração das notas explicativas (em desenvolvimento). |
| `scripts/` | Diagnóstico, bootstrap, validação, verificação de fontes e coleta. |
| `config/` | Registro das fontes financeiras verificadas. |
| `tests/testthat/`, `tests/fixtures/` | Testes automatizados e fixtures públicas ou sintéticas. |
| `docs/` | Arquitetura, requisitos, dicionário de dados, fontes e ambiente. |
| `docs/project_management/` | Itens de trabalho, testes, aceites, riscos, decisões e retomada. |
| `prompts/` | Instruções por etapa (pacote 1.0); os arquivos avulsos são a referência. |
| `site/` | Página publicada no GitHub Pages. |
| `renv/`, `renv.lock` | Infraestrutura e bloqueio de dependências. |

Dados coletados, intermediários e processados nunca são versionados
(`data/`, `reports/source_probes/` e a pasta definida em `TAXMINER_DATA_DIR`).

## 16. Segurança e privacidade

- `restricted/` e `tmp/` são áreas protegidas, inacessíveis aos agentes, e
  nunca são publicadas. O atalho `doit` lê `.claude/doit.txt`, arquivo local
  ignorado pelo Git.
- `.gitignore` e `.renvignore` não substituem controle de acesso nem a
  exclusão de sincronização em nuvem; o desenvolvedor verifica essas
  exclusões localmente.
- Somente fontes públicas verificadas e fixtures públicas ou sintéticas.
  Acesso recusado (403/429) interrompe a coleta; controles de acesso nunca são
  contornados.
- Dados pessoais presentes em cadastros públicos (por exemplo, contatos de
  responsáveis) não entram em fixtures, relatórios ou na página do projeto.
- Nunca use `git add .` nem publique a raiz sem revisão; adicione arquivos por
  caminhos explícitos. Commits seguem Conventional Commits; commits, push e
  publicação exigem autorização. Credenciais nunca são registradas.

## 17. Documentação complementar

- [Página do projeto (GitHub Pages)](https://amarallr.github.io/taxminer/)
- [Panorama do projeto](docs/project_overview.md)
- [Arquitetura](docs/architecture.md) · [Requisitos e critérios de aceite](docs/requirements.md) · [Dicionário de dados](docs/data_dictionary.md)
- Fontes: [Soluções de Consulta](docs/source_inventory.md) · [Viabilidade da Fase 1.1](docs/feasibility.md) · [CVM](docs/data_sources.md)
- [Ambiente de desenvolvimento](docs/development_environment.md) · [GitHub](docs/github_setup.md)
- [Gestão do projeto](docs/project_management/) · [CHANGELOG](CHANGELOG.md) · [Prompts](prompts/README.md)
- Fontes oficiais: [Normas da Receita Federal](https://normas.receita.fazenda.gov.br/) · [Dados abertos da CVM](https://dados.cvm.gov.br/)

## 18. Licença

O código está sob a [licença MIT](LICENSE). Documentos e dados de terceiros
seguem os termos de cada fonte e não são cobertos por ela (por exemplo, os
dados abertos da CVM estão sob a licença ODbL).

## 19. Aviso de independência institucional

O TaxMiner é um projeto pessoal, independente e de código aberto. **Não é um
serviço oficial da Receita Federal do Brasil nem da CVM**, não tem vinculação
institucional com esses órgãos e não representa suas posições. Os resultados
não substituem os documentos oficiais nem constituem orientação jurídica,
contábil ou fiscal.
