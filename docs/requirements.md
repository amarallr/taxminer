# TaxMiner requirements and phase acceptance

This is a review draft derived from `docs/project_management/requirements_register.csv`
and the current prompt pack. All requirements remain proposed until reviewed.
No MVP work is authorized by this document.

| ID | Requirement | Minimum evidence for acceptance |
|---|---|---|
| req_0001 | Reproducible local environment and protected boundaries | Root validator passes; explicit dependency lock restores; public/synthetic fixtures only; protected directories excluded without being accessed. |
| req_0002 | Independent assistant readiness | Per tool, record installation, authentication, functional test, human acceptance, and unsupported controls separately. |
| req_0003 | Source-specific architecture and measurable acceptance | Typed source schemas, stable IDs, provenance, module contracts, phase criteria, and developer review documented. |
| req_0004 | Acquire public `tax_consultation_decisions` | Verify official sources and terms; record per-document outcomes, hashes, manifest, retries/resume, and measured coverage. |
| req_0005 | Process `tax_consultation_decisions` reproducibly | Preserve Portuguese source text and original document type; validate mappings, deterministic IDs, deduplication, queryable output, and lineage. |
| req_0006 | Search consultation decisions independently | Local Shiny search/filter/detail flow on an accepted public sample; official citations and relevance/citation checks recorded. |
| req_0007 | Acquire public `financial_disclosures` independently | Verify source, terms, availability; record document outcomes, hashes, versions, coverage, and manifest. |
| req_0008 | Process `financial_notes` independently | Preserve report/note/table hierarchy, company evidence, period, scope, units, pages, revisions, queryable output, and uncertainty. |
| req_0009 | Search financial notes independently | Search works without Phase 1.1; validated company/CNPJ, period, and note filters with source-page citations. |
| req_0010 | Evidence-based `document_relationships` (Phase 2) | Only accepted Phase 1 datasets; cited links include traceability, confidence, uncertainty, tests, and human review; no misconduct findings. |
| req_0011 | Independent MVP acceptance gates (subphases 1.1–1.3 and Phase 2, `decision_0025`) | Each subphase and phase has reproducible tests, operational evidence, limitations, explicit human acceptance, and distinct implementation/test/acceptance/release/operations states. |
| req_0012 | Acquire public `investment_fund_reports` independently (FII, FIDC, FIP, FIAGRO) | Verify CVM open-data sources, terms and crawl delay per family; record per-file outcomes, hashes, versions, coverage and manifest; no dependency on other families. |
| req_0013 | Consolidate `investment_fund_reports` independently | Consolidate per family, table and layout over time; preserve source values and lineage (ZIP hash, file, line); diagnose repeated keys and versions without dropping or summing. |
| req_0014 | Search investment fund reports independently | Local Shiny search works without Phases 1.1, 1.2 or 2; family, fund CNPJ, administrator and period filters with source-file citations. |

## Phase gates

Phases follow `decision_0025`.

- **Phase 1 — data collection, structuring and search.** Three independent
  subphases, each with its own human acceptance:
  - **1.1:** req_0004 → req_0005 → req_0006 (`tax_consultation_decisions`). The
    acquisition scope and quantitative coverage thresholds require review
    before collection.
  - **1.2:** req_0007 → req_0008 → req_0009 (`financial_disclosures`).
    Financial-note search remains independently usable without Phase 1.1.
  - **1.3:** req_0012 → req_0013 → req_0014 (`investment_fund_reports`: FII,
    FIDC, FIP, FIAGRO). It does not depend on Phases 1.1 or 1.2.
- **Phase 2 — cross-source intelligence:** req_0010. A relationship may use
  only Phase 1 datasets that have explicit human acceptance.

Testing, human acceptance, release, and operations are separate gates. A passed
test does not imply acceptance or release. The current register remains the
status authority; this draft does not change its proposed requirements.

## Proposed quantitative thresholds for review

These are draft acceptance thresholds, not observed results or accepted product
criteria. They apply only to a declared, versioned public-source snapshot and
adjudicated public/synthetic test sets. They do not promise completeness of an
unbounded historical archive.

| Measure | Proposed threshold | Measurement method |
|---|---:|---|
| Discovery accounting | 100% of discovered source entries receive a terminal outcome | Manifest counts downloaded, unavailable, out-of-scope, blocked, duplicate, and failed entries; no silent omissions. |
| Acquisition integrity | 100% of downloaded files have a recorded SHA-256 and source URL | Recompute hashes from the public test corpus and compare with manifest. |
| Extraction core-field coverage | ≥99% of applicable required fields on the adjudicated corpus | Publish per-field denominator and missing/uncertain counts; do not convert unknown into a value. |
| Pipeline reproducibility | 100% identical stable IDs and normalized outputs across two runs on the same versioned input | Compare canonical outputs and manifests; document intentional timestamps separately. |
| Search relevance | Precision@10 ≥0.90 and Recall@10 ≥0.80 per dataset | At least 30 independently adjudicated queries per dataset with a versioned relevance set; report confidence intervals and zero-result queries. |
| Citation correctness | 100% of displayed results cite the correct source document; page citations must resolve to the cited page | Human review of every result in the fixed acceptance query set. |
| Local search latency | p95 ≤2 seconds at declared benchmark size | Benchmark 100,000 decision records and 1,000,000 financial-note rows on a named machine profile; report cold and warm runs separately. |
| Cross-source link precision | ≥0.90 precision at the proposed display threshold, with 100% cited evidence | Human-adjudicated set of at least 50 proposed links; unresolved links stay unaccepted and no misconduct labels are allowed. |

If a corpus cannot support a denominator or minimum query/link count, report
the metric as insufficient evidence and do not claim the threshold passed.
Developer review must confirm, revise, or reject these numbers before any MVP
acceptance test is designed. No source collection or MVP implementation is
authorized by these draft thresholds.

## Acceptance — 2026-11-10T17:46:38-03:00

The developer explicitly accepted `req_0003` and the quantitative thresholds
above as the acceptance criteria for the MVP phases (`acc_0003`). The other
requirements keep their own status in `requirements_register.csv`.
