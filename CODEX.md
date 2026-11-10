# Codex instructions

`AGENTS.md` is the authoritative project instruction file. Codex CLI loads
`AGENTS.md` for this repository; this file is a concise companion reference
and does not replace or override it. Read `AGENTS.md` before acting and follow
its current stage authorization, security boundaries, development policies,
and delivery requirements.

## Protected paths

- Never read, list, search, traverse, index, copy, modify, delete, or transmit
  `restricted/` or `tmp/`, including their contents and metadata.
- Use explicit file and directory allowlists. Do not recursively scan the
  repository root, follow links into protected paths, or use broad staging or
  packaging commands.
- Use only public or synthetic fixtures. Treat ignore rules as supplementary
  filters, not as access barriers.

## Project workflow

- Read `docs/project_management/project_status.md`, `work_items.csv`, and
  `handoff.md` before changing files. Execute only the authorized stage.
- Track implementation, tests, human acceptance, release, and operations as
  separate states. Never infer acceptance or fabricate evidence.
- R is the primary language. Use en-US `snake_case` technical identifiers,
  relative paths, and preserve original Portuguese source text and document
  classifications.
- Keep consultation decisions and financial disclosures in independent
  schemas, with provenance, coverage, quality, and search contracts of their
  own. Cross-source relationships are cited hypotheses, never automatic
  misconduct findings.
- Do not install unrelated dependencies. Use explicit renv snapshots and the
  project validation instructions in `AGENTS.md`.
- Do not automatically commit, push, create remotes, rewrite history, perform
  destructive actions, install globally, or change global configuration.

## Local Codex CLI configuration

`.codex/config.toml` selects `workspace-write` sandboxing and `on-request`
approval for trusted projects. These settings complement `AGENTS.md`; they do
not grant authorization for work outside the user's request or the project's
current stage. Keep dangerous approval-bypass options disabled.
