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
| req_0009 | Search financial notes independently | Search works without Phase 1; validated company/CNPJ, period, and note filters with source-page citations. |
| req_0010 | Evidence-based `document_relationships` | Both datasets accepted; cited links include traceability, confidence, uncertainty, tests, and human review; no misconduct findings. |
| req_0011 | Three independent MVP acceptance gates | Each phase has reproducible tests, operational evidence, limitations, explicit human acceptance, and distinct implementation/test/acceptance/release/operations states. |

## Phase gates

- **Phase 1:** req_0004 → req_0005 → req_0006. The acquisition scope and
  quantitative coverage thresholds require review before collection.
- **Phase 2:** req_0007 → req_0008 → req_0009. Financial-note search remains
  independently usable without Phase 1.
- **Phase 3:** req_0010 only after explicit acceptance of Phases 1 and 2.

Testing, human acceptance, release, and operations are separate gates. A passed
test does not imply acceptance or release. The current register remains the
status authority; this draft does not change its proposed requirements.
