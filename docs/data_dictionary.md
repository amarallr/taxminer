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
`<TAXMINER_DATA_DIR>/financial_disclosures/processed/`, one zstd Parquet part
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

Implemented by `src/data/consolidate_fund_reports.R` (Data P04, `decision_0029`).
Outputs under `<TAXMINER_DATA_DIR>/investment_fund_reports/processed/`, one zstd
Parquet part per source file and member (current version of each file):
`{family}/{table_name}/part-{file stem}--{member stem}.parquet`. A table is read
across periods with `open_fund_table()`, which unifies the layouts.

| Field | Meaning |
|---|---|
| `family` | `fii`, `fidc`, `fip` or `fiagro`. |
| `dataset` | CVM dataset, for example `INF_MENSAL`. |
| `table_name` | Member file name without the period, for example `inf_mensal_fidc_tab_I`; matches the META file `meta_{table_name}.txt`. |
| `layout_version` | First 12 hex digits of the signature of the member's header (column names in order). |
| `reference_period` | Period of the source file (`yyyy` or `yyyy-mm`); the row's own period stays in its CVM column (`Data_Referencia` or `DT_COMPTC`). |
| `fund_cnpj_original` | Fund identifier as published, from the first present of `CNPJ_Fundo_Classe`, `CNPJ_Classe`, `CNPJ_FUNDO` (case-insensitive). |
| `fund_cnpj_normalized` | 14 characters with check digits validated (numeric or alphanumeric CNPJ); `NA` when invalid or empty. |
| `zip_sha256` / `source_file` / `source_line` | SHA-256 of the stored file, member name and line number (header is line 1). |
| CVM columns | Every published column with its published name and original text value; a CVM column that clashes with a TaxMiner column gets the prefix `cvm_`. |

Members are read as Latin-1 and split on `;` without quote handling: the
published files carry literal quotes inside text and a constant field count.

### Layout inventory (Data P04 step 00, consolidation of 2026-11-11)

Measured on the 102 files collected on 2026-11-11 (3,094 members, 12.16 million
rows). A layout is a distinct header; periods are those of the members.

| Family | Tables | Rows | Layout breaks |
|---|---:|---:|---|
| FII | 32 (`inf_mensal` 3, `inf_trimestral` 16, `inf_anual` 13) | 1,397,634 | Every table changes between 2020 and 2021; `inf_mensal_fii_ativo_passivo` also between 2018 and 2019. Column counts mostly unchanged, so the break is in names. |
| FIDC | 18 (`tab_I`–`tab_X_7`) | 10,680,382 | 2020-11 for `tab_I`–`tab_VII`, `tab_X_1_1`, `tab_X_5` and `tab_X_7` (`tab_I` also at 2019-11: 67, 104 and 109 columns); 2023-10 for `tab_X_1`–`tab_X_4` and `tab_X_6`; `tab_X` first appears in 2023-10, `tab_X_1_1` and `tab_X_7` in 2019-11. |
| FIP | 2 | 74,391 | `inf_trimestral_fip` (2010–2023, 54 columns, `CNPJ_FUNDO`) is replaced by `inf_quadrimestral_fip` (2024–2026, 55 columns, `CNPJ_FUNDO_CLASSE`). |
| FIAGRO | 2 | 10,109 | None (2025-05 to 2026-10). |

Quality records of that run: `duplicate_row` 13,603 (10,636 in FII),
`repeated_fund_period` 1,773 member-level records, `column_not_in_dictionary`
and `dictionary_column_absent` 1,251 each (the META files describe the current
layout only), `resubmitted_versions` 10. Every fund CNPJ passed the check digits.

`fund_quality_issues/` (one part per source file) holds `family`, `dataset`,
`table_name`, `reference_period`, `zip_sha256`, `source_file`, `source_line`
(empty for member-level issues), `issue_type`, `detail` and `row_count`.

| `issue_type` | Level | Meaning |
|---|---|---|
| `field_count_mismatch` | row | The line has a different number of fields from the header; values kept, missing fields empty. |
| `duplicate_row` | row | Identical to an earlier line of the same member. |
| `empty_fund_identifier` / `invalid_cnpj` | row | Fund CNPJ empty or failing the check digits. |
| `missing_fund_identifier` | member | No fund CNPJ column in the header. |
| `repeated_fund_period` | member | Rows sharing fund and period (expected in multi-row tables such as assets). |
| `resubmitted_versions` | member | Fund-periods with more than one value of `Versao`. |
| `column_not_in_dictionary` / `dictionary_column_absent` | member | Header differs from the META dictionary. |
| `duplicate_column` / `no_dictionary` | member | Repeated header name; no META entry for the table. |

`consolidation_index.rds` records, per member, the source file SHA-256, the
consolidation signature, `layout_version`, column and row counts, issue count
and the output path and SHA-256. Reruns skip files whose hash and signature are
unchanged; parts of tables that disappear from a new file version are removed.
Retrieval provenance (`source_url`, `listing_last_modified`, `retrieved_at`)
stays in the Collect P05 manifests.

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
