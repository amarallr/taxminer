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

## `investment_fund_reports` (Phase 4, `decision_0024`)

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
schemas or search, and are not consumed by `document_relationships` unless a
later decision extends Phase 3.

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
