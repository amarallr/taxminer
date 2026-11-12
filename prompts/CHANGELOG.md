# Changelog

## 2026-11-12 — governance master prompt 1.2 (prv_0003, decision_0046)
- Common P08: registry timestamps come from the clock or the commit, never estimated; security-sensitive items need their own explicit confirmation; canonical test command named in phase 07.

## 2026-11-12 — governance master prompt 1.1 (prv_0002, decision_0044)
- Common P08 aligned with `AGENTS.md` and Common P01 after developer approval: lowercase_snake IDs, current protected-area names, read-only agent adapters, state mapping onto the Common P01 status dimensions, location of the immutable layer, and "unavailable" accepted for token estimates. Revisions are logged in `docs/project_management/prompt_revisions.csv`.

## 2026-11-12 — governance master prompt (Common P08)
- Added `common_p08_governance_master.txt`: the developer's TaxMiner Governance master prompt, version 1.0, unchanged below a header that names its layers and precedence (`AGENTS.md` and Common P01 prevail).
- Phase 01 report and the proposed revision 1.1 (not applied) are in `docs/governance_plan.md`, section 9.

## 2026-11-12 — protected areas renamed (decision_0040)
- Every prompt now names the protected areas `.restricted/` and `.tmp/` (formerly `restricted/` and `tmp/`), confidential and never shared or published.

## 2026-11-12 — fund panel requirement and other FIDC tables (decision_0039)
- Common P06 (Phase 1.3) now names requirement `req_0020` (fund reports panel and published dashboard) and states that the published dashboard carries every other FIDC table as one gzip file per fund, read only when chosen, within the 1 GB GitHub Pages limit.

## 2026-11-11 — FIDC cedentes (decision_0038)
- Common P06 (Phase 1.3) adds the Cedentes tab after FIDC (cedentes from report table I; CPF in full by developer decision; out-of-range shares flagged), the FIP investment entity filter and red negative values.

## 2026-11-11 — fund record views (decision_0037)
- Common P06 (Phase 1.3) now describes the fund record views: a Ficha tab in the local app (any fund; Ficha and full series on the whole width) and the Ficha and full series of each family's main tables in the published dashboard, one file per fund loaded on demand, with the same formatting and citations as the app.

## 2026-11-11 — per-family data layout (decision_0028)
- Collect P05 and Data P04 now place raw and processed fund report files under `TAXMINER_DATA_DIR/investment_fund_reports/{raw,processed}/`. Data P04 writes Parquet, since `arrow` is declared (`decision_0027`).

## 2026-11-10 — two-phase MVP structure (decision_0025)
- The mandatory roadmap block in every prompt now defines MVP Phase 1 (data collection, structuring and search) with independent subphases 1.1 Tax Consultation Decisions, 1.2 Financial Statement Notes and 1.3 Investment Fund Reports. MVP Phase 2 (cross-source intelligence) covers the bases accepted in Phase 1.
- Common P01, Common P06, Intelligence P02, Collect P04/P05, Data P04, Common P07 and the README use the new numbering.

## 2026-11-10 — investment fund reports as a new source family (decision_0024)
- Added `investment_fund_reports` (FII, FIDC, FIP, FIAGRO) as a first-class source family and MVP Phase 4, independent of Phases 1–3.
- New prompts: `collect_p05_investment_fund_report_acquisition.txt` and `data_p04_investment_fund_report_consolidation.txt`.
- The mandatory roadmap block in every prompt now lists four phases and the new technical family name; Common P01, Common P06 and Intelligence P02 describe Phase 4 explicitly.
- `common_p07_new_data_sources.txt` (new data sources addendum, `decision_0023`) now governs shared primitives and the acceptance-evidence pattern; its optional-module wording is superseded.

## 2026-11-10 — consistency review
- Aligned internal titles with file names (Common P02–P05 previously said P01–P04) and prefixed every title with its module.
- Replaced the Portuguese directory `data/raw/normas/` with `data/raw/legal_sources/` and the Portuguese entity names in Common P03 with en-US names matching `docs/architecture.md`.
- Updated the single-source CONTEXT paragraph of ten prompts to name both document families.
- Common P01 now prescribes lowercase snake_case IDs (`req_0001`, `work_0001`, …) as used by the registers, and requires an `acceptance_register.csv` row for each `approved` acceptance.
- Collect P04 no longer claims that consultation-decision acquisition already exists.
- README: Intelligence P02 assigned to Phase 2 financial-note search; Collect P03 and Intelligence P01 listed as post-MVP; version labels explained; `tmp/doit.txt` exception referenced.

