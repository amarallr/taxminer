# Data sources (Collect P04 and P05)

**Status:** sources verified (Collect P04 and P05); collections running ·
**Última atualização:** 2026-11-11 ·
**Documentos relacionados:** [Architecture](architecture.md) ·
[Data dictionary](data_dictionary.md) ·
[Decision log](project_management/decision_log.md)

## Financial disclosure sources (Collect P04, step 00)

Family: `financial_disclosures` (MVP Phase 1.2; numbered Phase 2 before `decision_0025`). Probe run: 2026-11-10T19:00
-03:00, `scripts/probe_financial_sources.R`
(`reports/source_probes/20261110T190046_cvm/`, local). Requests used the
generic user agent `TaxMiner-source-probe/0.1` with 10 s between requests.
Downloaded: listings, the company register, the smallest yearly DFP ZIP (2026,
243 KB) and one filing document (13.5 MB). No bulk download was made. The
machine-readable registry is `config/financial_disclosure_sources.yml`.

### Summary

| Need                                                | Source                                                                                     | Verified            |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------- |
| Filing index (company, CNPJ, period, version, link) | CVM open data, DFP/ITR yearly ZIP, `*_cia_aberta_{year}.csv`                               | Yes                 |
| Structured statements (BP, DRE, DFC, DMPL, DVA)     | Same ZIPs, one CSV per statement and scope (`_con`, `_ind`)                                | Yes                 |
| **Explanatory notes**                               | **Not in the open-data ZIPs.** Available in the filing document from RAD/ENET (`LINK_DOC`) | Yes, for one filing |
| Company identity                                    | CVM register `cad_cia_aberta.csv`                                                          | Yes                 |

### CVM open data (dados.cvm.gov.br)

