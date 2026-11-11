# Novas fontes de dados: fundos de investimento da CVM (FII, FIDC, FIP, FIAGRO) — inventário e análise de lacunas (Common P07, etapa 00)

> **Atualização (`decision_0024`, 2026-11-10):** os fundos de investimento (FII, FIDC, FIP e
> FIAGRO) passaram a ser a família `investment_fund_reports` e a Fase 4 do MVP, com aceite
> próprio. Onde este documento fala em "opção B", "família opcional" ou "fora dos MVPs", vale
> a Fase 4. A implementação de referência cobre só FIDC e FII; FIP e FIAGRO serão
> implementados a partir das fontes da CVM. Listagens verificadas em `docs/data_sources.md`.

- **Prompt:** `prompts/common_p07_new_data_sources.txt` (etapa 00, somente leitura).
- **Work item:** `work_0019`. **Riscos:** `risk_0014`, `risk_0015`.
- **Origem (implementação de referência):** pipeline R do próprio desenvolvedor para relatórios de fundos da CVM @ `595991b` (repositório público, **sem LICENSE**).
- **Destino:** TaxMiner @ `8e6b719`. O prompt foi escrito sobre `7c0d8be`; os dois commits
  posteriores só mudaram a apresentação (README e site) e não alteram esta análise.
- **Data:** 2026-11-10. **Estado:** aguardando o gate 01. Nenhum código foi incorporado.

## Método e limites

- **Clone.** Feito fora do checkout do TaxMiner e do OneDrive, na área temporária da sessão do
  assistente, com `git sparse-checkout` restrito à allowlist do prompt:
  - `README.md`, `CHANGELOG.md`, `renv.lock`;
  - `prompts/*.txt`, `prompts/README.md`;
  - `docs/*.md`, `docs/references/cvm/*.csv`;
  - `src/{orchestration,utils,validation,configuration,download,acceptance}/*`;
  - `src/consolidation/*.R` (só o nível superior, portanto sem `private/`);
  - `tests/testthat/*.R`, `.github/workflows/testes.yml`.
- **Caminhos não lidos.** Nenhum caminho ignorado ou privado da origem foi lido: `restricted/`,
  `data/`, `tmp/`, `src/consolidation/private/`, `locais/`, `outputs/`, `config/`, `logs/` e o
  `AGENTS.md` local.
- **Isolamento.** O clone não é remote, submódulo nem subtree do TaxMiner.
- **Integridade da origem.** O `git status` do clone ficou limpo após os testes; a origem não
  foi alterada.
- **Pacote de prompts.** A origem ainda não tem o pacote de prompts 1.1, só os prompts
  `00`–`07`. Por isso a seção (a) usa o método "IDs a reconciliar".

### Suíte da origem (resultado real)

O runner oficial `Rscript --vanilla src/utils/p02_testar.R todas` **não foi executado**, por
dois motivos:

- ele exige o arquivo `.Rproj` da origem, que está fora da allowlist;
- `dotenv` não está instalado, e P03 e P07 dependem dele. Nada foi instalado.

No lugar dele, cada arquivo de teste cujas dependências já existiam foi executado com
`testthat::test_file` dentro do clone, com `FIDC_TESTES_ATIVOS=1` (exit 0):

| Arquivo | Casos | Expectativas | Aprovadas | Falhas, erros, skips e avisos |
|---|---:|---:|---:|---:|
| test-p01-orquestracao.R | 4 | 68 | 68 | 0 |
| test-p02-utilitarios.R | 7 | 44 | 44 | 0 |
| test-p04-configuracao.R | 4 | 25 | 25 | 0 |
| test-p05_01-download-fidc.R | 4 | 24 | 24 | 0 |
| test-p05_02-download-fii.R | 7 | 56 | 56 | 0 |
| test-p06_01-consolidacao-fidc.R | 11 | 57 | 57 | 0 |
| test-p06_02-consolidacao-fii.R | 3 | 21 | 21 | 0 |
| **Total (7 de 9 arquivos)** | **40** | **295** | **295** | **0** |

`test-p03-ambiente.R` e `test-p07-aceite.R` não foram executados porque exigem `dotenv`.

