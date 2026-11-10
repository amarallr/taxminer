# Changelog

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
