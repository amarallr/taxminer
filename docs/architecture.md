# TaxMiner architecture

## Scope and status

This document defines the proposed architecture for the three independent
product phases. It is architecture work only: it does not authorize source
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

### Cross-source relationships

`document_relationships` is a separate, optional intelligence domain that may
consume only the two independently accepted datasets. Every relationship is a
cited hypothesis with typed source and target IDs, relationship type, evidence
spans/pages, confidence, uncertainty, method/version, and human review state.
It does not state or infer misconduct, liability, or legal effect.

## Data flow and phase gates

1. Phase 1 collects, processes, and independently searches public consultation
   decisions.
2. Phase 2 independently collects and processes financial disclosures and
   searches financial notes without requiring Phase 1 search.
3. Phase 3 integrates both accepted datasets through cited hypotheses.

Each phase has separate implementation, testing, human acceptance, release,
and operations states. No downstream phase starts until its prerequisites and
human gates are met. This planning document is not phase acceptance.

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
  performance thresholds with the developer before implementation.
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
