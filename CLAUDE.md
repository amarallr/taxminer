# Claude Code instructions

Read and follow `AGENTS.md` as the authoritative project policy before acting.
It governs scope, security boundaries, architecture, validation, and delivery.
If instructions conflict, follow `AGENTS.md` and report the conflict.

Do not access `restricted/` or `tmp/`, including contents and metadata, except the read-only `doit` exception for the
single file `tmp/doit.txt` defined in `AGENTS.md`. Use only
explicit file and directory allowlists; never recursively scan the repository
root or follow links into protected paths. Use public or synthetic fixtures.
Do not install tools or dependencies, change global settings, commit, push, or
publish without the authorization required by `AGENTS.md`.
