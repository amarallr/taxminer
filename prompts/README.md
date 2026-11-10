# TaxMiner — Prompt Pack 1.0

**Release:** 1.0 (first baseline release of the prompts; not a claim of implemented software).

16 detailed CO-STAR prompts, directly under `prompts/`, numbered independently per module. American English (`en-US`) technical naming (`snake_case`); developer-facing explanations may use Brazilian Portuguese. Source documents preserve their original language.

## Scope
- `tax_consultation_decisions`: Receita Federal Solucoes de Consulta (Tax Consultation Decisions); Solucoes de Divergencia and other interpretive acts, if included, remain distinct document types, subject to verified sources.
- `financial_disclosures`: publicly published company financial statements, explanatory notes and associated tables, subject to verified CVM/issuer availability and reuse terms.
- `document_relationships`: evidence-backed research links; never automatic tax misconduct findings.

## Recommended execution and three independent MVP phases
1. `common_p01_lifecycle_management.txt` — initialize and maintain governance across all three phases.
2. `common_p02_rstudio_project_setup.txt` and `common_p03_architecture_requirements.txt` — environment, security, source-specific architecture and independent acceptance gates.
3. **MVP Phase 1 — Tax Consultation Decisions:** `collect_p01_official_source_discovery.txt`, `collect_p02_historical_download.txt`, `data_p01_text_metadata_extraction.txt`, `data_p02_historical_parquet_consolidation.txt`, `intelligence_p02_semantic_search_analytics.txt`, and `common_p06_prototype_delivery.txt`.
4. **MVP Phase 2 — Financial Statement Notes:** `collect_p04_financial_disclosure_acquisition.txt`, `data_p03_financial_note_extraction.txt`, `intelligence_p02_semantic_search_analytics.txt` (independent financial-note search only; no dependency on Phase 1 search) and `common_p06_prototype_delivery.txt`.
5. **MVP Phase 3 — Cross-Source Intelligence:** `intelligence_p03_cross_source_analysis.txt` and `common_p06_prototype_delivery.txt`.
6. `common_p04_testing_quality.txt` and `common_p05_documentation_release.txt` apply to each phase; run `common_p01_lifecycle_management.txt` after every gate and during operations.
7. **Post-MVP (not part of any MVP gate):** `collect_p03_incremental_updates.txt` (incremental refresh after a phase's sample is accepted) and `intelligence_p01_legal_tax_enrichment.txt` (legal/tax enrichment after Phase 1 acceptance). Start only with explicit authorization.

## Naming and version labels
- File names are canonical: `group_pNN_objective.txt`. Internal titles repeat the module and number (for example `# COMMON P03`).
- "Prompt Pack 1.0" / "TAXMINER 1.0" is the current pack version. "CONTRATO TRANSVERSAL TAXMINER V5" and "TaxMiner 3.0" inside Common P02 are historical labels of embedded template text, not separate versions.
- Later sections in a prompt (the dual-source contract and the three-phase roadmap) prevail over earlier, conflicting single-source wording.

## Protected directories
`restricted/` and `tmp/` are exclusively local legally protected areas. Codex/remote agents must not access or operate them. The developer may independently maintain **local-only** Git histories inside them, with no remotes; the main Git repository ignores both, and protected data or histories must never be pushed, synced or published. `.gitignore` is not by itself a sufficient safety boundary. Use public or synthetic data for development, tests and demonstrations. There are no exceptions; the developer's `doit` instruction file lives at `.claude/doit.txt`, outside the protected paths.

## Acceptance and verification
Implementation, testing, human acceptance, release and operations statuses are tracked separately. Phase 1, Phase 2, and Phase 3 MVP approvals are independent and distinct. No fabricated counts, tests, source availability or legal conclusions. Request authentication only when needed through official local flows; never ask for tokens/passwords in chat.

## Deliverables
This archive contains **prompts and documentation only**. It does not implement the TaxMiner software.


## Development assistant integration (1.0 update)
The environment setup prompt covers RStudio terminal workflows for Codex, Claude Code and Gemini CLI, Git/GitHub CLI integration, and GitHub Copilot in a compatible editor when supported. Each tool has independent installation, authentication, smoke-test and acceptance status. Current TaxMiner layout: Codex is installed per-user under `%LOCALAPPDATA%/Programs/OpenAI/Codex/`; GitHub CLI, Gemini CLI and Node/npm are installed per-user under `%LOCALAPPDATA%/Programs/TaxMiner/`. The user PATH contains the required tool directories; machine PATH is unchanged. The GitHub CLI directory is `%LOCALAPPDATA%/Programs/TaxMiner/github_cli/bin`. Project `renv` state is configured under `%LOCALAPPDATA%/R/cache/renv`; verify that this target exists and restores successfully before claiming readiness. Current review found the target absent. The checkout remains under OneDrive and sync exclusions require local human verification. The current Windows locale can make direct UTF-8 validation fail; record that failure and use only child-process locale cleanup for a controlled rerun. Prefer a reviewed checkout outside OneDrive; never copy/package the repository root or access `restricted/` and `tmp/`. `scripts/run_gemini.ps1` remains available as a project launcher. All assistants must respect the local-only `restricted/` and `tmp/` boundaries.
