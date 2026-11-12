# Hybrid document processing and token budget — diagnosis and plan

Status: **proposed** (`work_0026`). Requested on 2026-11-11 through
`.claude/tunning.txt` (CO-STAR prompt: MarkItDown, Markdown + Parquet +
metadata, selective retrieval, token budget). Only stages 01 (diagnosis) and
the plan are done. Nothing was installed, no document was sent to an external
service, and no LLM was called.

## 1. Diagnosis (verified on 2026-11-11)

### Tooling

| Item | Finding |
|---|---|
| Python | Not installed. `python` resolves only to the Microsoft Store alias (`WindowsApps\python.exe`); `py` and `pip` absent. |
| MarkItDown | Latest release `v0.1.9` (2026-10-21, GitHub and PyPI). Requires Python `>=3.10,<3.15`. Core deps: `beautifulsoup4`, `markdownify`, `magika`, `requests`, `defusedxml`, `charset-normalizer`, `certifi`. Extras used here: `[pdf]` (`pdfminer-six`, `pdfplumber`), `[docx]` (`mammoth`, `lxml`), `[xlsx]` (`openpyxl`, `pandas`), `[pptx]` (`python-pptx`). |
| MarkItDown limits (README) | Output is "meant to be consumed by text analysis tools", not high-fidelity conversion. Image captioning and audio transcription use web services; the `markitdown-ocr` plugin needs an LLM client; Azure converters are billable cloud calls. Plugins are off by default. It performs I/O with the process privileges; the README recommends `convert_local()`/`convert_stream()`. |
| R side | `arrow` 25.0.1 declared. `duckdb`, `readxl`, `officer` are installed in the system library but not declared. `reticulate` not installed. |
| Governance | `AGENTS.md`: dependencies explicit in `DESCRIPTION`, renv explicit snapshot, no installation, global setting change or new toolchain without explicit authorization. There is no Python environment policy yet. |

### What the project already does (do not duplicate)

| Prompt layer | Existing component |
|---|---|
| A — originals | Content-addressed raw store with append-only manifests, SHA-256 per file and per ZIP member (`src/collect/`, Collect P04/P05). |
| B — text | Note extraction from the PDF attachments embedded in the DFP XML, by page, with `pdftools` (`src/data/extract_financial_notes.R`, `decision_0026`); notes kept with page start/end. |
| C — tables | Fund reports: 12.16 million rows in Parquet with lineage to file and line (`src/data/consolidate_fund_reports.R`). Notes: report and note tables in Parquet (`decision_0027`). **Note tables are not extracted yet** (handoff). |
| D — metadata | Consolidation and extraction indexes, quality-issue tables, signatures (`src/common/signatures.R`), validated atomic writes (`safe_io.R`, `parquet_io.R`). |
| Cache / incremental | Per-file hash + transformation signature skip (notes, funds, fund directory). |
| Structured queries | `src/intelligence/search_fund_reports.R` (work_0022, in progress): deterministic filters with source-file citations; no LLM. |
| Path safety | `validate_contained_path()`; protected `.restricted/` and `.tmp/` never read. |
| LLM integration | **None.** Requirements make RAG optional (Intelligence P02); no provider, key or token measurement exists. |

### Source formats that matter

- DFP packages: structured XML with the statements, PDF attachments in base64
  (notes), `DadosDocumento.xlsx`, form XMLs (`docs/data_sources.md`).
- Fund reports: Latin-1 CSV (already in Parquet).
- Soluções de Consulta (Phase 1.1, suspended): HTML/PDF, not collected.
- No DOCX or PPTX source is in scope today. Their converters would be built and
  tested only on synthetic fixtures.

### Conflicts and gaps

1. The prompt prioritises Python. The project is R/renv with explicit
   dependencies, and Python is absent. Adding a Python toolchain is a
   governance decision (new `decision_*`) plus an installation the developer
   must authorise.
2. The prompt's example question (financial expenses 2021–2025) needs the
   **statement line items**, which the project does not consolidate yet. The
   DFP XML carries them, and the CVM open-data portal also publishes
   statements as CSV; that source is **not verified yet**. A Parquet of line
   items with company, period, scope (individual or consolidated), scale and
   sign answers the question deterministically. MarkItDown is not needed for
   it.
3. Measuring tokens needs a tokenizer. Exact counts for Claude come from the
   API's token-counting endpoint, which sends the text to an external service.
   That needs authorization (and an API key the project does not hold). Without
   it, only character counts and labelled estimates are possible, and the
   prompt forbids claiming savings without measurement.
4. Benchmark scenarios A–C and the fidelity metric need a model run and an
   adjudicated question set; neither exists.

## 2. Architecture fit

Markdown is an intermediate text representation, never a replacement for
Parquet. Each layer stays where the project already puts it:

```
Collect (raw store, manifests, SHA-256)
  └─ Data
       ├─ text:   PDF/DOCX/PPTX/HTML ──► Markdown per document (MarkItDown or pdftools)
       │                                 + page/slide/section map (JSON)
       ├─ tables: XML statements, XLSX, CSV, PDF tables ──► Parquet (explicit schema,
       │          decimal as text + scale/sign columns, lineage: hash, page, sheet, cell range)
       ├─ chunks: Markdown sections ──► chunk Parquet (chunk_id, document_id, page span,
       │          section path, text, char_count, token_count?)
       └─ indexes and signatures (existing pattern)
  └─ Intelligence
       ├─ deterministic query layer (arrow/duckdb, read-only, allowlisted datasets,
       │  parameter validation; no LLM-generated SQL)
       ├─ keyword/metadata search over chunks (duckdb fts or base R)
       ├─ context builder: budget (minimal/balanced/extended/full), dedup,
       │  citations per item, evidence class (documented/calculated/inferred/not found/unverifiable)
       └─ LLM call (only after an explicit provider decision)
```

Python, if approved, runs as a **batch converter called from R** through
`system2()` on an allowlisted file list. It writes Markdown and JSON next to
the R outputs, so the R pipeline stays the orchestrator and no `reticulate`
coupling is needed. The Python environment would be a project-local `.venv`
with a pinned `requirements.lock` (hashes), never global.

## 3. Plan (increments, each with its own authorization)

| # | Increment | Needs | Output |
|---|---|---|---|
| 0 | This diagnosis and plan | — | This file, `work_0026` |
| 1 | **Spike, no install:** compare the current `pdftools` note text with what a table-aware extractor would need; pick 5 public DFP packages already collected; record where tables are lost | Nothing new | Measured gap list (pages, tables) |
| 2 | Python toolchain decision and local install: Python 3.12 user-level, project `.venv`, `markitdown[pdf,docx,xlsx,pptx]==0.1.9` pinned with hashes; plugins, OCR and Azure off | **Developer authorization** (installation, new toolchain) | `decision_*`, `requirements.lock`, setup script, CI step |
| 3 | MarkItDown spike on the same 5 packages: Markdown quality, page boundaries, tables recovered vs `pdftools`, run time | Increment 2 | Benchmark table in this doc; go/no-go for MarkItDown on notes |
| 4 | Statement line items in Parquet: verify the CVM DFP CSV source (or parse the DFP XML), explicit schema (company, CNPJ, period, scope, account code, label, value as text and as decimal, scale, sign, version, lineage) | Source verification only; same family `financial_disclosures` | Parquet + tests (negative values, scale, nulls vs zero, restated versions) |
| 5 | Note tables (pending in Data P03): from MarkItDown/pdfplumber or `pdftools` layout, to Parquet with page and table ids | Increment 3 decision | `financial_note_tables/` |
| 6 | Chunking of note Markdown and keyword/metadata search; deterministic query layer over line items and funds | Declaring `duckdb` in `DESCRIPTION` (already installed; renv snapshot) | `src/intelligence/` modules + tests |
| 7 | Context builder with budget modes and evidence classes; token counts as characters + labelled estimates | — | Module + tests |
| 8 | Token measurement and LLM call | **Developer authorization**: provider, model, key handling, which data may leave the machine (public CVM data only) | Measured tokens/cost; scenarios A–C |
| 9 | Benchmark A–C and fidelity/coverage metrics on an adjudicated question set | Questions and answers adjudicated by the developer | Report; homologation request |

Synthetic fixtures (multi-sheet XLSX with formulas and merged cells, PPTX with
a table, long DOCX, scanned PDF) are written by the tests. No protected or
private document is used.

## 4. Risks

- **Toolchain drift:** a second language doubles setup and CI cost. Mitigation: pinned lock with hashes, a single converter entry point, CI job.
- **Silent loss:** MarkItDown may drop page boundaries, merged cells or table structure. Mitigation: never the only representation; compare against `pdftools`/XML; quality issues recorded per document.
- **Data egress:** OCR plugin, image captioning and Azure converters call external services. Mitigation: disabled by configuration and by a test that fails if they are enabled.
- **Untrusted input:** converters open files with process privileges. Mitigation: `convert_local()` on allowlisted paths from manifests only, contained-path validation, no URL conversion.
- **Unmeasured savings:** forbidden by the prompt. Increment 8 is the first point where savings can be claimed.

## 5. Acceptance criteria (proposed)

- Every Markdown, chunk and table row traces to document SHA-256 and page (or
  sheet and cell range).
- Line items: values, signs, scale and scope match the source XML on an
  adjudicated sample (100%); missing stays distinct from zero.
- Coverage ≥ 98% and factual fidelity ≥ 99% on the adjudicated set (targets
  from the prompt, not observed results).
- Token savings reported only from measured counts, per scenario, with cost.
- Tests for protected-path blocking and for external-service flags pass.
- Phase homologation only with explicit developer acceptance.

## 6. Decisions requested from the developer

1. Authorise a Python 3.12 toolchain (user-level install, project `.venv`,
   pinned MarkItDown 0.1.9) — or keep the pipeline R-only and use MarkItDown
   nowhere.
2. Order: start with increment 4 (statement line items, deterministic, no new
   toolchain) or increment 1–3 (MarkItDown on notes).
3. LLM provider and whether public CVM text may be sent to it for token
   counting and answers.

Answer of 2026-11-11: item 1 authorised (`decision_0031`). Items 2 and 3 were
returned to Claude for a recommendation; the choice stays with the developer.
