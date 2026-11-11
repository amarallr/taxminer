# TaxMiner architecture

## Scope and status

This document defines the proposed architecture for the product phases:
Phase 1 (data collection, structuring and search, in subphases 1.1–1.3, one
per source family) and Phase 2 (cross-source intelligence), per `decision_0025`.
It is architecture work only: it does not authorize source
discovery, data acquisition, MVP implementation, external model processing, or
release. Requirements and phase criteria remain subject to developer review.

## Logical modules and contracts

TaxMiner uses one repository and one local Shiny application with independent
areas. `src/collect/` discovers and acquires permitted public source records;
`src/data/` extracts and normalizes documents; `src/intelligence/` serves
search, analysis, and cited relationships; `src/common/` contains shared
contracts and validation that do not couple the source-specific schemas.

Collect emits a source manifest and immutable raw-document references. Each
record carries its source family, source URL, retrieval time, content hash,
source version when available, retrieval outcome, and retry/resume metadata.
Data consumes those records and emits versioned source-specific tables plus
quality results and field-level lineage. Intelligence consumes accepted,
versioned tables through read-only contracts and returns results with direct
citations to source documents and pages. Optional model services cannot be a
dependency for collection, extraction, or deterministic search.

No module may read `restricted/` or `tmp/`. Raw and derived pipeline inputs are
limited to verified public records and synthetic fixtures. The architecture
does not select a storage engine or vector provider yet; those choices require
measured criteria and an explicit dependency decision.

## Independent source domains

### Consultation decisions

The `tax_consultation_decisions` domain preserves the original Portuguese text
and distinguishes original act/document classifications. Its conceptual
entities are `consultation_decisions`, `decision_documents`, `decision_sources`,
`decision_versions`, `legal_references`, `collection_events`, and
`collection_errors`. Stable IDs derive from a verified issuing authority,
original document type, official number/year, and source identity. Different
acts are never merged just because their text or number resembles another act.
Ementa-only references remain distinguishable from full-text documents.

### Financial disclosures and notes

The `financial_disclosures` domain is independent of decisions. Its conceptual
entities are `companies`, `financial_reports`, `financial_report_versions`,
`financial_notes`, `financial_tables`, `financial_sources`, `financial_pages`,
`financial_collection_events`, and `financial_quality_issues`. A note retains
its report, company identifier evidence, reporting period, scope, note number,
table hierarchy, page, original unit/value, normalized value when justified,
and parser uncertainty. Company matching is evidence-backed; unresolved or
ambiguous matches remain unresolved rather than being forced.

Implemented (Data P03, `decision_0027`): `scripts/extract_financial_notes.R`
reads the Collect P04 catalog and manifest, extracts each downloaded package
once and writes `financial_reports` and `financial_notes` as Parquet parts per
package with `arrow`. An extraction index keyed by package SHA-256 and the
extraction signature (`src/common/signatures.R`) makes reruns incremental, so
consolidation can run while the collection is still adding packages. Layout in
`docs/data_dictionary.md`.

### Investment fund reports

The `investment_fund_reports` domain (`decision_0024`) is independent of
decisions and financial disclosures. It covers four CVM fund families, each a
separate namespace with its own manifest, schema versions, coverage and quality:

| Family | CVM open-data datasets (verified 2026-11-10) |
|---|---|
| `fii` (real estate funds) | `INF_MENSAL`, `INF_TRIMESTRAL`, `INF_ANUAL` (yearly ZIPs since 2016), `DFIN` (yearly CSV index of financial statements) |
| `fidc` (receivables funds) | `INF_MENSAL` (monthly ZIPs, older years under `HIST/`) |
| `fip` (private equity funds) | `INF_TRIMESTRAL` (yearly CSV 2010–2023), `INF_QUADRIMESTRAL` (yearly CSV since 2024) |
| `fiagro` (agribusiness funds) | `INF_MENSAL` (monthly ZIPs since 2025-05) |

Conceptual entities: `funds`, `fund_reports`, `fund_report_files`,
`fund_report_tables`, `fund_report_rows`, `fund_collection_events` and
`fund_quality_issues`. Each consolidated row keeps:

- the family, dataset, official table name and layout version;
- the reference period, the fund CNPJ (original and normalized) and the
  administrator identifier when published;
- the original values as text;
- lineage: `zip_sha256`, `source_file` and `source_line`.

Repeated keys and resubmitted versions are diagnosed and kept, never dropped or
summed. The FII financial statements listed in `DFIN` are documents, not
tables; reading them is a later decision, not part of the first Phase 1.3 sample.

### Cross-source relationships

`document_relationships` is a separate intelligence domain that may
consume only Phase 1 datasets (subphases 1.1–1.3) that have explicit human
acceptance; it is MVP Phase 2 (`decision_0025`).
Every relationship is a
cited hypothesis with typed source and target IDs, relationship type, evidence
spans/pages, confidence, uncertainty, method/version, and human review state.
It does not state or infer misconduct, liability, or legal effect.

## Data flow and phase gates

Phases were restructured by `decision_0025`.

1. **Phase 1 — data collection, structuring and search.** Three independent
   subphases, one per source family. None depends on another.
   - **1.1** collects, processes and searches public consultation decisions.
   - **1.2** collects and processes financial disclosures and searches
     financial notes.
   - **1.3** collects, consolidates and searches CVM investment fund reports
     (FII, FIDC, FIP, FIAGRO; `decision_0024`).
