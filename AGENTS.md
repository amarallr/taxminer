# TaxMiner agent instructions

TaxMiner is an independent project, not an official Receita Federal service.
Read docs/project_management/project_status.md, work_items.csv and handoff.md
before changing files. Common P01 governs delivery; execute only the authorized
stage. Track implementation, tests, human acceptance, release and operations
separately. Never infer approval or fabricate evidence.

## Inaccessible boundaries

- Never read, list, traverse, search, index, copy, modify, delete or transmit
  .restricted/ or .tmp/ (renamed from restricted/ and tmp/ on 2026-11-12; the
  old names stay protected if they reappear), including their contents and
  metadata. They are confidential: never share them with anyone, never send
  them to any external service, model or tool, never commit, package, upload
  or publish them, and never mention their contents. Never operate
  developer-owned independent repositories inside these paths.
- Dot-prefixed names do not make these paths safe to touch: tools that skip or
  include hidden entries must still exclude them explicitly.
- No exceptions. When the user types `doit`, read `.claude/doit.txt` (local,
  ignored by Git, outside the protected paths) and follow its instructions
  subject to every other rule in this file.
- Use explicit file/directory allowlists. Never recursively scan the repository
  root, use unbounded globs, git add ., or package the root. Do not follow links
  into protected areas. Root inventories must be nonrecursive and omit protected
  entries. Tests and dependency tools must use explicit inputs.
- .gitignore and .renvignore are supplementary controls, not access barriers.
  Do not enable IDE/assistant indexing or cloud sync without verified exclusions.
- Use public or synthetic fixtures only. Never read credential stores or log
  tokens. Authenticate just in time through official human-controlled flows.

## Development

- R is the primary language. Use en-US snake_case identifiers and relative paths;
  preserve source Portuguese text and typed original document classifications.
- Logical modules are src/common/, src/collect/, src/data/, src/intelligence/.
  Create modules when there is real code. Keep prompts/ flat.
- tax_consultation_decisions, financial_disclosures and investment_fund_reports
  (fii, fidc, fip, fiagro) have independent schemas, provenance, coverage and
  quality. financial_notes and fund report search must work independently.
  document_relationships express cited hypotheses, never automatic misconduct.
- Two MVP phases. Phase 1 is data collection, structuring and search, with
  three independent subphases: 1.1 consultation decisions, 1.2 financial notes
  and 1.3 investment fund reports. Phase 2 is cross-source intelligence over
  the accepted Phase 1 bases, always as hypotheses with evidence and human
  review. Each subphase and Phase 2 has its own human acceptance gate. Use one
  local Shiny interface with independent areas.
- Dependencies are explicit in DESCRIPTION. Use renv snapshot type explicit,
  never implicit root dependency discovery. Bootstrap offline from installed
  packages with Rscript --vanilla scripts/setup_environment.R. Restore a locked
  environment with renv::restore(prompt = FALSE) after configuring project-local
  cache paths as in .Rprofile. Do not install unrelated dependencies.
- Validate from the root with Rscript --vanilla scripts/validate_environment.R.
  Report actual results and limitations. Update governance and handoff records.
- No automatic commit, push, remote creation, history rewrite, destructive action,
  global installation or global configuration change. Obtain explicit authorization
  when needed; preserve previously granted authorization within its scope.
- Every static export, commit and push follows prompts/common_p09_safe_publication.txt
  (req_0023): confirm the export, diagnose, integrity, tests, blocking security scan
  (counts only), stamp with timezone and site/app/version.json, explicit file
  allowlist (never git add . / -A / --all), push only with authorization, then
  validate the version served by GitHub Pages and report evidence.
- Optional assistants are not pipeline dependencies. Do not run another assistant
  or delegate tasks unless explicitly requested by the user.