Ambiente usado: R 4.5.1, testthat 3.3.2, data.table 1.18.2.1, httr2 1.3.0, digest 0.6.39,
jsonlite 2.0.0 e arrow 25.0.1. Todos estão na biblioteca de sistema e nenhum foi declarado no
TaxMiner.

## a) Inventário e lacunas de rastreabilidade

| Etapa | Arquivo | Funções públicas |
|---|---|---|
| P01 orquestração | `src/orchestration/p01_executar.R`, `p01_pipeline_fidc.R` | `executar_etapa`, `executar_pipeline_etapa` |
| P02 utilitários | `src/utils/p02_utilitarios.R` | `validar_destino`, `calcular_hash_assinatura`, `gravar_validado_atomico`, `recuperar_rollback`, `ler_rds_recuperavel`, `assinatura_codigo`, `assinatura_transformacao`, `registrar_tentativa`, `registrar_ambiente`, `resolver_politica_execucao`, `validar_rastreabilidade`, `carregar_pipeline` |
| P02 dependências e runner | `src/utils/p02_dependencias.R`, `p02_testar.R` | `gerenciar_dependencias`; script runner |
| P03 ambiente | `src/validation/p03_*.R` | `verificar_ambiente`, `verificar_repositorio`, `preparar_projeto` |
| P04 configuração FIDC | `src/configuration/p04_configuracao_fidc.R` | `validar_configuracao`, `validar_filtros_fidc`, `expressao_filtros_fidc`, `avaliar_filtros_fidc`, `inventariar_recursos_fidc`, `selecionar_unidades_fidc`, `assinar_plano_fidc`, `validar_downloads_plano` |
| P05_01 download FIDC | `src/download/p05_01_download_fidc.R` | `transportar_http`, `validar_zip_fidc`, `baixar_unidade_fidc`, `retomar_downloads_fidc`, `extrair_zip_fidc` |
| P05_02 download FII | `src/download/p05_02_download_fii.R` | `carregar_download_fii`, `validar_configuracao_fii`, `inventariar_recursos_fii`, `selecionar_unidades_fii`, `baixar_recurso_fii`, `executar_download_fii` |
| P06_01 consolidação FIDC | `src/consolidation/p06_01_consolidacao_fidc.R`, `p06_01_medir_execucao.R` | `chaves_posicoes_fidc`, `preparar_indice_filtros_fidc`, `aplicar_indice_filtros_fidc`, `ler_padronizar_fidc`, `relatar_qualidade_fidc`, `auditar_chaves_fidc`, `validar_dv_ni`, `retomar_consolidacao_fidc`, `exportar_parquet_fidc`, `medir_pipeline` |
| P06_02 consolidação FII | `src/consolidation/p06_02_consolidacao_fii.R` | `carregar_consolidacao_fii`, `ler_texto_fii`, `ler_tabela_fii`, `consolidar_fii` |
| P07 aceite | `src/acceptance/p07_aceite.R`, `p07_evidencias.R` | `executar_aceite`, `gerar_relatorio_aceite`, `produzir_evidencias_aceite`, `validar_evidencias_aceite` |

Também foram inventariados os testes `tests/testthat/test-p01` a `test-p07` (9 arquivos) mais
`helper-p02-pipeline.R`, e os dicionários `docs/references/cvm/dicionario_campos_declarados.csv`
e `dicionario_textual_cvm.csv`.

**IDs.** A busca usou o padrão `PNN[_SS]-(RF|RNF|TST|FUN|MOD)-NNN`.

| Categoria | Nos prompts | Nos marcadores de código e testes |
|---|---:|---:|
| RF | 46 | 24 |
| RNF | 15 | 5 |
| TST | 9 | 35 |
| FUN | 0 | 45 |
| MOD | 0 | 11 |
| **Total distinto** | **70** | **120** |

**Lacunas.** Há 43 IDs nos prompts sem marcador no código:

- **P05_02 (FII) é a maior lacuna:** 22 IDs (RF-002/003/005–008/010–012, RNF-001–005,
  TST-002/006–009).
- **Demais etapas:**
  - P01-RNF-002;
  - P02-RF-001/003 e RNF-001;
  - P04-RF-002–004;
  - P05_01-RF-002–005 e RNF-001;
  - P06_01-RF-001/002/004/005 e RNF-001;
  - P06_02-RF-002/004/005 e RNF-001/002;
  - P07-RF-002 e RNF-001.