2. **Phase 2 — cross-source intelligence.** It relates the Phase 1 datasets
   through cited hypotheses with evidence and human review. A relationship may
   use only datasets whose subphase has explicit human acceptance.

Each subphase and phase has separate implementation, testing, human
acceptance, release, and operations states. No downstream phase starts until its prerequisites and
human gates are met. This planning document is not phase acceptance.

## Shared contracts in `src/common/` (Common P07 stage 02)

These are base-R primitives that any source family may use (`decision_0023`, `work_0024`,
`req_0015`–`req_0017`). They were re-implemented from requirements; each function header
records its provenance (`origin:`).

- **`safe_io.R`**
  - `validate_contained_path`: rejects absolute, drive-letter and `..` paths, and paths that
    resolve outside the root.
  - `write_validated_atomic`: writes to a temporary neighbour file, reads it back, validates
    it, publishes with rollback, and keeps the previous version on failure.
  - `recover_from_rollback` and `read_rds_recoverable`: a corrupt state file is preserved and
    never read as success.
  - `validate_zip_archive`: checks member count and size limits, unsafe or duplicate names,
    and extraction integrity, and returns per-member SHA-256.
- **`signatures.R`**
  - `compute_signature_hash`: deterministic SHA-256 of objects and files, independent of the
    R version.
  - `code_signature`: signature of an explicit file list, with no traversal.
  - `transformation_signature`: signature of function arguments and bodies.
- **`execution_policy.R`**
  - `resolve_execution_policy`: checkpoint reuse never forces a download.
  - `record_attempt`: records `in_progress`, then `completed` or `failed`.

Adoption by `src/collect/` is a separate, later work item. Nothing changes while the DFP
collection runs.

## Cross-cutting controls

Source terms, availability, rate limits, coverage, and document integrity are
verified before acquisition. Schemas are versioned; source values and original
classifications are retained alongside normalized values. Failures and
uncertainty are first-class records. Tests use public or synthetic inputs.
Logs exclude credentials and protected content. External AI processing requires
a separate privacy review and authorization.

## Open design decisions

- Confirm official source families, identifiers, available versions, and reuse
  conditions before defining complete coverage.
- Select storage and query engines only after benchmarking representative
  public samples and validating required R packages.
- Define quantitative coverage, search relevance, citation accuracy, and
  performance thresholds with the developer before implementation. Draft
  measurable thresholds for review are in `docs/requirements.md` and remain
  unaccepted.
- Decide company-identity evidence rules and human-review thresholds before
  financial matching or cross-source relationship work.

## Architecture review — 2026-11-10

Codex review: the module boundaries and separation of the three source domains
are coherent for planning. Before implementation, refine ID fallback behavior
for acts lacking an official number/year; make company identifiers typed by
scheme (for example, CNPJ) and preserve the original value separately from any
normalized value; and define how confidence is calibrated for relationships.
Coverage, relevance, citation-accuracy, and performance thresholds remain
developer decisions. This review is not developer approval of the architecture
or requirements.

## Proposed resolutions of open review items — 2026-11-10

Status: proposed by Claude Code during the project review; accepted by the
developer on 2026-11-10T17:46:38-03:00 (`acc_0003`). They
close the three items from the review above so that `req_0003` can be decided.

1. **ID fallback.** Primary key:
   `{family}:{issuing_authority_code}:{original_document_type_code}:{number}/{year}`.
   When the number or year is absent, use
   `{family}:{issuing_authority_code}:{original_document_type_code}:h{sha256_12}`,
   where `sha256_12` is the first 12 hex characters of the SHA-256 of the
   normalized canonical source URL plus the publication date. Record
   `id_method = official | fallback`. A fallback ID is never merged with an
   official ID automatically; promotion requires a recorded decision.
2. **Company identifiers.** Store `company_identifier_scheme` (`cnpj`,
   `cvm_code`, `name_only`), `company_identifier_original` exactly as published,
   and `company_identifier_normalized` (CNPJ: 14 digits, check digits
   validated). A match needs at least one verified identifier; `name_only`
   matches stay `unresolved`. Keep the root CNPJ (8 digits) as a derived field
   for group-level grouping only, never as identity.
3. **Relationship confidence.** Phase 2 (numbered Phase 3 before `decision_0025`) starts with deterministic rules only
   (explicit citation of a legal act number or of a decision ID). Confidence is
   a categorical `evidence_level` (`explicit_citation`, `shared_legal_basis`,
   `topic_similarity`), not a probability. A numeric score is introduced only
   after calibrating on the adjudicated set of at least 50 links defined in
   `docs/requirements.md`.
4. **Storage (proposal for the Phase 1.1 sample).** Parquet files written with
   `arrow`, queried with `duckdb`; full-text search through DuckDB's `fts`
   extension. Re-evaluate against the latency threshold before scaling. Adding
   `arrow`, `duckdb`, `httr2`, `xml2`, `pdftools` and `shiny` to `DESCRIPTION`
   happens only when the first code that uses each one is written.
5. **Shiny location.** The single application lives in `prototype/` (as Common
   P03/P06 prescribe) and contains presentation code only. Business logic stays
   in `src/`; each phase is a separate Shiny module that is enabled only when
   its dataset exists.

## Acceptance — 2026-11-10T17:46:38-03:00

The developer explicitly accepted this architecture, the proposed resolutions
above and the thresholds in `docs/requirements.md` (`acc_0003`,
`decision_0014`). Acceptance closes Common P03 planning; it does not authorize
bulk collection, release, or any MVP acceptance.
