# Source inventory (Collect P01)

Probe run: 2026-11-10T18:42 -03:00, `scripts/probe_sources.R`
(`reports/source_probes/20261110T184218/`, local). Requests used the generic
user agent `TaxMiner-source-probe/0.1`, 5 s between Normas requests and 10 s
between CVM requests. No bulk download was made. Totals below are the values
the source reported, not counts of documents TaxMiner holds.

## `tax_consultation_decisions` — Receita Federal

### Normas portal (search)

| Item | Observed |
|---|---|
| Official URL | https://normas.receita.fazenda.gov.br/ (Angular application) |
| robots.txt | Absent: the path returns the application page (HTTP 200, `text/html`). No explicit crawler policy. |
| Search API | `POST /api/indexacao/ato/pesquisar`, JSON body. Observed in the application's public JavaScript; not documented as a public API. |
| Reference lists | `GET /api/tipoAto/ativo`, `GET /api/orgao/ativo` (JSON, HTTP 200). |
| Act type IDs | Solução de Consulta `72`; Solução de Consulta Conjunta `104`; Solução de Consulta Interna `75`; Solução de Divergência `73`. |
| Filters | `tiposAtosSelecionados`, `orgaosSelecionados`, `tipoData` (`dataPublicacao`), `dataInicio`/`dataFim` as `dd/mm/aaaa`, `anoAto`, `numeroAto`, `termo`, `apenasAtosVigentes`, `internet: true`. |
| Pagination | `paginacaoPaginaAtual`, `paginacaoQuantidadePorPagina`; without them the API returns the total and an empty list. |
| Response fields | `idAto`, `numeroAto`, `anoAto`, `dataAto`, `dataPublicacao`, `tipoAto`, `orgaos` (sigla, nome, id), `ementa` (HTML), `vigente`, `internet`, `urlVisualizacao`; `texto` and `conteudo` came back empty. |
| Content | Ementa with subject, statement and legal provisions (1,324–10,828 characters in the January 2024 sample). Full text is not in the search response. |
| Errors | ISO dates return HTTP 500 with a parse message from the back end (Elasticsearch). |

Reported totals (`internet: true`, by publication date):

| Act type | All years | 2005 | 2015 | 2024 | 2025 |
|---|---:|---:|---:|---:|---:|
| Solução de Consulta | 15,880 | 82 | 1,045 | 1,033 | 965 |
| Solução de Consulta Interna | 259 | 5 | 17 | 6 | 5 |
| Solução de Divergência | 374 | 1 | 38 | 7 | 2 |
| Solução de Consulta Conjunta | 0 | 0 | 0 | 0 | 0 |

The January 2024 sample (20 SCs) came from Cosit (2) and regional Disit units
(SRRF04, SRRF07, SRRF08). The 2005 sample act (SC 264/2005, Disit/SRRF06) also
has an ementa (2,458 characters), so old acts carry metadata and ementa.

### Act viewer (full text)

| Item | Observed |
|---|---|
| Viewer URL | `https://normasinternet2.receita.fazenda.gov.br/#/consulta/externa/{idAto}` (from `urlVisualizacao`). Legacy links `sijut2consulta/link.action?idAto=` are redirected there by JavaScript. |
| robots.txt | Absent (returns the application page). |
| Full-text API | `GET /api/consulta-externa/ato/{idAto}`, observed in the viewer's JavaScript. |
| Automated access | **HTTP 403** for act 135832. Not retried with other headers, per project rules. |

### Other channels

- No open dataset of Soluções de Consulta was found on the RFB open-data
  pages or dados.gov.br (web search, 2026-11-10). Absence is not proven.
- www.gov.br/robots.txt allows general crawling (first attempt: connection
  reset; second: HTTP 200).
- Third-party sites republish PDFs of Cosit decisions; they are not official
  sources and are out of scope.

## `financial_disclosures` — CVM (handoff to Collect P04)

| Item | Observed |
|---|---|
| Official URL | https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/ and `.../ITR/DADOS/` |
| robots.txt | `Crawl-Delay: 10`; disallows `/api/`, `/dataset/*/history`, `/revision/`, `/dataset/rate/`. `/dados/` allowed. |
| License | ODbL, as shown on the dataset pages (web search; text to be confirmed in Collect P04). |
| Files | One ZIP per year, `dfp_cia_aberta_2010.zip` … `dfp_cia_aberta_2026.zip`, 8–13 MB each, last updated 2026-11-08. ITR follows the same layout. |
| Open question | Whether explanatory notes are in the ZIP files or only in the linked filing documents. Not checked; no ZIP was downloaded. |

## `investment_fund_reports` — CVM (handoff to Collect P05, `decision_0024`)

Listing check: 2026-11-10T22:20 -03:00, 15 directory listings, 10 s between requests, all HTTP
200, no file downloaded. Details are in `docs/data_sources.md` and
`config/investment_fund_report_sources.yml`.

| Subfamily | Official listings | Observed coverage |
|---|---|---|
| `fii` | `https://dados.cvm.gov.br/dados/FII/DOC/` (`INF_MENSAL`, `INF_TRIMESTRAL`, `INF_ANUAL`, `DFIN`) | yearly files 2016–2026 |
| `fidc` | `https://dados.cvm.gov.br/dados/FIDC/DOC/INF_MENSAL/` | monthly 202501–202610 plus `HIST/` |
| `fip` | `https://dados.cvm.gov.br/dados/FIP/DOC/` (`INF_TRIMESTRAL`, `INF_QUADRIMESTRAL`) | yearly 2010–2023 and 2024–2026 |
| `fiagro` | `https://dados.cvm.gov.br/dados/FIAGRO/DOC/INF_MENSAL/` | monthly 202505–202610 |

Open questions for Collect P05 step 00:

- dataset licenses (ODbL to be confirmed per dataset page);
- `META/` dictionaries and table layouts;
- the content and first period of the FIDC `HIST/` folder;
- the republication cadence of recent files.