| Item                   | Observed                                                                                                                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| URLs                   | `https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_{year}.zip`, `.../ITR/DADOS/itr_cia_aberta_{year}.zip`, `.../CAD/DADOS/cad_cia_aberta.csv`                                         |
| robots.txt             | `Crawl-Delay: 10`; disallows `/api/`, `/dataset/*/history`, `/revision/`, `/dataset/rate/`; `/dados/` allowed                                                                                              |
| License                | ODbL (Open Data Commons), as shown on the dataset page `dataset/cia_aberta-doc-dfp`                                                                                                                        |
| Update policy          | Dataset page: weekly updates with resubmissions; history since 2010                                                                                                                                        |
| Files                  | DFP 2010–2026 (8–13 MB; 2026: 238 KB); ITR up to 2026 (21–31 MB for 2024–2026)                                                                                                                             |
| DFP ZIP members (2026) | Index `dfp_cia_aberta_2026.csv`; `BPA`, `BPP`, `DRE`, `DRA`, `DVA`, `DMPL`, `DFC_MD`, `DFC_MI` in `_con` and `_ind`; `composicao_capital`; `parecer` (auditor's report). 19 files, no notes                |
| Index columns          | `CNPJ_CIA`, `DT_REFER`, `VERSAO`, `DENOM_CIA`, `CD_CVM`, `CATEG_DOC`, `ID_DOC`, `DT_RECEB`, `LINK_DOC`                                                                                                     |
| Encoding               | Latin-1, `;` separator                                                                                                                                                                                     |
| Company register       | 2,679 rows: 756 `ATIVO`, 1,916 `CANCELADA`, 7 suspended; 2,532 distinct CNPJs (147 repeated rows). Contains names and contacts of responsible officers: personal data, never copied to fixtures or reports |

The 2026 DFP index lists 9 filings (fiscal years ending in 2026, e.g.
31/03/2026). Most annual filings for calendar years are under the year of
`DT_REFER` (2025 for fiscal year 2025).

### Filing documents (RAD/ENET)

| Item                    | Observed                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| URL                     | `LINK_DOC` = `http://www.rad.cvm.gov.br/ENETCONSULTA/frmDownloadDocumento.aspx?CodigoInstituicao=1&NumeroSequencialDocumento={ID_DOC}`; HTTP 302 to the same path over HTTPS                                                                                                                                                                                                                                                                    |
| robots.txt              | Absent (HTTP 404). No explicit crawler policy found                                                                                                                                                                                                                                                                                                                                                                                             |
| Response                | HTTP 200, `Content-Type: text/html` but `Content-Disposition: attachment; filename={cd_cvm}{yyyymmdd}{n}.zip`; the body is a ZIP. Check content by signature, not by the declared type                                                                                                                                                                                                                                                          |
| Members (ID_DOC 159112) | `{cd_cvm}DFP{dd-mm-yyyy}v{version}.xml` (8.9 MB, structured statements and attachments), a PDF generated by ENET (16 MiB), `DadosDocumento.xlsx`, `FormularioCadastral.xml`, `FormularioDemonstracaoFinanceiraDFP.xml`                                                                                                                                                                                                                          |
| Notes                   | The XML embeds the company's PDF attachments in base64 (`XmlDemonstracoesFinanceirasDadosDFPAnexoDocumento`, with `NomeArquivoPdf` and `ImagemObjetoArquivoPdf`). In this filing: management report, the financial statements with explanatory notes (20 pages, numbered notes such as "1. Contexto operacional", "17. Instrumentos financeiros", "24. Partes relacionadas"), projections, capital budget. The ENET PDF also contains the notes |
| Text layer              | The attached statements PDF has a text layer (extracted with `pdftotext`; no OCR needed in this case)                                                                                                                                                                                                                                                                                                                                           |
| Stability               | Downloading the same `ID_DOC` twice gave different ZIP hashes (the generated PDF name carries a timestamp) but identical SHA-256 for the XML, XLSX and form XML members. Checksums must be kept per member as well as per download                                                                                                                                                                                                              |
| Anomaly                 | The ENET PDF is exactly 16,777,216 bytes, with about 9.6 MB of content followed by zero padding; `pdftotext` reports a damaged xref table and reconstructs it. Prefer the attachments in the XML; treat the generated PDF as secondary                                                                                                                                                                                                          |

### Identity and versions (input to step 01)

- `report_id`: `cvm:{CATEG_DOC}:{CD_CVM}:{DT_REFER}:v{VERSAO}`, with `ID_DOC` kept
  as the source document number. Resubmissions get a new `VERSAO` and
  `ID_DOC`; keep all versions.
- `company_cnpj` from the index and the register, verified by matching
  `CD_CVM`; `CNPJ_CIA` repeats in the register (cancelled and new
  registrations), so the join key is `CD_CVM` plus validity dates.
- `statement_scope`: `_con` (consolidated) and `_ind` (individual) in the
  structured data; in the notes, the scope comes from the text and is often
  both.
- `report_type`: `DFP` (annual) and `ITR` (quarterly); other CVM documents (FRE,
  IPE) are out of scope unless approved.

### Proposed Phase 1.2 sample (needs authorization)

Collect P04 step 02 should start with up to 20 filing packages (about 15 MB
each, about 300 MB in total, 10 s between requests):

| Stratum                                                   | Filings |
| --------------------------------------------------------- | ------: |
| DFP fiscal year 2025, active companies, different sectors | 10      |
| ITR 2026 (latest quarter), same companies when available  | 5       |
| DFP fiscal year 2011, to check older formats              | 3       |
| Resubmission (`VERSAO` > 1)                               | 2       |

Raw packages stay local under `data/raw/financial_disclosures/` and are never
published. The yearly index ZIPs needed for selection (about 13 MB each) are
downloaded once per year used.

### Open questions

1. Whether older filings (e.g. 2010–2012) embed notes the same way; one recent
   filing was inspected.
2. Whether every company attaches the statements PDF; the attachment names are
   free text chosen by the company, so the notes attachment must be identified
   by content, not by name.
3. Formal terms of use for RAD/ENET documents (public filings; no robots.txt and
   no license statement found on the download response).
4. Why the ENET PDF is zero-padded to 16 MiB, and whether larger filings are
   truncated.

### Full collection (authorized 2026-11-10)

The developer asked to download everything available. The catalog built from
all yearly index ZIPs (DFP 2010–2026, ITR 2011–2026; `itr_cia_aberta_2010.zip`
returns 404) has **49,908 filing packages** from 1,230 companies:

| Form | Packages | Resubmissions (`VERSAO` > 1) |
| ---- | -------: | ---------------------------: |
| DFP  | 14,015   | 3,149                        |
| ITR  | 35,893   | 4,412                        |

Measured packages range from 3.3 MB (DFP 2011) to 22 MB (DFP 2026), with 17–21 s
of server time each. All forms would need about 450 GB and about 16 days at
10 s between requests, more than the 163 GB free on the workstation. The
developer chose **all DFP first** (about 110 GB, 4–5 days, newest periods
first) in a local folder outside OneDrive; ITR waits for more storage.

Command (resumable; reruns skip packages already downloaded):

```powershell
$env:TAXMINER_DATA_DIR = 'C:\TaxMinerData'
Rscript --vanilla scripts/collect_financial_reports.R dfp 2010-2026 Inf
```

> [!WARNING]
> The script refuses a data folder inside OneDrive and stops when free space falls below
> 20 GB. Raw packages, the catalog and the manifest stay in the data folder and are never
> committed or published.

Observed in the first packages:

- **Older format:** a 2011 DFP and a 2018 ITR carry `{cd_cvm}{date}{seq}.dfp`
  / `.itr` files instead of the `...v{n}.xml` file of recent filings. Data P03
  must handle both layouts.
- **Transient failures:** RAD sometimes returns HTTP 200 with the text "The
  HTTP service ... is unavailable", or resets the connection mid-transfer
  (truncated ZIP without a central directory). Both are retried with backoff
  (30 s, 60 s); after three attempts the package is recorded as `failed` and
  retried on the next run. A truncated or unreadable file never stays in the
  raw store (it is moved to `quarantine/`).
- The ENET-generated PDF is padded to a power of two (8 MiB, 16 MiB).

## Investment fund report sources (Collect P05)

- **Family:** `investment_fund_reports` (MVP Phase 1.3, `decision_0024`, `decision_0025`,
  `decision_0029`).
- **Registry:** `config/investment_fund_report_sources.yml` (human-readable) and
  `fund_report_sources` in `src/collect/discover_fund_reports.R` (used by the code).

### Step 00 — verification (2026-11-11T00:18-03:00)

- **Access.** `robots.txt` of `dados.cvm.gov.br` allows `/dados/` and sets `Crawl-Delay: 10`;
  every request waited at least 10 s. All requests returned HTTP 200; none was refused.
- **License.** The dataset pages `fii-doc-inf_mensal`, `fidc-doc-inf_mensal`,
  `fip-doc-inf_quadrimestral` and `fiagro-doc-inf_mensal` state ODbL. The FIP page says the
  files are updated weekly with resubmissions.
- **Dictionaries.** The `META/` file of each dataset was downloaded to
  `<TAXMINER_DATA_DIR>/investment_fund_reports/meta/` (Latin-1 text, one block per field with
  description, domain, type and size):

| Dataset                 | META file                        | SHA-256 (12)   | Tables                 | Fund identifier                                | Period field      |
| ----------------------- | -------------------------------- | -------------- | ---------------------: | ---------------------------------------------- | ----------------- |
| FII `INF_MENSAL`        | `meta_inf_mensal_fii.zip`        | `d9a4a78941ca` | 3                      | `CNPJ_Fundo_Classe`                            | `Data_Referencia` |
| FII `INF_TRIMESTRAL`    | `meta_inf_trimestral_fii.zip`    | `e270e15b47d5` | 16                     | `CNPJ_Fundo_Classe`                            | `Data_Referencia` |
| FII `INF_ANUAL`         | `meta_inf_anual_fii.zip`         | `182afa5ecd36` | 13                     | `CNPJ_Fundo_Classe`                            | `Data_Referencia` |
| FII `DFIN`              | `meta_dfin_fii.txt`              | `3c4e13039eb3` | 1                      | `CNPJ_Fundo_Classe`                            | `Data_Referencia` |
| FIDC `INF_MENSAL`       | `meta_inf_mensal_fidc_txt.zip`   | `5fb2b329aadf` | 18 (`tab_I`–`tab_X_7`) | `CNPJ_FUNDO_CLASSE` (some tables `CNPJ_FUNDO`) | `DT_COMPTC`       |
| FIP `INF_TRIMESTRAL`    | `meta_inf_trimestral_fip.txt`    | `b2a5fc31e13f` | 1                      | `CNPJ_FUNDO`                                   | `DT_COMPTC`       |
| FIP `INF_QUADRIMESTRAL` | `meta_inf_quadrimestral_fip.txt` | `1cab9fb27223` | 1                      | `CNPJ_FUNDO_CLASSE`                            | `DT_COMPTC`       |
| FIAGRO `INF_MENSAL`     | `meta_inf_mensal_fiagro.zip`     | `f7d9ce7a4c34` | 2                      | `CNPJ_Classe`                                  | `Data_Referencia` |

- **Administrator.** `CNPJ_Administrador` appears in the FII `geral` tables and FIAGRO;
  `CNPJ_ADMIN` in FIDC `tab_I`. FIP has no administrator CNPJ in the dictionary.
- **Layout breaks.** The fund identifier changes from `CNPJ_FUNDO` (FIP quarterly, up to 2023)
  to `CNPJ_FUNDO_CLASSE` (four-monthly, from 2024), following the fund/class split of CVM
  Resolution 175. Data P04 must map both.

### Step 01 — listings (2026-11-11T00:18-03:00)

The listings are nginx autoindex pages with name, timestamp (`dd-Mon-yyyy HH:MM`) and an
approximate size. Discovery parsed 102 files plus 11 DFIN files:

| Subfamily | Listing                            | Files | Periods                                              |
| --------- | ---------------------------------- | ----: | ---------------------------------------------------- |
| `fii`     | `FII/DOC/INF_MENSAL/DADOS/`        | 11    | 2016–2026 (yearly ZIP)                               |
| `fii`     | `FII/DOC/INF_TRIMESTRAL/DADOS/`    | 11    | 2016–2026 (yearly ZIP)                               |
| `fii`     | `FII/DOC/INF_ANUAL/DADOS/`         | 11    | 2016–2026 (yearly ZIP)                               |
| `fii`     | `FII/DOC/DFIN/DADOS/`              | 11    | 2016–2026 (CSV index; outside the collection scopes) |
| `fidc`    | `FIDC/DOC/INF_MENSAL/DADOS/`       | 22    | 2025-01–2026-10 (monthly ZIP)                        |
| `fidc`    | `FIDC/DOC/INF_MENSAL/DADOS/HIST/`  | 12    | 2013–2024 (yearly ZIP)                               |
| `fip`     | `FIP/DOC/INF_TRIMESTRAL/DADOS/`    | 14    | 2010–2023 (yearly CSV)                               |
| `fip`     | `FIP/DOC/INF_QUADRIMESTRAL/DADOS/` | 3     | 2024–2026 (yearly CSV)                               |
| `fiagro`  | `FIAGRO/DOC/INF_MENSAL/DADOS/`     | 18    | 2025-05–2026-10 (monthly ZIP)                        |

Every listing timestamp is on or after 2026-11-07: the CVM rewrites the files, including old
periods. A new timestamp makes a file pending again; identical content is recorded as
`unchanged_content` without a second copy.

### Steps 02–03 — collection

```powershell
$env:TAXMINER_DATA_DIR = "C:\TaxMinerData"
Rscript --vanilla scripts/collect_fund_reports.R sample    # latest period of each dataset
Rscript --vanilla scripts/collect_fund_reports.R history   # every listed period
```

- **Storage.** `<TAXMINER_DATA_DIR>/investment_fund_reports/`: `catalog.csv`,
  `manifests/{family}.csv` (append-only, one row per attempt), `meta/`, `logs/` and
  `raw/{family}/{dataset}/{file stem}/{sha256_12}.{zip|csv}` (immutable, content-addressed).
  `raw_path` in the manifests is relative to this folder.
- **Checks.** ZIP signature, member count and size limits, unsafe or duplicate member names
  and per-member SHA-256 (`validate_zip_archive`); CSV files must be `;`-separated and not
  HTML. Bad content and network errors are retried with backoff; 403/429 stop the run.
- **Sample (2026-11-11T00:18-03:00).** Latest period of each of the 7 datasets: 7 of 7
  downloaded (HTTP 200), all checks passed.
- **Out of scope** unless the developer decides otherwise: FII `DFIN` (index of financial
  statement documents) and the other fund folders of the portal (`FI/`, `FIE/`, `ADM_FII/`).

## Name sources for FIDC cedentes (2026-11-12, `decision_0041`)

The FIDC monthly report publishes the cedente CPF or CNPJ but no name. PJ cedente names come
from public registries, in this order: TaxMiner entity catalog, CVM registries (exact CNPJ),
Receita Federal CNPJ open data (corporate name of the CNPJ root), CVM registries by CNPJ root.

| Item               | CVM registries                                                                                                                       | Receita Federal CNPJ open data                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Files              | `FI/CAD/DADOS/cad_fi.csv`, `FI/CAD/DADOS/registro_fundo_classe.zip`, `CIA_ABERTA/CAD/DADOS/cad_cia_aberta.csv` (dados.cvm.gov.br) | `Empresas0.zip` … `Empresas9.zip` of the month (`arquivos.receitafederal.gov.br`, public share `Dados/Cadastros/CNPJ/{yyyy-mm}`) |
| Format             | Latin-1, `;`, stray quotes (read with `quote = ""`)                                                                                  | No header, `;`, quoted, Latin-1: CNPJ root, corporate name, legal nature, responsible qualification, capital, size, federal entity |
| Collector          | `scripts/collect_cvm_registries.R` (`src/collect/collect_cvm_registries.R`)                                                          | `scripts/collect_rfb_cnpj.R [yyyy-mm]` (`src/collect/collect_rfb_cnpj.R`)                                          |
| Storage            | `investment_fund_reports/registries/raw/{stem}/{sha256_12}.{ext}`, manifest `manifests/registries.csv`                               | `investment_fund_reports/registries/raw/rfb_cnpj/{yyyy-mm}/EmpresasN.zip`, manifest `manifests/rfb_cnpj.csv`       |
| Reader             | `src/data/cvm_registry_names.R` (cache `processed/cnpj_names.rds`)                                                                   | `src/data/rfb_company_names.R`: zips read as a stream, only the cedente roots kept (cache `processed/rfb_company_names.rds`) |
| Collected          | 2026-11-12, 3 of 3 files                                                                                                             | 2026-10, 10 of 10 files (HTTP 200, about 1.4 GB)                                                                   |

- Generic user agent, spaced requests; 401/403/429 stop the run. Names are kept as published.
- Coverage (Cedentes package, 2026-11-12): 10,272 of 10,274 PJ cedentes named (Receita 8,943;
  catalog 986; CVM companies 288; fund service providers 35; funds and classes 20). Each name
  shows its source in the app and on the published site.
- Corporate names of individual entrepreneurs (MEI) may include the owner's CPF, as published by
  the Receita Federal.
