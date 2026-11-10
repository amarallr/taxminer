# TaxMiner agent instructions

TaxMiner is an independent project, not an official Receita Federal service.
Read docs/project_management/project_status.md, work_items.csv and handoff.md
before changing files. Common P01 governs delivery; execute only the authorized
stage. Track implementation, tests, human acceptance, release and operations
separately. Never infer approval or fabricate evidence.

## Inaccessible boundaries

- Never read, list, traverse, search, index, copy, modify, delete or transmit
  restricted/ or tmp/, including their contents and metadata. Never operate
  developer-owned independent repositories inside these paths.
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
- tax_consultation_decisions and financial_disclosures have independent schemas,
  provenance, coverage and quality. financial_notes search must work independently.
  document_relationships express cited hypotheses, never automatic misconduct.
- Three MVP phases: consultation decisions; independent financial notes; then
  cross-source intelligence over two explicitly accepted datasets. Each has its
  own human acceptance gate. Use one local Shiny interface with independent areas.
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
- Optional assistants are not pipeline dependencies. Do not run another assistant
  or delegate tasks unless explicitly requested by the user.