## 2026-11-10 — per-user environment and safe project relocation
- Updated Common P01 and P02 with current TaxMiner organization: CLI tools per-user, GitHub CLI in user PATH, renv global state under `%LOCALAPPDATA%/R/cache/renv`, project library isolated, and no project-root copying or access to protected areas.
- Corrected setup evidence after verifying `gh` 2.103.3 resolves from its per-user installation. Project relocation must use an explicit reviewed allowlist; old renv state is retained until restore and validation succeed.

## 2026-11-10 — autenticação Gemini e estado GitHub
- Atualizado Common P02: chamada sintética do Gemini retornou o token fixture esperado; validação no terminal RStudio continua pendente.
- O repositório remoto está público; visibilidade pública não define licença de distribuição.

## 1.0 — 2026-11-10
- Documented per-user installation for Codex, GitHub CLI, Gemini CLI and Gemini's Node runtime. Gemini launcher uses only a process-scoped PATH. Recorded Copilot synthetic completion and disabled project indexing inheritance in setup guidance.
- Clarified in Common P02 that Gemini's launcher version check does not substitute for RStudio-terminal, authentication or synthetic-interaction verification.
- Recorded user authorization for per-user PATH entries covering Codex, Gemini CLI, GitHub CLI, Node and npm; machine PATH remains unchanged.

## 1.0 — First baseline release
- Declared the prompt collection version **1.0** (replacing prior draft-pack numbering).
- Added `financial_disclosures` as a first-class source alongside `tax_consultation_decisions`.
- Added `collect_p04_financial_disclosure_acquisition.txt`, `data_p03_financial_note_extraction.txt`, and `intelligence_p03_cross_source_analysis.txt`.
- Updated all 13 existing prompts for source-family separation, provenance, temporal notes, cross-source citations and security.
- Initially defined two prototype acceptance phases; this historical design was superseded by the three independent phases recorded under terminology and roadmap refinement below.
- Retained `common_p01_lifecycle_management.txt` as first and governing prompt, independent module numbering and flat `prompts/` layout.
- Retained en-US technical naming, restricted local-only directories, developer-managed local-only Git for protected content, and just-in-time authentication.

## 1.0 — terminology and roadmap refinement
- Replaced ambiguous `tax_rulings` / Tax Rulings with `tax_consultation_decisions` / Tax Consultation Decisions for RFB Solucoes de Consulta.
- Preserved original Portuguese document types and distinct classification for Solucoes de Divergencia and other interpretive acts.
- Defined three independently testable and acceptable MVP phases: Tax Consultation Decisions, Financial Statement Notes, Cross-Source Intelligence.
- Updated all 16 prompts, shared schemas, prototype requirements, governance, and README.


## 1.0 — development environment integration refinement
- Expanded `common_p02_rstudio_project_setup.txt` with GitHub, Codex, Claude Code, Gemini CLI and GitHub Copilot compatibility checks, just-in-time authentication and synthetic-data smoke tests.
- Added provider-specific readiness and acceptance tracking to `common_p01_lifecycle_management.txt`.
- Explicitly distinguished terminal integrations from native RStudio/editor integrations and preserved local-only protected-directory rules.

## 2026-11-10 — three-phase consistency correction
- Corrected the remaining two-phase instructions in Common P01 and Common P06: independent consultation decisions, independent financial notes, then cross-source intelligence.
- Clarified Intelligence P02 responsibilities: independent financial-note search belongs to Phase 2; Intelligence P03 supplies Phase 3 cross-source research.
- Retained the earlier two-phase changelog entry as explicitly superseded history.
- The ZIP is an unchanged historical package; the corrected loose prompt files are the current working instructions.
- Added current environment-review requirements to Common P01/P02: verify the actual renv target, treat OneDrive synchronization as unverified until local human review, preserve inherited-locale failures alongside controlled child-process reruns, and reconcile current tool paths while retaining historical checkpoints.