- **O sentido inverso é estrutural:** os IDs FUN e MOD existem só no código, e vários TST só
  nos testes. Também aparecem no código requisitos ausentes dos prompts: P02-RF-006,
  P02-RNF-002, P03-RNF-002 e P06_01-RF-012/014/015.
- **Consequência:** um marcador ausente não prova que o requisito ficou sem implementação, e um
  ID só no código não tem lastro documental. Qualquer requisito adotado precisa de reconciliação
  manual (seção d), e a contagem de cobertura da origem não pode ser herdada.

## b) Capacidades: primitiva da origem vs. TaxMiner

TaxMiner hoje: `src/collect/download_financial_reports.R` e `scripts/collect_financial_reports.R`
(pipeline da Fase 2, `test_0033`/`test_0034`).

| Primitiva da origem | Equivalente no TaxMiner | Situação | Benefício | Risco | Evidência de teste na origem |
|---|---|---|---|---|---|
| `validar_destino` (caminho relativo contido na raiz, rejeita `..`, absoluto e unidade; resolve o ancestral real) | O script rejeita `TAXMINER_DATA_DIR` dentro do OneDrive; os caminhos são montados com `file.path` sem verificar contenção | **ausente** | Barreira contra path traversal vindo do catálogo e de nomes de membros | Baixo; comparação insensível a caixa só faz sentido no Windows | P02, 44/44 |
| `calcular_hash_assinatura` (SHA-256 de arquivo ou objeto, lista ordenada por nome) | `tools::sha256sum` (base R) por pacote e por membro | **parcial** (só arquivos) | Assinatura determinística de configuração e plano | `digest` com `serializeVersion = 2` cria dependência; dá para reimplementar com `serialize()` + `tools::sha256sum` em arquivo temporário | P02 |
| `gravar_validado_atomico` + `recuperar_rollback` (temporário vizinho, validação, `.rollback`, restauração) | Pacote `partial` renomeado para o destino; manifesto em CSV append-only | **parcial** | Publicação sem destruir a versão anterior; recuperação após interrupção | No OneDrive o rename pode falhar (a origem documenta isso); o formato CSV usa `data.table` | P02, P05_01 |
| `ler_rds_recuperavel` (RDS corrompido preservado como `.corrompido-`) | Quarentena de ZIP ilegível em `quarantine/` | **parcial** (mesma ideia, outro artefato) | Estado corrompido nunca vale como sucesso | Baixo | P02 |
| `assinatura_codigo` / `assinatura_transformacao` | Inexistente | **ausente** | Liga evidência e saída à versão do código; detecta evidência obsoleta | Lista de arquivos e funções fixa na origem; precisa de nova definição | P02, P07 (não executado) |
| `registrar_tentativa` (registro por etapa e PID; `em_processamento` denuncia queda) | Log de texto + manifesto por pacote | **ausente** | Detecta execução abortada e liga a tentativa à configuração | Baixo | P02 |
| `resolver_politica_execucao` (reutilizar checkpoint ≠ atualizar download) | Implícita: só baixa o que falta, atualiza os índices dos dois anos recentes | **parcial** | Política explícita e testável | Baixo | P02 |
| `registrar_ambiente` | `scripts/validate_environment.R` (pacotes, R, fronteiras) | **existe** | — | — | — |
| `validar_rastreabilidade` | Registros CSV sem validador automático | **ausente** | Detecta ID duplicado ou sem vínculo | Esquema de IDs diferente (`req_`, `test_`) | P02 |
| `transportar_http` (httr2, status sem exceção) | `curl_fetch` (curl do sistema, status 0 em erro) | **existe** | — | httr2 seria uma nova dependência sem ganho | P05_01 |
| `validar_zip_fidc` (≤ 256 membros, limite de bytes, nomes inseguros e duplicados, CRC por extração e hash) | `is_valid_package` + `member_checksums` (extração e hash por membro) | **parcial** (faltam limites e nomes inseguros) | Proteção contra zip-slip e zip bomb no pacote RAD | Pacotes legados têm `.dfp` aninhado; o limite de membros precisa ser calibrado | P05_01, 24/24 |
| Retentativa em 408/429/5xx, backoff min(2^(n-1), 8) s | Retentativa em timeout e 5xx, backoff de 30 s × 2^(n-1); **parada imediata em 403/429** | **existe** (TaxMiner é mais conservador) | — | Não adotar a retentativa em 429 da origem: conflita com `AGENTS.md` | P05_01 |
| `extrair_zip_fidc` por unidade e hash | Leitura em memória dos anexos (`src/data/extract_financial_notes.R`) | **existe** de outra forma | — | — | — |
| Evidência de aceite P07 (código, configuração, plano e saídas assinados; retomada em processos novos) | `test_register.csv` e `acceptance_register.csv` manuais | **ausente** | Evidência automática verificável que apoia o aceite humano | Complexo; nunca substitui o aceite humano | P07 (não executado) |
| P04, P05_02, P06_01, P06_02 (FIDC e FII) | Nenhum (fora do escopo dos MVPs) | **fora de escopo** | Só relevante na opção B | Ampliação de escopo | P04 25/25; P05_02 56/56; P06_01 57/57; P06_02 21/21 |

