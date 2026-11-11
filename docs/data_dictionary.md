# Initial TaxMiner data dictionary

This is a conceptual dictionary for architecture review. It defines no physical
database, migration, collection, or MVP implementation. Preserve original
Portuguese content and original source classifications. Schema version and
field definitions require review before implementation.

## `tax_consultation_decisions`

| Field | Meaning |
|---|---|
| `consultation_decision_id` | Stable typed identifier for one verified act. |
| `consultation_decision_type` | Original typed classification, not inferred equivalence. |
| `consultation_decision_number` / `consultation_decision_year` | Official number and year when present. |
| `issuing_authority` | Authority as stated by the source, with normalized form kept separately if needed. |
| `consultation_decision_date` / `publication_date` | Source dates, preserving unknown or absent values. |
| `tax_topic` | Classified topic with taxonomy/version provenance. |
| `summary_text` / `full_text` | Original-language source text; ementa-only records remain explicit. |
| `legal_basis` | Cited legal references with source spans where available. |
| `source_url` / `download_timestamp` | Retrieval provenance. |
| `document_hash` | Content integrity identifier for the acquired version. |
| `consultation_decision_status` | Source status, with evidence and observation date. |

Supporting records distinguish a legal act from its document manifestations,
source listings, versions, retrieval events, and errors. Duplicates across
sources are linked as possible manifestations until verified; different acts
are never collapsed based on text similarity alone.

## `financial_disclosures` and `financial_notes`

| Field | Meaning |
|---|---|
| `financial_disclosure_id` | Stable identifier for a report filing/document. |
| `company_identifier_scheme` / `company_identifier_original` | Identifier type (for example CNPJ) and exact source value. |
| `company_identifier_normalized` / `company_identity_evidence` | Normalized value and evidence used to verify the company match; unresolved cases remain explicit. |
| `reporting_period` | Period exactly as supported by source evidence. |
| `report_scope` | Consolidated, individual, or other source-stated scope. |
| `financial_note_id` / `note_number` | Stable note identity within a report version and its original label. |
| `table_path` | Hierarchical table location within a note/report. |
| `page_number` | Source page reference for traceability. |
| `line_item_label` | Original label, optionally paired with a normalized label. |
| `value_original` / `unit_original` | Value and unit as published. |
| `value_normalized` / `unit_normalized` | Derived values only with documented conversion and method. |
| `source_url` / `document_hash` / `version` | Source and version provenance. |
| `extraction_status` / `uncertainty` | Parsing and matching outcomes, including unresolved cases. |

Company, filing, report version, note, table, and page relationships must remain
traceable. Notes cannot depend on the consultation-decision schema or search.

### Implemented Parquet layout (Data P03, `decision_0027`)

Written by `src/data/consolidate_financial_notes.R` under
`<TAXMINER_DATA_DIR>/processed/financial_disclosures/`, one zstd Parquet part
per filing package (`part-{source_document_id}.parquet`). Columns and types are
fixed by `financial_report_columns` and `financial_note_columns`, so every part
shares one schema.

| Table | Grain | Key columns |
|---|---|---|
| `financial_reports/` | One row per downloaded filing package | `report_id`, `source_document_id`, `report_type`, `cvm_code`, `company_cnpj`, `company_name`, `reporting_period_end`, `document_version`, `source_url`, `package_sha256`, `document_hash`, `page_count`, `note_count`, `extraction_status`, `extraction_error`, `confidence`, `extraction_signature`, `extracted_at` |
| `financial_notes/` | One row per extracted note | `note_id`, `report_id`, `source_document_id`, `cvm_code`, `company_cnpj`, `reporting_period_end`, `note_set`, `note_number`, `note_title`, `note_text`, `source_page_start`, `source_page_end`, `document_hash`, `unit_scale`, `unit_scale_source`, `extraction_status`, `confidence`, `extraction_signature` |

`extraction_index.rds` records `source_document_id`, `package_sha256` and
`extraction_signature` per package. A rerun skips a package only when all three
match; a new package hash or a change to the extraction functions or heading
patterns reprocesses it. Packages without notes keep their report row and have
no notes part. `company_name` comes from the CVM open-data index decoded as
Latin-1 (`risk_0016`). Raw packages are only read.

## `investment_fund_reports` (Phase 1.3, `decision_0024`, `decision_0025`)

Conceptual contract; the column inventory per subfamily, table and layout comes
from Data P04 step 00 (CVM `META/` dictionaries) and is not yet verified.

| Field | Meaning |
|---|---|
| `fund_report_row_id` | Stable row identity: `{family}:{dataset}:{table_name}:{zip_sha256_12}:{source_line}`. |
| `family` | `fii`, `fidc`, `fip` or `fiagro`. |
| `dataset` / `table_name` / `layout_version` | CVM dataset (for example `INF_MENSAL`), official table file name, and layout version inferred from the dictionaries and headers. |
| `reference_period` | Period exactly as published (`DT_COMPTC` or equivalent). |
| `fund_cnpj_original` / `fund_cnpj_normalized` | Fund CNPJ as published and normalized to 14 digits with check digits validated; invalid values stay unresolved. |
| `administrator_cnpj_original` | Administrator identifier when the table publishes it. |
| CVM source columns | Kept with their published names; values kept as text (`value_original`); typed values only with documented conversion. |
| `zip_sha256` / `source_file` / `source_line` | File-level lineage. |
| `source_url` / `listing_last_modified` / `retrieved_at` | Retrieval provenance; republished files are separate versions. |
| `quality_issue` | Repeated key, resubmission, invalid CNPJ, missing mandatory field or unexpected column; rows are never dropped or summed. |

Fund reports cannot depend on the consultation-decision or financial-note
schemas or search. `document_relationships` (Phase 2) may use them only after
Phase 1.3 has explicit human acceptance.

## `document_relationships`

| Field | Meaning |
|---|---|
| `relationship_id` | Stable identifier for a reviewed or proposed link. |
| `source_document_id` / `target_document_id` | Typed references into independently versioned source domains. |
| `relationship_type` | Explicit hypothesis category and vocabulary version. |
| `evidence_citations` | Source spans/pages supporting the hypothesis. |
| `confidence` / `uncertainty` | Method-scoped estimate and unresolved evidence. |
| `method_version` | Reproducibility metadata for deterministic or model-assisted analysis. |
| `human_review_status` | Proposed, reviewed, accepted, or rejected state with reviewer evidence. |

Relationships are research hypotheses, not automatic legal conclusions or
misconduct findings.