## c) Mapeamento de nomes pt-BR → en-US (proposta; decisão no gate 01)

| Origem | Proposta TaxMiner | Arquivo de destino proposto |
|---|---|---|
| `validar_destino` | `validate_contained_path` | `src/common/safe_io.R` |
| `gravar_validado_atomico` | `write_validated_atomic` | `src/common/safe_io.R` |
| `recuperar_rollback` | `recover_from_rollback` | `src/common/safe_io.R` |
| `ler_rds_recuperavel` | `read_rds_recoverable` | `src/common/safe_io.R` |
| `calcular_hash_assinatura` | `compute_signature_hash` | `src/common/signatures.R` |
| `assinatura_codigo` | `code_signature` | `src/common/signatures.R` |
| `assinatura_transformacao` | `transformation_signature` | `src/common/signatures.R` |
| `registrar_tentativa` | `record_attempt` | `src/common/execution_policy.R` |
| `resolver_politica_execucao` | `resolve_execution_policy` | `src/common/execution_policy.R` |
| `validar_rastreabilidade` | `validate_traceability` | `src/common/traceability.R` |
| `validar_zip_fidc` | `validate_zip_archive` | `src/common/safe_io.R` |
| `transportar_http` | `http_transport` (não recomendado: já existe `curl_fetch`) | — |

Argumentos e campos seguem a mesma regra:

- `caminho` → `path`, `raiz` → `root`, `validador` → `validator`;
- `estado` → `status`, com valores `in_progress`, `completed`, `failed` e `unavailable`;
- `motivo` → `reason`, `tentativas` → `attempts`.

Nomes de campos da CVM e textos de origem ficam como publicados.

## d) Mapeamento de IDs (proposta)

Os IDs `req_` e `test_` do TaxMiner nunca são reutilizados. Cada requisito ou teste adotado
recebe o próximo ID livre, com a nota `origin_id`. Os próximos livres no momento são
`req_0012` e `test_0035`.

| Proposta | Descrição | `origin_id` |
|---|---|---|
| `req_0015` (common, proposto) | Gravação validada com rollback e caminhos contidos | P02-RF-002, P02-RF-003, P02-RF-008, P02-FUN-001/006/007/008 |
| `req_0016` (common, proposto) | Assinaturas de código, configuração e transformação | P02-FUN-002/009/012, P07-RF-004 |
| `req_0017` (common, proposto) | Política de execução e registro de tentativas | P02-RF-006, P02-FUN-003/013 |
| `test_0035` | Testes sintéticos de `src/common/` | P02-TST-001/003/004/011/012/013 |
| `req_0012`–`req_0014` (registrados, `decision_0024`) | Coleta, consolidação e busca de `investment_fund_reports` (FII, FIDC, FIP, FIAGRO) | P04, P05_01, P05_02, P06_01, P06_02 para FIDC e FII; FIP e FIAGRO sem código de referência |

Atualização (`decision_0024`): `req_0012`–`req_0014` foram usados pelos requisitos dos fundos. Os requisitos das rotinas comuns recebem os próximos IDs livres na etapa 02 (hoje `req_0015`–`req_0017`).

## e) Dependências: delta e alternativas em base R

Hoje o `DESCRIPTION` do TaxMiner tem `Imports: renv, testthat`.

| Pacote da origem | Uso na origem | Alternativa base R | Recomendação |
|---|---|---|---|
| `digest` | SHA-256 de arquivo e objeto | `tools::sha256sum` (arquivos) + `serialize()` em arquivo temporário (objetos) | **Não adicionar** |
| `data.table` | `fread`, `fwrite`, `rbindlist` (CSV com `;`) | `utils::read.csv2`, `write.csv2`, `do.call(rbind, …)` | **Não adicionar** para as primitivas; reavaliar na opção B (volume FIDC) |
| `httr2` | Transporte HTTP | `curl_fetch` existente (curl do sistema) | **Não adicionar** |
| `jsonlite` | Resumo e evidência em JSON | `saveRDS` ou CSV | **Não adicionar** agora; avaliar na etapa 04 |
| `dotenv` | `.env` em P03 e P07 | `readRenviron()` | **Não adicionar** |
| `arrow` (opcional) | Parquet | Nenhuma equivalente | Já pendente para a Fase 2 (`data_p02`/`data_p03`); decisão própria |
| `readr`, `vroom`, `curl` e outros transitivos do `renv.lock` (48 pacotes) | Leitura e transporte | — | Não adicionar |

Com a opção A, a incorporação **não exige nenhum pacote novo**.

## f) Mapeamento de diretórios (Fase 4, `decision_0024`)

| Origem | TaxMiner (fora do repositório e do OneDrive) |
|---|---|
| `data/data_fidc/originais` | `TAXMINER_DATA_DIR/raw/investment_fund_reports/fidc/` |
| `data/data_fii/...` | `TAXMINER_DATA_DIR/raw/investment_fund_reports/fii/` |
| `data/data_fidc/extraidos/<unidade>/<hash>` | `TAXMINER_DATA_DIR/interim/investment_fund_reports/fidc/<unit>/<sha256>/` |
| `outputs/fidc`, `outputs/fii` | `TAXMINER_DATA_DIR/processed/investment_fund_reports/{fii,fidc,fip,fiagro}/` |
| `config/` (ignorado na origem) | `config/investment_fund_report_sources.yml` (versionado, sem segredos) |
| `logs/` | Log e manifesto em `TAXMINER_DATA_DIR/...`; evidência em `reports/execution/` só se for aprovada |

## g) Conflitos e riscos

1. **Escopo:** FIDC e FII não pertencem a nenhum MVP. A opção B cria uma família opcional que
   não conta para os gates e disputa atenção com a Fase 2 (`risk_0015`).
2. **Licença:** a origem não tem LICENSE, e o TaxMiner é MIT. Sem relicenciamento confirmado
   pelo titular, só é possível reimplementar a partir dos requisitos, com atribuição
   (`risk_0014`).
3. **Nomes e idioma:** identificadores, mensagens e documentos da origem estão em pt-BR. Importar
   o histórico Git traria caminhos e nomes fora do padrão; a recomendação é registrar a
   proveniência por SHA.
4. **Matriz de CI:** a origem roda em Windows e Linux; o TaxMiner, só em Windows. Propor um job
   Linux só se os testes portados precisarem.
5. **Semântica de `tmp/`:** na origem guarda instruções locais; no TaxMiner é área protegida.
   Nada de `tmp/` da origem é lido ou portado, e nenhum código portado pode usar `tmp/` como
   destino.
6. **Coleta DFP em andamento** (pid 7068, `C:\TaxMinerData`): nenhuma mudança em `src/collect/`
   até a coleta terminar ou chegar a um ponto escolhido pelo desenvolvedor. Primitivas novas em
   `src/common/` não alteram o processo em execução, porque ele já carregou o código.
7. **Política de 429:** a origem tenta de novo em 429; o TaxMiner para. A regra do TaxMiner
   prevalece.
8. **Termos da CVM para `/dados/FIDC` e `/dados/FII`:** não foram verificados nesta etapa (sem
   rede para a CVM). É obrigatório verificar licença, `robots.txt` e crawl delay antes de
   qualquer código na opção B.
9. **OneDrive e rename:** a origem documenta que a substituição atômica não é garantida no
   OneDrive. No TaxMiner os dados ficam fora do OneDrive, mas os registros do repositório
   continuam nele.
10. **Rastreabilidade incompleta da origem** (seção a): a cobertura declarada não pode ser
    herdada.
